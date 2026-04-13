// ---------------------------------------------------------------------------
// Drift -- AI Coaching Routes
// ---------------------------------------------------------------------------

import { Router, Request, Response } from "express";
import { z } from "zod";
import { requireAuth, requirePlan, AuthenticatedRequest } from "../middleware/auth.js";
import { rateLimit } from "../middleware/rateLimit.js";
import {
  generateSessionCoaching,
  classifyDomainWithAI,
  batchClassifyDomains,
  getAIUsageForUser,
  SessionData,
} from "../services/ai-coach.js";
import { getPlan } from "../config/plans.js";
import { getSupabaseAdmin } from "../config/supabase.js";
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
      console.error(`[Coaching] Unhandled error on ${req.method} ${req.path}:`, message);
      res.status(500).json(apiError("INTERNAL_ERROR", "An unexpected error occurred"));
    });
  };
}

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

function computeETag(payload: unknown): string {
  const hash = crypto.createHash("md5").update(JSON.stringify(payload)).digest("hex");
  return `W/"${hash}"`;
}

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

const topDomainSchema = z.object({
  domain: z.string().min(1).max(253),
  timeMs: z.number().int().min(0),
});

const driftPointSchema = z.object({
  reason: z.string().max(500),
  trigger: z.string().max(200),
  timestamp: z.number(),
});

const sessionCoachingSchema = z.object({
  totalDurationMs: z.number().int().min(1, "Session must have a duration"),
  productiveTimeMs: z.number().int().min(0).default(0),
  neutralTimeMs: z.number().int().min(0).default(0),
  distractionTimeMs: z.number().int().min(0).default(0),
  driftScore: z.number().min(0).max(100).default(0),
  driftPointCount: z.number().int().min(0).default(0),
  topDomains: z.array(topDomainSchema).min(1, "At least one domain is required").max(50),
  driftPoints: z.array(driftPointSchema).max(100).default([]),
  entryDomain: z.string().max(253).default("unknown"),
  exitDomain: z.string().max(253).default("unknown"),
  categorySwitchCount: z.number().int().min(0).default(0),
  longestProductiveStreakMs: z.number().int().min(0).default(0),
  longestDistractionStreakMs: z.number().int().min(0).default(0),
});

/** Regex: standard domain name (no protocol, no path) */
const DOMAIN_PATTERN = /^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$/;

const classifySchema = z.object({
  domain: z
    .string()
    .min(1)
    .max(253)
    .transform((v) => v.replace(/[^\x20-\x7E]/g, ""))
    .refine((v) => DOMAIN_PATTERN.test(v), { message: "Invalid domain format" }),
  title: z
    .string()
    .max(500)
    .transform((v) => v.replace(/[^\x20-\x7E\s]/g, ""))
    .optional(),
  url: z.string().url().max(2000).optional(),
});

const batchClassifySchema = z.object({
  domains: z
    .array(
      z.object({
        domain: z.string().min(1).max(253),
        title: z.string().max(500).optional(),
      }),
    )
    .min(1, "At least one domain is required")
    .max(20, "Maximum 20 domains per batch"),
});

const historyQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// ---------------------------------------------------------------------------
// POST /api/coaching/session -- Get AI coaching for a session
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/coaching/session
 * @desc    Generate AI coaching insights for a completed tracking session.
 *          Subject to daily AI usage quota.
 * @access  Private (Bearer token, Pro/Team plan required)
 * @body    SessionData
 * @returns CoachingResponse
 */
router.post(
  "/session",
  requireAuth,
  requirePlan("pro", "team"),
  rateLimit("ai"),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(sessionCoachingSchema, req, res);
    if (!body) return;

    const authReq = req as AuthenticatedRequest;

    // Check daily AI quota
    const plan = getPlan(authReq.userPlan);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const usage = await getAIUsageForUser(authReq.userId, today);

    if (usage.requests >= plan.features.aiCoachingPerDay) {
      res.status(429).json(
        apiError("AI_QUOTA_EXCEEDED", "Daily AI coaching limit reached", {
          limit: plan.features.aiCoachingPerDay,
          used: usage.requests,
          resetsAt: new Date(today.getTime() + 86_400_000).toISOString(),
        }),
      );
      return;
    }

    const coaching = await generateSessionCoaching(authReq.userId, body as SessionData);
    res.json(coaching);
  }),
);

// ---------------------------------------------------------------------------
// POST /api/coaching/classify -- AI domain classification
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/coaching/classify
 * @desc    Classify a single domain as productive / neutral / distraction.
 * @access  Private (Bearer token, Pro/Team plan required)
 * @body    { domain: string, title?: string, url?: string }
 * @returns { category, confidence, reason }
 */
router.post(
  "/classify",
  requireAuth,
  requirePlan("pro", "team"),
  rateLimit("ai"),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(classifySchema, req, res);
    if (!body) return;

    const result = await classifyDomainWithAI(body.domain, body.title, body.url);
    res.json(result);
  }),
);

// ---------------------------------------------------------------------------
// POST /api/coaching/classify-batch -- Batch AI classification
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/coaching/classify-batch
 * @desc    Classify up to 20 domains in a single request.
 * @access  Private (Bearer token, Pro/Team plan required)
 * @body    { domains: { domain: string, title?: string }[] }
 * @returns Record<string, { category, confidence }>
 */
router.post(
  "/classify-batch",
  requireAuth,
  requirePlan("pro", "team"),
  rateLimit("ai"),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(batchClassifySchema, req, res);
    if (!body) return;

    const results = await batchClassifyDomains(body.domains);
    res.json(Object.fromEntries(results));
  }),
);

// ---------------------------------------------------------------------------
// GET /api/coaching/usage -- AI usage stats
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/coaching/usage
 * @desc    Return today's and this month's AI usage stats with plan limits.
 * @access  Private (Bearer token)
 * @returns { today: { used, limit, remaining }, month: { requests, tokensUsed, estimatedCost } }
 */
router.get(
  "/usage",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayUsage = await getAIUsageForUser(authReq.userId, today);

    const monthStart = new Date();
    monthStart.setDate(1);
    monthStart.setHours(0, 0, 0, 0);
    const monthUsage = await getAIUsageForUser(authReq.userId, monthStart);

    const plan = getPlan(authReq.userPlan);

    const payload = {
      today: {
        used: todayUsage.requests,
        limit: plan.features.aiCoachingPerDay,
        remaining: Math.max(0, plan.features.aiCoachingPerDay - todayUsage.requests),
      },
      month: {
        requests: monthUsage.requests,
        tokensUsed: monthUsage.inputTokens + monthUsage.outputTokens,
        estimatedCost: `$${monthUsage.estimatedCost.toFixed(4)}`,
      },
    };

    if (handleConditionalGet(req, res, payload, 30)) return;
    res.json(payload);
  }),
);

// ---------------------------------------------------------------------------
// GET /api/coaching/history -- Past coaching responses (paginated)
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/coaching/history
 * @desc    Return a paginated list of past AI coaching responses.
 * @access  Private (Bearer token, Pro/Team plan required)
 * @query   limit (1-50, default 20), offset (default 0)
 * @returns { history: CoachingHistoryEntry[], pagination }
 */
router.get(
  "/history",
  requireAuth,
  requirePlan("pro", "team"),
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const query = validateQuery(historyQuerySchema, req, res);
    if (!query) return;

    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    // Total count for pagination
    const { count: total } = await sb
      .from("ai_coaching_history")
      .select("id", { count: "exact", head: true })
      .eq("user_id", authReq.userId);

    const { data, error } = await sb
      .from("ai_coaching_history")
      .select("id, coaching_response, created_at")
      .eq("user_id", authReq.userId)
      .order("created_at", { ascending: false })
      .range(query.offset, query.offset + query.limit - 1);

    if (error) throw error;

    const payload = {
      history: data ?? [],
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

export default router;
