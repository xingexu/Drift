// ---------------------------------------------------------------------------
// Drift -- Auth Routes (Supabase Auth proxy for desktop/web app)
// ---------------------------------------------------------------------------

import { Router, Request, Response } from "express";
import { z } from "zod";
import { rateLimit } from "../middleware/rateLimit.js";
import { getSupabaseAdmin } from "../config/supabase.js";
import { getEnv } from "../config/env.js";

const router = Router();

// ---------------------------------------------------------------------------
// Shared types & helpers
// ---------------------------------------------------------------------------

/** Standard error envelope returned by every auth endpoint on failure. */
interface AuthErrorResponse {
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}

/** Build a consistent error payload. */
function authError(code: string, message: string, details?: unknown): AuthErrorResponse {
  return { error: { code, message, ...(details !== undefined && { details }) } };
}

/**
 * Wrap an async route handler so unhandled rejections are caught and
 * converted into a safe 500 response. Prevents Express from silently
 * dropping errors.
 */
function asyncHandler(
  fn: (req: Request, res: Response) => Promise<void>,
): (req: Request, res: Response) => void {
  return (req, res) => {
    fn(req, res).catch((err: unknown) => {
      const message = err instanceof Error ? err.message : "Unknown error";
      console.error(`[Auth] Unhandled error on ${req.method} ${req.path}:`, message);
      res.status(500).json(authError("INTERNAL_ERROR", "An unexpected error occurred"));
    });
  };
}

// ---------------------------------------------------------------------------
// Dedicated auth rate limiter -- stricter than the general API limiter
// (20 requests / minute per IP to mitigate brute-force / credential-stuffing)
// ---------------------------------------------------------------------------

import { RateLimiterMemory } from "rate-limiter-flexible";

const authLimiter = new RateLimiterMemory({
  points: 20,
  duration: 60,
  keyPrefix: "auth",
});

function authRateLimit() {
  return async (req: Request, res: Response, next: () => void): Promise<void> => {
    const key = req.ip ?? "anonymous";
    try {
      await authLimiter.consume(key);
      next();
    } catch {
      res.status(429).json(authError("RATE_LIMITED", "Too many requests. Please try again later."));
    }
  };
}

// ---------------------------------------------------------------------------
// Validation schemas (Zod)
// ---------------------------------------------------------------------------

const signupSchema = z.object({
  email: z.string().email("Invalid email address").max(254).trim().toLowerCase(),
  password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(128, "Password must not exceed 128 characters"),
  name: z
    .string()
    .max(100, "Name must not exceed 100 characters")
    .trim()
    .optional(),
});

const loginSchema = z.object({
  email: z.string().email("Invalid email address").max(254).trim().toLowerCase(),
  password: z.string().min(1, "Password is required").max(128),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1, "Refresh token is required"),
});

const logoutSchema = z.object({
  refreshToken: z.string().optional(),
});

const forgotPasswordSchema = z.object({
  email: z.string().email("Invalid email address").max(254).trim().toLowerCase(),
});

const updatePasswordSchema = z.object({
  accessToken: z.string().min(1, "Access token is required"),
  newPassword: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(128, "Password must not exceed 128 characters"),
});

const oauthSchema = z.object({
  redirectTo: z.string().url().max(2000).optional(),
});

const callbackSchema = z.object({
  accessToken: z.string().min(1, "Access token is required"),
  refreshToken: z.string().optional(),
});

/** Validate a Zod schema against `req.body` and return parsed data or send 400. */
function validateBody<T extends z.ZodTypeAny>(
  schema: T,
  req: Request,
  res: Response,
): z.infer<T> | null {
  const result = schema.safeParse(req.body);
  if (!result.success) {
    const details = result.error.issues.map((i) => ({
      field: i.path.join("."),
      message: i.message,
    }));
    res.status(400).json(authError("VALIDATION_ERROR", details[0].message, details));
    return null;
  }
  return result.data;
}

// ---------------------------------------------------------------------------
// POST /api/auth/signup -- Register a new user
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/auth/signup
 * @desc    Create a new user account and send a verification email.
 * @access  Public (rate-limited)
 * @body    { email: string, password: string, name?: string }
 * @returns { message: string, userId: string }
 */
router.post(
  "/signup",
  authRateLimit(),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(signupSchema, req, res);
    if (!body) return;

    const { email, password, name } = body;
    const sb = getSupabaseAdmin();

    const { data, error } = await sb.auth.admin.createUser({
      email,
      password,
      email_confirm: false,
      user_metadata: { name: name ?? null },
    });

    if (error) {
      if (
        error.message.includes("already registered") ||
        error.message.includes("duplicate")
      ) {
        res.status(409).json(authError("EMAIL_EXISTS", "An account with this email already exists"));
        return;
      }
      throw error;
    }

    // Send confirmation email (best-effort)
    try {
      await sb.auth.admin.generateLink({
        type: "signup",
        email,
        password,
        options: { redirectTo: `${getEnv().FRONTEND_URL}/verify` },
      });
    } catch {
      // Non-critical -- user was still created
    }

    res.status(201).json({
      message: "Account created. Check your email for a verification link.",
      userId: data.user.id,
    });
  }),
);

// ---------------------------------------------------------------------------
// POST /api/auth/login -- Sign in with email/password
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/auth/login
 * @desc    Authenticate via email/password and return session tokens.
 * @access  Public (rate-limited)
 * @body    { email: string, password: string }
 * @returns { accessToken, refreshToken, expiresIn, user }
 */
router.post(
  "/login",
  authRateLimit(),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(loginSchema, req, res);
    if (!body) return;

    const { email, password } = body;
    const sb = getSupabaseAdmin();

    const { data, error } = await sb.auth.signInWithPassword({ email, password });

    if (error) {
      if (error.message.includes("Email not confirmed")) {
        res
          .status(403)
          .json(authError("EMAIL_NOT_VERIFIED", "Please verify your email before logging in"));
        return;
      }
      if (error.message.includes("Invalid login")) {
        res.status(401).json(authError("INVALID_CREDENTIALS", "Invalid email or password"));
        return;
      }
      throw error;
    }

    if (!data.session) {
      res.status(401).json(authError("SESSION_CREATION_FAILED", "Login failed -- no session created"));
      return;
    }

    const { data: profile } = await sb
      .from("user_profiles")
      .select("plan, name")
      .eq("user_id", data.user.id)
      .single();

    res.json({
      accessToken: data.session.access_token,
      refreshToken: data.session.refresh_token,
      expiresIn: data.session.expires_in,
      user: {
        userId: data.user.id,
        email: data.user.email,
        name: profile?.name ?? data.user.user_metadata?.name ?? null,
        plan: profile?.plan ?? "free",
      },
    });
  }),
);

// ---------------------------------------------------------------------------
// POST /api/auth/refresh -- Refresh access token
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/auth/refresh
 * @desc    Exchange a refresh token for a new access/refresh token pair.
 * @access  Public (rate-limited)
 * @body    { refreshToken: string }
 * @returns { accessToken, refreshToken, expiresIn }
 */
router.post(
  "/refresh",
  authRateLimit(),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(refreshSchema, req, res);
    if (!body) return;

    const sb = getSupabaseAdmin();
    const { data, error } = await sb.auth.refreshSession({
      refresh_token: body.refreshToken,
    });

    if (error || !data.session) {
      res.status(401).json(authError("TOKEN_EXPIRED", "Invalid or expired refresh token"));
      return;
    }

    res.json({
      accessToken: data.session.access_token,
      refreshToken: data.session.refresh_token,
      expiresIn: data.session.expires_in,
    });
  }),
);

// ---------------------------------------------------------------------------
// POST /api/auth/logout -- Sign out (invalidate refresh token)
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/auth/logout
 * @desc    Invalidate the current session on the server. Always returns 200.
 * @access  Public (rate-limited)
 * @body    { refreshToken?: string }
 * @returns { message: string }
 */
router.post(
  "/logout",
  authRateLimit(),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(logoutSchema, req, res);
    if (!body) return;

    // Best-effort: try to invalidate the session on Supabase
    if (body.refreshToken) {
      try {
        const sb = getSupabaseAdmin();
        const header = req.headers.authorization;
        if (header?.startsWith("Bearer ")) {
          const token = header.slice(7);
          const {
            data: { user },
          } = await sb.auth.getUser(token);
          if (user) {
            await sb.auth.admin.signOut(token);
          }
        }
      } catch {
        // Non-critical -- token will expire naturally
      }
    }

    res.json({ message: "Logged out successfully" });
  }),
);

// ---------------------------------------------------------------------------
// POST /api/auth/forgot-password -- Send password reset email
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/auth/forgot-password
 * @desc    Send a password-reset email. Always returns 200 to prevent email
 *          enumeration attacks.
 * @access  Public (rate-limited)
 * @body    { email: string }
 * @returns { message: string }
 */
router.post(
  "/forgot-password",
  authRateLimit(),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(forgotPasswordSchema, req, res);
    if (!body) return;

    try {
      const sb = getSupabaseAdmin();
      await sb.auth.resetPasswordForEmail(body.email, {
        redirectTo: `${getEnv().FRONTEND_URL}/reset-password`,
      });
    } catch {
      // Swallow intentionally -- same response regardless
    }

    // Always return success to prevent email enumeration
    res.json({ message: "If an account exists with that email, a reset link has been sent." });
  }),
);

// ---------------------------------------------------------------------------
// POST /api/auth/update-password -- Update password (requires valid token)
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/auth/update-password
 * @desc    Set a new password using a valid access token (e.g. from a reset flow).
 * @access  Public (rate-limited, token-gated)
 * @body    { accessToken: string, newPassword: string }
 * @returns { message: string }
 */
router.post(
  "/update-password",
  authRateLimit(),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(updatePasswordSchema, req, res);
    if (!body) return;

    const sb = getSupabaseAdmin();

    const {
      data: { user },
      error: userError,
    } = await sb.auth.getUser(body.accessToken);

    if (userError || !user) {
      res.status(401).json(authError("TOKEN_INVALID", "Invalid or expired token"));
      return;
    }

    const { error: updateError } = await sb.auth.admin.updateUserById(user.id, {
      password: body.newPassword,
    });

    if (updateError) throw updateError;

    res.json({ message: "Password updated successfully" });
  }),
);

// ---------------------------------------------------------------------------
// POST /api/auth/google -- Initiate Google OAuth sign-in
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/auth/google
 * @desc    Start a Google OAuth flow and return the redirect URL.
 * @access  Public (rate-limited)
 * @body    { redirectTo?: string }
 * @returns { url: string }
 */
router.post(
  "/google",
  authRateLimit(),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(oauthSchema, req, res);
    if (!body) return;

    const sb = getSupabaseAdmin();
    const env = getEnv();
    const callbackUrl = body.redirectTo || `${env.FRONTEND_URL}/api/auth/oauth-redirect`;

    const { data, error } = await sb.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: callbackUrl,
        queryParams: { access_type: "offline", prompt: "consent" },
      },
    });

    if (error) throw error;

    res.json({ url: data.url });
  }),
);

// ---------------------------------------------------------------------------
// POST /api/auth/apple -- Initiate Apple Sign-In
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/auth/apple
 * @desc    Start an Apple Sign-In flow and return the redirect URL.
 * @access  Public (rate-limited)
 * @body    { redirectTo?: string }
 * @returns { url: string }
 */
router.post(
  "/apple",
  authRateLimit(),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(oauthSchema, req, res);
    if (!body) return;

    const sb = getSupabaseAdmin();
    const env = getEnv();
    const callbackUrl = body.redirectTo || `${env.FRONTEND_URL}/api/auth/oauth-redirect`;

    const { data, error } = await sb.auth.signInWithOAuth({
      provider: "apple",
      options: { redirectTo: callbackUrl },
    });

    if (error) throw error;

    res.json({ url: data.url });
  }),
);

// ---------------------------------------------------------------------------
// GET /api/auth/oauth-redirect -- Bridge page: tokens -> drift:// deep link
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/auth/oauth-redirect
 * @desc    Serve a tiny HTML page that reads tokens from the URL fragment
 *          and redirects the desktop app via the `drift://` custom scheme.
 * @access  Public
 */
router.get("/oauth-redirect", (_req: Request, res: Response) => {
  res.setHeader("Content-Type", "text/html");
  res.setHeader("Cache-Control", "no-store");
  res.send(`<!DOCTYPE html>
<html>
<head><title>Redirecting to Drift...</title></head>
<body>
  <p style="font-family:system-ui;text-align:center;margin-top:40vh;color:#666">
    Redirecting to Drift app...
  </p>
  <script>
    // Supabase puts tokens in the hash fragment
    var hash = window.location.hash.substring(1);
    if (hash) {
      window.location.href = 'drift://auth/callback#' + hash;
    } else {
      var params = window.location.search;
      if (params) {
        window.location.href = 'drift://auth/callback' + params;
      } else {
        document.body.innerHTML = '<p style="font-family:system-ui;text-align:center;margin-top:40vh;color:#c00">Authentication failed. Please try again from the Drift app.</p>';
      }
    }
  </script>
</body>
</html>`);
});

// ---------------------------------------------------------------------------
// POST /api/auth/callback -- Handle OAuth callback token exchange
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/auth/callback
 * @desc    Verify an OAuth access token and return (or create) the user profile.
 * @access  Public (rate-limited)
 * @body    { accessToken: string, refreshToken?: string }
 * @returns { accessToken, refreshToken, user }
 */
router.post(
  "/callback",
  authRateLimit(),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(callbackSchema, req, res);
    if (!body) return;

    const sb = getSupabaseAdmin();

    const {
      data: { user },
      error: userError,
    } = await sb.auth.getUser(body.accessToken);

    if (userError || !user) {
      res.status(401).json(authError("TOKEN_INVALID", "Invalid token"));
      return;
    }

    // Get or create profile
    const { data: profile } = await sb
      .from("user_profiles")
      .select("plan, name")
      .eq("user_id", user.id)
      .single();

    if (!profile) {
      await sb.from("user_profiles").insert({
        user_id: user.id,
        email: user.email,
        name: user.user_metadata?.full_name ?? user.user_metadata?.name ?? null,
        plan: "free",
      });
    }

    res.json({
      accessToken: body.accessToken,
      refreshToken: body.refreshToken ?? null,
      user: {
        userId: user.id,
        email: user.email,
        name: profile?.name ?? user.user_metadata?.full_name ?? null,
        plan: profile?.plan ?? "free",
      },
    });
  }),
);

export default router;
