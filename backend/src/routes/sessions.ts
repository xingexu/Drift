// ---------------------------------------------------------------------------
// Drift -- Desktop Session Routes
// Handles app session tracking, daily aggregates, and study sessions.
// ---------------------------------------------------------------------------

import { Router, Request, Response } from "express";
import { z } from "zod";
import { requireAuth, AuthenticatedRequest } from "../middleware/auth.js";
import { rateLimit } from "../middleware/rateLimit.js";
import { getSupabaseAdmin } from "../config/supabase.js";
import { getPlan, type PlanId } from "../config/plans.js";
import crypto from "node:crypto";

const router = Router();

// ---------------------------------------------------------------------------
// Shared types & helpers
// ---------------------------------------------------------------------------

interface ApiErrorResponse {
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}

function apiError(code: string, message: string, details?: unknown): ApiErrorResponse {
  return { error: { code, message, ...(details !== undefined && { details }) } };
}

function asyncHandler(
  fn: (req: Request, res: Response) => Promise<void>,
): (req: Request, res: Response) => void {
  return (req, res) => {
    fn(req, res).catch((err: unknown) => {
      const message = err instanceof Error ? err.message : "Unknown error";
      console.error(`[Sessions] Unhandled error on ${req.method} ${req.path}:`, message);
      res.status(500).json(apiError("INTERNAL_ERROR", "An unexpected error occurred"));
    });
  };
}

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
    res.status(400).json(apiError("VALIDATION_ERROR", details[0].message, details));
    return null;
  }
  return result.data;
}

/** Validate Zod schema against `req.query` and return parsed data or send 400. */
function validateQuery<T extends z.ZodTypeAny>(
  schema: T,
  req: Request,
  res: Response,
): z.infer<T> | null {
  const result = schema.safeParse(req.query);
  if (!result.success) {
    const details = result.error.issues.map((i) => ({
      field: i.path.join("."),
      message: i.message,
    }));
    res.status(400).json(apiError("VALIDATION_ERROR", details[0].message, details));
    return null;
  }
  return result.data;
}

/**
 * Compute a simple ETag from a JSON-serialisable payload.
 * Uses a fast hash -- not cryptographic, just cache-friendly.
 */
function computeETag(payload: unknown): string {
  const hash = crypto.createHash("md5").update(JSON.stringify(payload)).digest("hex");
  return `W/"${hash}"`;
}

/** Set standard cache headers and check If-None-Match for conditional GETs. Returns true if 304 was sent. */
function handleConditionalGet(
  req: Request,
  res: Response,
  payload: unknown,
  maxAge: number = 0,
): boolean {
  const etag = computeETag(payload);
  res.setHeader("ETag", etag);
  res.setHeader("Cache-Control", `private, max-age=${maxAge}`);

  if (req.headers["if-none-match"] === etag) {
    res.status(304).end();
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Validation schemas
// ---------------------------------------------------------------------------

const startSessionSchema = z.object({
  platform: z
    .enum(["desktop", "web", "mobile"], {
      errorMap: () => ({ message: "platform must be desktop, web, or mobile" }),
    })
    .default("desktop"),
});

const endSessionSchema = z.object({
  totalDurationMs: z.number().int().min(0).default(0),
  productiveMs: z.number().int().min(0).default(0),
  neutralMs: z.number().int().min(0).default(0),
  distractionMs: z.number().int().min(0).default(0),
  driftScore: z.number().min(0).max(100).default(0),
  appSwitchCount: z.number().int().min(0).default(0),
  uniqueApps: z.number().int().min(0).default(0),
});

const appEventSchema = z.object({
  owner: z.string().max(200).optional(),
  appName: z.string().max(200).optional(),
  title: z.string().max(500).optional(),
  url: z.string().max(2000).optional(),
  isBrowser: z.boolean().optional(),
  category: z.enum(["productive", "neutral", "distraction"]).default("neutral"),
  timestamp: z.number().optional(),
  durationMs: z.number().int().min(0).default(0),
});

const eventsBodySchema = z.object({
  events: z.array(appEventSchema).min(1, "At least one event is required").max(500),
});

const historyQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
  sort: z.enum(["start_time", "drift_score", "total_duration_ms"]).default("start_time"),
  order: z.enum(["asc", "desc"]).default("desc"),
});

const dailyQuerySchema = z.object({
  days: z.coerce.number().int().min(1).max(90).default(7),
});

const studySessionSchema = z.object({
  subject: z.string().max(200).trim().optional(),
  focusDurationMin: z.number().int().min(1).max(120).default(25),
  breakDurationMin: z.number().int().min(0).max(60).default(5),
  sessionsCompleted: z.number().int().min(0).default(0),
  totalFocusTimeMs: z.number().int().min(0).default(0),
});

const sessionIdParam = z.object({
  id: z.coerce.number().int().positive("Session ID must be a positive integer"),
});

// ---------------------------------------------------------------------------
// POST /api/sessions/start -- Begin a new tracking session
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/sessions/start
 * @desc    Create a new app-tracking session. Enforces free-plan session limits.
 * @access  Private (Bearer token)
 * @body    { platform?: "desktop" | "web" | "mobile" }
 * @returns { sessionId: number }
 */
router.post(
  "/start",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(startSessionSchema, req, res);
    if (!body) return;

    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    // Check session limit for free users
    const { data: profile } = await sb
      .from("user_profiles")
      .select("plan")
      .eq("user_id", authReq.userId)
      .single();

    const userPlan = getPlan((profile?.plan as PlanId) || "free");

    if (userPlan.features.maxSessions > 0) {
      const { count, error: countErr } = await sb
        .from("app_sessions")
        .select("id", { count: "exact", head: true })
        .eq("user_id", authReq.userId);

      if (!countErr && count !== null && count >= userPlan.features.maxSessions) {
        res.status(403).json(
          apiError("SESSION_LIMIT_REACHED", `You've used all ${userPlan.features.maxSessions} free sessions. Upgrade to Pro for unlimited tracking.`, {
            sessionsUsed: count,
            sessionsLimit: userPlan.features.maxSessions,
          }),
        );
        return;
      }
    }

    const { data, error } = await sb
      .from("app_sessions")
      .insert({
        user_id: authReq.userId,
        start_time: new Date().toISOString(),
        platform: body.platform,
      })
      .select("id")
      .single();

    if (error) throw error;

    res.status(201).json({ sessionId: data.id });
  }),
);

// ---------------------------------------------------------------------------
// POST /api/sessions/:id/end -- End a tracking session
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/sessions/:id/end
 * @desc    Finalise a session with aggregated stats and update the daily aggregate.
 *          Idempotent -- ending an already-ended session returns the existing data.
 * @access  Private (Bearer token)
 * @body    { totalDurationMs, productiveMs, neutralMs, distractionMs, driftScore, appSwitchCount, uniqueApps }
 * @returns { success: true }
 */
router.post(
  "/:id/end",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const params = sessionIdParam.safeParse(req.params);
    if (!params.success) {
      res.status(400).json(apiError("VALIDATION_ERROR", "Invalid session ID"));
      return;
    }

    const body = validateBody(endSessionSchema, req, res);
    if (!body) return;

    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    // Verify session ownership and check idempotency
    const { data: existing, error: fetchErr } = await sb
      .from("app_sessions")
      .select("id, end_time")
      .eq("id", params.data.id)
      .eq("user_id", authReq.userId)
      .single();

    if (fetchErr || !existing) {
      res.status(404).json(apiError("SESSION_NOT_FOUND", "Session not found or does not belong to you"));
      return;
    }

    // Idempotency: if already ended, return success without re-updating
    if (existing.end_time) {
      res.json({ success: true, alreadyEnded: true });
      return;
    }

    const { error } = await sb
      .from("app_sessions")
      .update({
        end_time: new Date().toISOString(),
        total_duration_ms: body.totalDurationMs,
        productive_time_ms: body.productiveMs,
        neutral_time_ms: body.neutralMs,
        distraction_time_ms: body.distractionMs,
        drift_score: body.driftScore,
        app_switch_count: body.appSwitchCount,
        unique_apps: body.uniqueApps,
      })
      .eq("id", params.data.id)
      .eq("user_id", authReq.userId);

    if (error) throw error;

    // Update daily aggregate (fire-and-forget -- do not block the response)
    updateDailyAggregate(authReq.userId, {
      totalMs: body.totalDurationMs,
      productiveMs: body.productiveMs,
      neutralMs: body.neutralMs,
      distractionMs: body.distractionMs,
      driftScore: body.driftScore,
      appSwitchCount: body.appSwitchCount,
    }).catch((err) => {
      console.error("[Sessions] Failed to update daily aggregate:", err instanceof Error ? err.message : err);
    });

    res.json({ success: true });
  }),
);

// ---------------------------------------------------------------------------
// POST /api/sessions/:id/events -- Batch upload app events
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/sessions/:id/events
 * @desc    Upload a batch of app-usage events (max 500 per request).
 * @access  Private (Bearer token)
 * @body    { events: AppEvent[] }
 * @returns { inserted: number }
 */
router.post(
  "/:id/events",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const params = sessionIdParam.safeParse(req.params);
    if (!params.success) {
      res.status(400).json(apiError("VALIDATION_ERROR", "Invalid session ID"));
      return;
    }

    const body = validateBody(eventsBodySchema, req, res);
    if (!body) return;

    const authReq = req as AuthenticatedRequest;
    const sessionId = params.data.id;
    const sb = getSupabaseAdmin();

    // Verify the session belongs to the caller
    const { data: session, error: sessionErr } = await sb
      .from("app_sessions")
      .select("id")
      .eq("id", sessionId)
      .eq("user_id", authReq.userId)
      .single();

    if (sessionErr || !session) {
      res.status(404).json(apiError("SESSION_NOT_FOUND", "Session not found or does not belong to you"));
      return;
    }

    const rows = body.events.map((e: z.infer<typeof appEventSchema>) => ({
      user_id: authReq.userId,
      session_id: sessionId,
      app_name: (e.owner || e.appName || "Unknown").slice(0, 200),
      window_title: e.title?.slice(0, 500),
      url: e.url?.slice(0, 2000),
      is_browser: !!e.isBrowser,
      category: e.category,
      start_time: new Date(e.timestamp || Date.now()).toISOString(),
      duration_ms: e.durationMs,
    }));

    const { error } = await sb.from("app_events").insert(rows);
    if (error) throw error;

    res.status(201).json({ inserted: rows.length });
  }),
);

// ---------------------------------------------------------------------------
// GET /api/sessions/history -- Paginated session history
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/sessions/history
 * @desc    Return paginated list of past sessions for the authenticated user.
 * @access  Private (Bearer token)
 * @query   limit (1-100, default 20), offset (default 0), sort, order
 * @returns { sessions: Session[], pagination: { limit, offset, total, hasMore } }
 */
router.get(
  "/history",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const query = validateQuery(historyQuerySchema, req, res);
    if (!query) return;

    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    // Fetch total count for pagination metadata
    const { count: total } = await sb
      .from("app_sessions")
      .select("id", { count: "exact", head: true })
      .eq("user_id", authReq.userId);

    const { data, error } = await sb
      .from("app_sessions")
      .select("*")
      .eq("user_id", authReq.userId)
      .order(query.sort, { ascending: query.order === "asc" })
      .range(query.offset, query.offset + query.limit - 1);

    if (error) throw error;

    const payload = {
      sessions: data || [],
      pagination: {
        limit: query.limit,
        offset: query.offset,
        total: total ?? 0,
        hasMore: query.offset + query.limit < (total ?? 0),
      },
    };

    if (handleConditionalGet(req, res, payload, 30)) return;
    res.json(payload);
  }),
);

// ---------------------------------------------------------------------------
// GET /api/sessions/count -- Total session count (for paywall check)
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/sessions/count
 * @desc    Return the total number of sessions and the plan limit. Used by
 *          the client to decide whether to show the upgrade paywall.
 * @access  Private (Bearer token)
 * @returns { count, limit, remaining }
 */
router.get(
  "/count",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    const { count, error } = await sb
      .from("app_sessions")
      .select("id", { count: "exact", head: true })
      .eq("user_id", authReq.userId);

    if (error) throw error;

    const { data: profile } = await sb
      .from("user_profiles")
      .select("plan")
      .eq("user_id", authReq.userId)
      .single();

    const plan = getPlan((profile?.plan as PlanId) || "free");
    const payload = {
      count: count ?? 0,
      limit: plan.features.maxSessions,
      remaining:
        plan.features.maxSessions > 0
          ? Math.max(0, plan.features.maxSessions - (count ?? 0))
          : -1, // -1 = unlimited
    };

    if (handleConditionalGet(req, res, payload, 10)) return;
    res.json(payload);
  }),
);

// ---------------------------------------------------------------------------
// GET /api/sessions/daily -- Daily aggregates
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/sessions/daily
 * @desc    Return daily aggregate stats for the last N days (max 90).
 * @access  Private (Bearer token)
 * @query   days (1-90, default 7)
 * @returns { daily: DailyAggregate[] }
 */
router.get(
  "/daily",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const query = validateQuery(dailyQuerySchema, req, res);
    if (!query) return;

    const authReq = req as AuthenticatedRequest;
    const since = new Date();
    since.setDate(since.getDate() - query.days);
    const sinceStr = since.toISOString().split("T")[0];

    const sb = getSupabaseAdmin();
    const { data, error } = await sb
      .from("daily_aggregates")
      .select("*")
      .eq("user_id", authReq.userId)
      .gte("date", sinceStr)
      .order("date", { ascending: false });

    if (error) throw error;

    const payload = { daily: data || [] };

    if (handleConditionalGet(req, res, payload, 60)) return;
    res.json(payload);
  }),
);

// ---------------------------------------------------------------------------
// POST /api/sessions/study -- Log a study session
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/sessions/study
 * @desc    Record a completed Pomodoro / study session.
 * @access  Private (Bearer token)
 * @body    { subject?, focusDurationMin?, breakDurationMin?, sessionsCompleted?, totalFocusTimeMs? }
 * @returns { studySessionId: number }
 */
router.post(
  "/study",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(studySessionSchema, req, res);
    if (!body) return;

    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    const { data, error } = await sb
      .from("study_sessions")
      .insert({
        user_id: authReq.userId,
        subject: body.subject?.slice(0, 200),
        focus_duration_min: body.focusDurationMin,
        break_duration_min: body.breakDurationMin,
        sessions_completed: body.sessionsCompleted,
        total_focus_time_ms: body.totalFocusTimeMs,
        ended_at: new Date().toISOString(),
      })
      .select("id")
      .single();

    if (error) throw error;

    // Update daily study aggregate (fire-and-forget)
    updateStudyAggregate(authReq.userId, {
      sessionsCompleted: body.sessionsCompleted,
      focusMs: body.totalFocusTimeMs,
    }).catch((err) => {
      console.error("[Sessions] Failed to update study aggregate:", err instanceof Error ? err.message : err);
    });

    res.status(201).json({ studySessionId: data.id });
  }),
);

// ---------------------------------------------------------------------------
// Helpers -- Daily Aggregates
// ---------------------------------------------------------------------------

async function updateDailyAggregate(
  userId: string,
  data: {
    totalMs: number;
    productiveMs: number;
    neutralMs: number;
    distractionMs: number;
    driftScore: number;
    appSwitchCount: number;
  },
): Promise<void> {
  const today = new Date().toISOString().split("T")[0];
  const sb = getSupabaseAdmin();

  const { data: existing } = await sb
    .from("daily_aggregates")
    .select("*")
    .eq("user_id", userId)
    .eq("date", today)
    .single();

  if (existing) {
    const newTotal = existing.total_tracked_ms + (data.totalMs || 0);
    const newProd = existing.productive_ms + (data.productiveMs || 0);
    const newNeutral = existing.neutral_ms + (data.neutralMs || 0);
    const newDist = existing.distraction_ms + (data.distractionMs || 0);
    const newCount = existing.session_count + 1;
    const newSwitches = existing.app_switch_count + (data.appSwitchCount || 0);
    const avgDrift =
      newProd + newDist > 0
        ? Math.round((newDist / (newProd + newDist)) * 100)
        : 0;

    await sb
      .from("daily_aggregates")
      .update({
        total_tracked_ms: newTotal,
        productive_ms: newProd,
        neutral_ms: newNeutral,
        distraction_ms: newDist,
        drift_score: avgDrift,
        session_count: newCount,
        app_switch_count: newSwitches,
      })
      .eq("user_id", userId)
      .eq("date", today);
  } else {
    const drift =
      data.productiveMs + data.distractionMs > 0
        ? Math.round(
            (data.distractionMs / (data.productiveMs + data.distractionMs)) * 100,
          )
        : 0;

    await sb.from("daily_aggregates").insert({
      user_id: userId,
      date: today,
      total_tracked_ms: data.totalMs || 0,
      productive_ms: data.productiveMs || 0,
      neutral_ms: data.neutralMs || 0,
      distraction_ms: data.distractionMs || 0,
      drift_score: drift,
      session_count: 1,
      app_switch_count: data.appSwitchCount || 0,
    });
  }
}

async function updateStudyAggregate(
  userId: string,
  data: { sessionsCompleted: number; focusMs: number },
): Promise<void> {
  const today = new Date().toISOString().split("T")[0];
  const sb = getSupabaseAdmin();

  const { data: existing } = await sb
    .from("daily_aggregates")
    .select("study_sessions, study_focus_ms")
    .eq("user_id", userId)
    .eq("date", today)
    .single();

  if (existing) {
    await sb
      .from("daily_aggregates")
      .update({
        study_sessions: existing.study_sessions + data.sessionsCompleted,
        study_focus_ms: existing.study_focus_ms + data.focusMs,
      })
      .eq("user_id", userId)
      .eq("date", today);
  } else {
    await sb.from("daily_aggregates").insert({
      user_id: userId,
      date: today,
      study_sessions: data.sessionsCompleted,
      study_focus_ms: data.focusMs,
    });
  }
}

export default router;
