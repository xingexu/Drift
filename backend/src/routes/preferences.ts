// ---------------------------------------------------------------------------
// Drift -- User Preferences Routes
// Syncs settings between desktop app and cloud.
// ---------------------------------------------------------------------------

import { Router, Request, Response } from "express";
import { z } from "zod";
import { requireAuth, AuthenticatedRequest } from "../middleware/auth.js";
import { rateLimit } from "../middleware/rateLimit.js";
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
      console.error(`[Preferences] Unhandled error on ${req.method} ${req.path}:`, message);
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

/**
 * Schema for focus_block_list: array of domain strings the user wants to
 * block during focus sessions. Each entry is sanitised to a safe domain pattern.
 */
const blockListItemSchema = z
  .string()
  .min(1)
  .max(253)
  .transform((v) => v.replace(/[<>&"']/g, "").trim().toLowerCase());

/**
 * Custom app rule stored in the `custom_app_rules` JSON column.
 */
const customAppRuleEntrySchema = z.object({
  pattern: z.string().min(1).max(253),
  patternType: z.enum(["exact", "contains", "regex"]).default("exact"),
  target: z.enum(["app", "domain", "title"]).default("app"),
  category: z.enum(["productive", "neutral", "distraction"]),
});

const updatePreferencesSchema = z
  .object({
    idle_timeout_seconds: z.number().int().min(30).max(3600).optional(),
    launch_at_login: z.boolean().optional(),
    show_tray: z.boolean().optional(),
    notifications_enabled: z.boolean().optional(),
    theme: z.enum(["system", "light", "dark"]).optional(),
    focus_block_list: z.array(blockListItemSchema).max(200).optional(),
    custom_app_rules: z.array(customAppRuleEntrySchema).max(500).optional(),
  })
  .strict()
  .refine((obj) => Object.keys(obj).length > 0, {
    message: "At least one preference field is required",
  });

const addAppRuleSchema = z.object({
  pattern: z
    .string()
    .min(1, "Pattern is required")
    .max(253)
    .transform((v) => v.replace(/[<>&"']/g, "").trim()),
  patternType: z.enum(["exact", "contains", "regex"]).default("exact"),
  target: z.enum(["app", "domain", "title"]).default("app"),
  category: z.enum(["productive", "neutral", "distraction"], {
    errorMap: () => ({ message: "Category must be productive, neutral, or distraction" }),
  }),
});

const ruleIdParam = z.object({
  id: z.coerce.number().int().positive("Rule ID must be a positive integer"),
});

// ---------------------------------------------------------------------------
// GET /api/preferences -- Get user preferences
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/preferences
 * @desc    Return the authenticated user's preferences. Lazily creates the
 *          row with defaults if it does not exist yet.
 * @access  Private (Bearer token)
 * @returns UserPreferences
 */
router.get(
  "/",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    const { data, error } = await sb
      .from("user_preferences")
      .select("*")
      .eq("user_id", authReq.userId)
      .single();

    if (error && error.code !== "PGRST116") throw error;

    if (!data) {
      // Lazily create default preferences
      const { data: created, error: createErr } = await sb
        .from("user_preferences")
        .insert({ user_id: authReq.userId })
        .select("*")
        .single();

      if (createErr) throw createErr;

      // New row -- no conditional GET needed
      res.setHeader("Cache-Control", "private, max-age=0");
      res.json(created);
      return;
    }

    if (handleConditionalGet(req, res, data, 30)) return;
    res.json(data);
  }),
);

// ---------------------------------------------------------------------------
// PATCH /api/preferences -- Update user preferences
// ---------------------------------------------------------------------------

/**
 * @route   PATCH /api/preferences
 * @desc    Partially update user preferences. Only whitelisted fields are
 *          accepted; unknown keys result in a 400.
 * @access  Private (Bearer token)
 * @body    Partial<UserPreferences> (at least one field)
 * @returns Updated UserPreferences
 */
router.patch(
  "/",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(updatePreferencesSchema, req, res);
    if (!body) return;

    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    const { data, error } = await sb
      .from("user_preferences")
      .update(body)
      .eq("user_id", authReq.userId)
      .select("*")
      .single();

    if (error) {
      // If the row does not exist, upsert it
      if (error.code === "PGRST116") {
        const { data: created, error: createErr } = await sb
          .from("user_preferences")
          .insert({ user_id: authReq.userId, ...body })
          .select("*")
          .single();
        if (createErr) throw createErr;
        res.json(created);
        return;
      }
      throw error;
    }

    res.json(data);
  }),
);

// ---------------------------------------------------------------------------
// GET /api/preferences/app-rules -- Get custom app classification rules
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/preferences/app-rules
 * @desc    Return the list of user-defined app classification rules.
 * @access  Private (Bearer token)
 * @returns { rules: AppRule[] }
 */
router.get(
  "/app-rules",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    const { data, error } = await sb
      .from("app_rules")
      .select("*")
      .eq("user_id", authReq.userId)
      .order("created_at", { ascending: false });

    if (error) throw error;

    const payload = { rules: data || [] };

    if (handleConditionalGet(req, res, payload, 30)) return;
    res.json(payload);
  }),
);

// ---------------------------------------------------------------------------
// POST /api/preferences/app-rules -- Add a custom app rule (idempotent upsert)
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/preferences/app-rules
 * @desc    Create or update a custom app classification rule. Uses a Postgres
 *          upsert on (user_id, pattern, target) for idempotency.
 * @access  Private (Bearer token)
 * @body    { pattern, patternType?, target?, category }
 * @returns AppRule
 */
router.post(
  "/app-rules",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(addAppRuleSchema, req, res);
    if (!body) return;

    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    const { data, error } = await sb
      .from("app_rules")
      .upsert(
        {
          user_id: authReq.userId,
          pattern: body.pattern,
          pattern_type: body.patternType,
          target: body.target,
          category: body.category,
        },
        { onConflict: "user_id, pattern, target" },
      )
      .select("*")
      .single();

    if (error) throw error;

    res.status(201).json(data);
  }),
);

// ---------------------------------------------------------------------------
// DELETE /api/preferences/app-rules/:id -- Remove a custom app rule
// ---------------------------------------------------------------------------

/**
 * @route   DELETE /api/preferences/app-rules/:id
 * @desc    Delete a custom app rule by ID. The rule must belong to the caller.
 *          Idempotent -- deleting a non-existent rule returns 200.
 * @access  Private (Bearer token)
 * @returns { deleted: true }
 */
router.delete(
  "/app-rules/:id",
  requireAuth,
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const params = ruleIdParam.safeParse(req.params);
    if (!params.success) {
      res.status(400).json(apiError("VALIDATION_ERROR", "Invalid rule ID"));
      return;
    }

    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    // Verify the rule exists and belongs to the user
    const { data: existing } = await sb
      .from("app_rules")
      .select("id")
      .eq("id", params.data.id)
      .eq("user_id", authReq.userId)
      .single();

    if (!existing) {
      // Idempotent: treat as success even if already deleted or never existed
      res.json({ deleted: true });
      return;
    }

    const { error } = await sb
      .from("app_rules")
      .delete()
      .eq("id", params.data.id)
      .eq("user_id", authReq.userId);

    if (error) throw error;

    res.json({ deleted: true });
  }),
);

export default router;
