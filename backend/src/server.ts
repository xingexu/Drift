// ---------------------------------------------------------------------------
// Drift -- Main API Server
// Express + Stripe + Claude AI + Cron Jobs
//
// Infrastructure improvements:
//   - CORS allowlist (explicit origins, no wildcard)
//   - Request logging with auth-header redaction
//   - Request-ID tracking (X-Request-Id)
//   - Graceful shutdown (SIGTERM / SIGINT)
//   - Deep health check (Supabase, Redis, Stripe, cron jobs)
//   - Helmet properly configured for API responses
// ---------------------------------------------------------------------------

import dotenv from "dotenv";
dotenv.config({ override: true });

import express from "express";
import cors from "cors";
import helmet from "helmet";
import crypto from "crypto";
import cron from "node-cron";

import { getEnv, isDev, isProd } from "./config/env.js";
import authRoutes from "./routes/auth.js";
import billingRoutes from "./routes/billing.js";
import coachingRoutes from "./routes/coaching.js";
import teamRoutes from "./routes/teams.js";
import sessionRoutes from "./routes/sessions.js";
import preferenceRoutes from "./routes/preferences.js";
import { requireAuth, AuthenticatedRequest } from "./middleware/auth.js";
import { rateLimit, getRedisHealth } from "./middleware/rateLimit.js";
import { runWeeklyDigest, getWeeklyDigestHealth } from "./jobs/weekly-digest.js";
import { runTrialReminders, getTrialRemindersHealth } from "./jobs/trial-reminders.js";
import { runDataCleanup, getDataCleanupHealth } from "./jobs/data-cleanup.js";
import { onboardNewUser, setupAuthWebhook } from "./jobs/onboarding.js";
import { getSubscriptionStatus } from "./services/stripe.js";
import { getSupabaseAdmin, checkSupabaseHealth } from "./config/supabase.js";

const app = express();

// ---------------------------------------------------------------------------
// 1. Helmet -- secure HTTP headers
// ---------------------------------------------------------------------------

app.use(
  helmet({
    // This is an API server, not a browser app -- disable HTML-specific
    // policies that add noise to JSON responses.
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false,
    // Keep useful protections
    hsts: isProd() ? { maxAge: 31536000, includeSubDomains: true } : false,
    noSniff: true,
    frameguard: { action: "deny" },
    xssFilter: true,
    referrerPolicy: { policy: "strict-origin-when-cross-origin" },
  }),
);

// ---------------------------------------------------------------------------
// 2. Request ID -- every request gets a unique trace ID
// ---------------------------------------------------------------------------

app.use((req, res, next) => {
  const requestId =
    (req.headers["x-request-id"] as string) ?? crypto.randomUUID();
  req.headers["x-request-id"] = requestId;
  res.setHeader("X-Request-Id", requestId);
  next();
});

// ---------------------------------------------------------------------------
// 3. CORS -- explicit origin allowlist, no wildcard
// ---------------------------------------------------------------------------

function buildCorsOrigins(): (string | RegExp)[] {
  const env = getEnv();
  const origins: (string | RegExp)[] = [];

  if (isDev()) {
    origins.push(
      "http://localhost:3000",
      "http://localhost:5173",
      "http://localhost:5174",
    );
  }

  // Production frontend
  if (env.FRONTEND_URL) {
    origins.push(env.FRONTEND_URL);
  }

  // Electron / Tauri app origins
  origins.push("file://", `${env.APP_SCHEME}://`);

  // Extra origins from CORS_ORIGINS env var
  if (env.CORS_ORIGINS) {
    for (const o of env.CORS_ORIGINS.split(",")) {
      const trimmed = o.trim();
      if (trimmed) origins.push(trimmed);
    }
  }

  return origins;
}

app.use(
  cors({
    origin: buildCorsOrigins(),
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "X-Request-Id",
      "X-Client-Version",
    ],
    exposedHeaders: [
      "X-Request-Id",
      "X-RateLimit-Limit",
      "X-RateLimit-Remaining",
      "X-RateLimit-Reset",
      "X-Token-Expired",
      "Retry-After",
    ],
    maxAge: 86400, // Preflight cache: 24 hours
  }),
);

// ---------------------------------------------------------------------------
// 4. Request logging -- custom middleware that redacts auth headers
// ---------------------------------------------------------------------------

app.use((req, res, next) => {
  const start = Date.now();
  const requestId = req.headers["x-request-id"] as string;

  res.on("finish", () => {
    const duration = Date.now() - start;
    const method = req.method;
    const url = req.originalUrl;
    const status = res.statusCode;

    // Redact sensitive headers
    const safeHeaders: Record<string, string> = {};
    if (req.headers["content-type"]) {
      safeHeaders["content-type"] = req.headers["content-type"] as string;
    }
    if (req.headers["authorization"]) {
      safeHeaders["authorization"] = "Bearer [REDACTED]";
    }
    if (req.headers["user-agent"]) {
      safeHeaders["user-agent"] = req.headers["user-agent"] as string;
    }

    // Compact single-line log format for structured logging
    const logLine = [
      `[${method}]`,
      url,
      status,
      `${duration}ms`,
      requestId ? `rid=${requestId}` : "",
    ]
      .filter(Boolean)
      .join(" ");

    if (status >= 500) {
      console.error(logLine);
    } else if (status >= 400) {
      console.warn(logLine);
    } else {
      console.log(logLine);
    }
  });

  next();
});

// ---------------------------------------------------------------------------
// 5. Body parsing
// ---------------------------------------------------------------------------

// Raw body for Stripe webhooks (must be before express.json())
app.use("/api/webhooks/stripe", express.raw({ type: "application/json" }));

// JSON body for everything else -- 1 MB limit prevents abuse
app.use(express.json({ limit: "1mb" }));

// ---------------------------------------------------------------------------
// 6. Health check -- deep dependency status
// ---------------------------------------------------------------------------

app.get("/api/health", async (_req, res) => {
  try {
    const [supabase, redis] = await Promise.all([
      checkSupabaseHealth(),
      Promise.resolve(getRedisHealth()),
    ]);

    // Cron job staleness
    const jobs = {
      weeklyDigest: getWeeklyDigestHealth(),
      trialReminders: getTrialRemindersHealth(),
      dataCleanup: getDataCleanupHealth(),
    };

    // Overall status: if any critical dependency is down, report degraded
    const isHealthy =
      supabase.status === "ok" &&
      (redis.status === "ok" || redis.status === "not_configured");

    res.status(isHealthy ? 200 : 503).json({
      status: isHealthy ? "ok" : "degraded",
      version: "1.1.0",
      timestamp: new Date().toISOString(),
      uptime: Math.floor(process.uptime()),
      dependencies: {
        supabase: {
          status: supabase.status,
          latencyMs: supabase.latencyMs,
          ...(supabase.error && !isProd() && { error: supabase.error }),
        },
        redis: {
          status: redis.status,
          mode: redis.mode,
          ...(redis.error && !isProd() && { error: redis.error }),
        },
      },
      jobs,
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("[Health] Check failed:", msg);
    res.status(503).json({
      status: "error",
      version: "1.1.0",
      timestamp: new Date().toISOString(),
      error: isDev() ? msg : "Health check failed",
    });
  }
});

// ---------------------------------------------------------------------------
// 7. API Routes
// ---------------------------------------------------------------------------

app.use("/api/auth", authRoutes);
app.use("/api/billing", billingRoutes);
app.use("/api/coaching", coachingRoutes);
app.use("/api/teams", teamRoutes);
app.use("/api/sessions", sessionRoutes);
app.use("/api/preferences", preferenceRoutes);

// ---------------------------------------------------------------------------
// 8. User profile & subscription
// ---------------------------------------------------------------------------

app.get(
  "/api/me",
  requireAuth,
  rateLimit("read"),
  async (req, res) => {
    try {
      const authReq = req as AuthenticatedRequest;
      const status = await getSubscriptionStatus(authReq.userId);

      const sb = getSupabaseAdmin();
      const { data: profile } = await sb
        .from("user_profiles")
        .select("*")
        .eq("user_id", authReq.userId)
        .single();

      res.json({
        userId: authReq.userId,
        email: authReq.userEmail,
        plan: status.plan,
        subscriptionStatus: status.status,
        trialEndsAt: status.trialEndsAt,
        cancelAt: status.cancelAt,
        profile: profile ?? null,
      });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Unknown error";
      console.error(`[/api/me] Error for user: ${msg}`);
      res
        .status(500)
        .json({ error: isDev() ? msg : "Internal server error" });
    }
  },
);

// ---------------------------------------------------------------------------
// 9. Auth webhook (Supabase triggers this on new user)
// ---------------------------------------------------------------------------

app.post(
  "/api/webhooks/auth",
  rateLimit("webhook"),
  async (req, res) => {
    try {
      const { type, record } = req.body ?? {};

      if (type === "INSERT" && record?.id && record?.email) {
        await onboardNewUser(record.id, record.email);
      }

      res.json({ received: true });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Unknown error";
      console.error("[Auth Webhook Error]", msg);
      res
        .status(500)
        .json({ error: isDev() ? msg : "Internal server error" });
    }
  },
);

// ---------------------------------------------------------------------------
// 10. Analytics endpoint (for Drift desktop app to report sessions)
// ---------------------------------------------------------------------------

app.post(
  "/api/sessions/report",
  requireAuth,
  rateLimit("api"),
  async (req, res) => {
    try {
      const authReq = req as AuthenticatedRequest;
      const { sessionData } = req.body;

      if (!sessionData) {
        res.status(400).json({ error: "sessionData required" });
        return;
      }

      // Store aggregated analytics (not raw browsing data -- privacy first)
      const sb = getSupabaseAdmin();
      const { error: insertError } = await sb
        .from("analytics_events")
        .insert({
          user_id: authReq.userId,
          event_type: "session_completed",
          payload: {
            driftScore: sessionData.driftScore,
            durationMs: sessionData.totalDurationMs,
            eventCount: sessionData.eventCount,
            plan: authReq.userPlan,
          },
          created_at: new Date().toISOString(),
        });

      if (insertError) {
        console.error("[Sessions/Report] Insert failed:", insertError.message);
        res.status(500).json({ error: "Failed to store session data" });
        return;
      }

      res.json({ received: true });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Unknown error";
      console.error("[Sessions/Report] Error:", msg);
      res
        .status(500)
        .json({ error: isDev() ? msg : "Internal server error" });
    }
  },
);

// ---------------------------------------------------------------------------
// 11. Cron Jobs (automated business processes)
//
// Each job is wrapped in a try/catch that logs but NEVER re-throws, so a
// cron failure can never crash the server process.
// ---------------------------------------------------------------------------

// Weekly AI digest -- every Monday at 8:03 AM
cron.schedule("3 8 * * 1", async () => {
  console.log("[Cron] Running weekly digest...");
  try {
    const result = await runWeeklyDigest();
    console.log(`[Cron] Weekly digest finished: sent=${result.sent}, errors=${result.errors}, ${result.durationMs}ms`);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("[Cron] Weekly digest failed:", msg);
  }
});

// Trial reminders -- daily at 9:17 AM
cron.schedule("17 9 * * *", async () => {
  console.log("[Cron] Running trial reminders...");
  try {
    const result = await runTrialReminders();
    console.log(`[Cron] Trial reminders finished: sent=${result.sent}, errors=${result.errors}, ${result.durationMs}ms`);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("[Cron] Trial reminders failed:", msg);
  }
});

// Data cleanup -- daily at 3:42 AM
cron.schedule("42 3 * * *", async () => {
  console.log("[Cron] Running data cleanup...");
  try {
    const result = await runDataCleanup();
    console.log(
      `[Cron] Data cleanup finished: users=${result.usersProcessed}, deleted=${result.sessionsDeleted}, errors=${result.errors}, ${result.durationMs}ms`,
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("[Cron] Data cleanup failed:", msg);
  }
});

// ---------------------------------------------------------------------------
// 12. Global error handler
// ---------------------------------------------------------------------------

app.use(
  (
    err: Error,
    req: express.Request,
    res: express.Response,
    _next: express.NextFunction,
  ) => {
    const requestId = req.headers["x-request-id"] as string | undefined;
    console.error(
      `[Unhandled Error] ${req.method} ${req.originalUrl}` +
        (requestId ? ` rid=${requestId}` : "") +
        `: ${err.message}`,
    );

    if (isDev()) {
      console.error(err.stack);
    }

    res.status(500).json({
      error: isDev() ? err.message : "Internal server error",
      ...(requestId && { requestId }),
    });
  },
);

// ---------------------------------------------------------------------------
// 13. Start + graceful shutdown
// ---------------------------------------------------------------------------

const port = getEnv().PORT;

const server = app.listen(port, () => {
  console.log(`
---------------------------------------------------------------
  drift backend v1.1.0
  http://localhost:${port}
  env: ${getEnv().NODE_ENV}

  Endpoints:
    GET  /api/health              Health check (deep)
    POST /api/auth/signup         Register
    POST /api/auth/login          Login
    POST /api/auth/refresh        Refresh token
    POST /api/auth/logout         Logout
    POST /api/auth/forgot-password Password reset
    GET  /api/me                  User profile
    GET  /api/billing/plans       List plans
    GET  /api/billing/status      Sub status
    POST /api/billing/checkout    Start checkout
    POST /api/billing/portal      Customer portal
    POST /api/coaching/session    AI session coaching
    POST /api/coaching/classify   AI classification
    GET  /api/coaching/usage      AI usage stats
    GET  /api/coaching/history    Past coaching
    POST /api/teams               Create team
    GET  /api/teams/:id           Team details
    POST /api/teams/:id/invite    Invite member
    GET  /api/teams/:id/analytics Team analytics
    POST /api/sessions/start      Start session
    POST /api/sessions/:id/end    End session
    POST /api/sessions/:id/events Batch events
    GET  /api/sessions/history    Session history
    GET  /api/sessions/daily      Daily aggregates
    POST /api/sessions/study      Log study session
    POST /api/sessions/report     Report session
    GET  /api/preferences         Get preferences
    PATCH /api/preferences        Update preferences
    GET  /api/preferences/app-rules  App rules
    POST /api/preferences/app-rules  Add rule

  Cron Jobs:
    Mon 8:03am   Weekly AI digest
    Daily 9:17am Trial reminders
    Daily 3:42am Data cleanup
---------------------------------------------------------------
  `);

  setupAuthWebhook();
});

// -- Graceful shutdown -------------------------------------------------------

let isShuttingDown = false;

async function gracefulShutdown(signal: string): Promise<void> {
  if (isShuttingDown) return;
  isShuttingDown = true;

  console.log(`\n[Shutdown] Received ${signal}. Closing server...`);

  // Stop accepting new connections
  server.close((err) => {
    if (err) {
      console.error("[Shutdown] Error closing server:", err.message);
      process.exit(1);
    }

    console.log("[Shutdown] HTTP server closed. Cleaning up...");

    // Allow in-flight requests a grace period before forced exit
    setTimeout(() => {
      console.log("[Shutdown] Grace period expired. Exiting.");
      process.exit(0);
    }, 10_000).unref();
  });

  // Force exit after 30 seconds regardless
  setTimeout(() => {
    console.error("[Shutdown] Forced exit after 30s timeout.");
    process.exit(1);
  }, 30_000).unref();
}

process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT", () => gracefulShutdown("SIGINT"));

// Catch unhandled promise rejections -- log but do not crash
process.on("unhandledRejection", (reason: unknown) => {
  const msg = reason instanceof Error ? reason.message : String(reason);
  console.error("[UnhandledRejection]", msg);
  if (reason instanceof Error && reason.stack) {
    console.error(reason.stack);
  }
});

export default app;
