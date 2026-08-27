// ---------------------------------------------------------------------------
// Drift -- Auth Middleware
//
// 1. Extracts and verifies the Supabase JWT from the Authorization header.
// 2. Validates standard claims (exp, aud, iss) when SUPABASE_JWT_SECRET is
//    configured -- otherwise falls back to Supabase's auth.getUser() RPC.
// 3. Attaches userId, userEmail, userPlan, and userRole to the request.
// 4. Provides role-based and plan-based access-control middleware.
// ---------------------------------------------------------------------------

import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import { getSupabaseAdmin } from "../config/supabase.js";
import { getEnv } from "../config/env.js";
import { PlanId, planIdSchema, planAtLeast } from "../config/plans.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type UserRole = "user" | "admin";

export interface AuthenticatedRequest extends Request {
  userId: string;
  userEmail: string;
  userPlan: PlanId;
  userRole: UserRole;
  /** Raw access token -- available if downstream code needs to create a
   *  user-scoped Supabase client. */
  accessToken: string;
}

interface SupabaseJwtPayload {
  sub: string;
  email?: string;
  aud?: string;
  iss?: string;
  role?: string;
  exp?: number;
  iat?: number;
  app_metadata?: { role?: string };
  user_metadata?: Record<string, unknown>;
}

// ---------------------------------------------------------------------------
// Token verification
// ---------------------------------------------------------------------------

/**
 * If SUPABASE_JWT_SECRET is available, verify the JWT locally (fast, no
 * network round-trip). Otherwise fall back to Supabase's auth.getUser()
 * which performs a remote verification.
 */
async function verifyToken(
  token: string,
): Promise<{ userId: string; email: string; role: UserRole }> {
  const env = getEnv();

  // -- Fast path: local JWT verification ----------------------------------
  if (env.SUPABASE_JWT_SECRET) {
    try {
      const payload = jwt.verify(token, env.SUPABASE_JWT_SECRET, {
        algorithms: ["HS256"],
        // Validate audience -- Supabase sets this to "authenticated"
        audience: "authenticated",
        // Prevent a valid token from another Supabase project being accepted.
        issuer: `${env.SUPABASE_URL.replace(/\/$/, "")}/auth/v1`,
      }) as SupabaseJwtPayload;

      if (!payload.sub) {
        throw new Error("Token missing sub claim");
      }

      // Derive role from app_metadata (Supabase convention)
      const rawRole = payload.app_metadata?.role ?? "user";
      const role: UserRole = rawRole === "admin" ? "admin" : "user";

      return {
        userId: payload.sub,
        email: payload.email ?? "",
        role,
      };
    } catch (err: unknown) {
      if (err instanceof jwt.TokenExpiredError) {
        throw new AuthError("Token has expired", 401, "TOKEN_EXPIRED");
      }
      if (err instanceof jwt.JsonWebTokenError) {
        throw new AuthError("Invalid token", 401, "TOKEN_INVALID");
      }
      throw err;
    }
  }

  // -- Slow path: remote verification via Supabase ------------------------
  const sb = getSupabaseAdmin();
  const {
    data: { user },
    error,
  } = await sb.auth.getUser(token);

  if (error || !user) {
    if (error?.message?.toLowerCase().includes("expired")) {
      throw new AuthError("Token has expired", 401, "TOKEN_EXPIRED");
    }
    throw new AuthError(
      error?.message ?? "Invalid or expired token",
      401,
      "TOKEN_INVALID",
    );
  }

  const rawRole = user.app_metadata?.role ?? "user";
  const role: UserRole = rawRole === "admin" ? "admin" : "user";

  return { userId: user.id, email: user.email ?? "", role };
}

// ---------------------------------------------------------------------------
// Structured auth error
// ---------------------------------------------------------------------------

export class AuthError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number = 401,
    public readonly code: string = "AUTH_ERROR",
  ) {
    super(message);
    this.name = "AuthError";
  }
}

// ---------------------------------------------------------------------------
// Main auth middleware
// ---------------------------------------------------------------------------

/**
 * Verify Supabase access token from Authorization header.
 * Attaches userId, userEmail, userPlan, and userRole to the request.
 *
 * Token refresh hint: when the token is expired, the response includes an
 * `X-Token-Expired: true` header so the client knows to call the refresh
 * endpoint before retrying.
 */
export async function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const header = req.headers.authorization;

  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({
      error: "Missing authorization token",
      code: "NO_TOKEN",
      hint: "Include an Authorization: Bearer <token> header",
    });
    return;
  }

  const token = header.slice(7);

  if (!token || token === "undefined" || token === "null") {
    res.status(401).json({
      error: "Malformed authorization token",
      code: "MALFORMED_TOKEN",
    });
    return;
  }

  try {
    const { userId, email, role } = await verifyToken(token);

    // Fetch plan from profile (single lightweight query)
    const sb = getSupabaseAdmin();
    const { data: profile } = await sb
      .from("user_profiles")
      .select("plan")
      .eq("user_id", userId)
      .single();

    const parsed = planIdSchema.safeParse(profile?.plan);
    const plan: PlanId = parsed.success ? parsed.data : "free";

    const authReq = req as AuthenticatedRequest;
    authReq.userId = userId;
    authReq.userEmail = email;
    authReq.userPlan = plan;
    authReq.userRole = role;
    authReq.accessToken = token;

    next();
  } catch (err: unknown) {
    if (err instanceof AuthError) {
      if (err.code === "TOKEN_EXPIRED") {
        res.setHeader("X-Token-Expired", "true");
      }
      res.status(err.statusCode).json({
        error: err.message,
        code: err.code,
      });
      return;
    }

    // Unexpected failure -- log and return generic message
    console.error("[Auth] Unexpected verification error:", err);
    res.status(401).json({
      error: "Authentication failed",
      code: "AUTH_ERROR",
    });
  }
}

// ---------------------------------------------------------------------------
// Optional auth -- attaches user info if a token is present, but does not
// reject unauthenticated requests.
// ---------------------------------------------------------------------------

export async function optionalAuth(
  req: Request,
  _res: Response,
  next: NextFunction,
): Promise<void> {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    next();
    return;
  }

  try {
    const token = header.slice(7);
    const { userId, email, role } = await verifyToken(token);

    const sb = getSupabaseAdmin();
    const { data: profile } = await sb
      .from("user_profiles")
      .select("plan")
      .eq("user_id", userId)
      .single();

    const parsed = planIdSchema.safeParse(profile?.plan);

    const authReq = req as AuthenticatedRequest;
    authReq.userId = userId;
    authReq.userEmail = email;
    authReq.userPlan = parsed.success ? parsed.data : "free";
    authReq.userRole = role;
    authReq.accessToken = token;
  } catch {
    // Silently ignore -- request continues as unauthenticated
  }

  next();
}

// ---------------------------------------------------------------------------
// Plan-gated middleware
// ---------------------------------------------------------------------------

/**
 * Require the authenticated user to be on one of the listed plans.
 * Must be placed AFTER requireAuth in the middleware chain.
 */
export function requirePlan(...allowed: PlanId[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const authReq = req as AuthenticatedRequest;
    if (!allowed.includes(authReq.userPlan)) {
      res.status(403).json({
        error: "Upgrade required",
        code: "PLAN_REQUIRED",
        requiredPlan: allowed[0],
        currentPlan: authReq.userPlan,
      });
      return;
    }
    next();
  };
}

/**
 * Require a minimum plan tier (free < pro < team).
 */
export function requireMinPlan(minimum: PlanId) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const authReq = req as AuthenticatedRequest;
    if (!planAtLeast(authReq.userPlan, minimum)) {
      res.status(403).json({
        error: "Upgrade required",
        code: "PLAN_REQUIRED",
        requiredPlan: minimum,
        currentPlan: authReq.userPlan,
      });
      return;
    }
    next();
  };
}

// ---------------------------------------------------------------------------
// Role-based access control
// ---------------------------------------------------------------------------

/**
 * Require the authenticated user to have one of the specified roles.
 * Must be placed AFTER requireAuth in the middleware chain.
 */
export function requireRole(...roles: UserRole[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const authReq = req as AuthenticatedRequest;
    if (!roles.includes(authReq.userRole)) {
      res.status(403).json({
        error: "Insufficient permissions",
        code: "ROLE_REQUIRED",
      });
      return;
    }
    next();
  };
}
