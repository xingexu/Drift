// ---------------------------------------------------------------------------
// Drift -- Team Management Routes
// ---------------------------------------------------------------------------

import { Router, Request, Response } from "express";
import { z } from "zod";
import { requireAuth, requirePlan, AuthenticatedRequest } from "../middleware/auth.js";
import { rateLimit } from "../middleware/rateLimit.js";
import { getSupabaseAdmin } from "../config/supabase.js";
import { getPlan } from "../config/plans.js";
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
      console.error(`[Teams] Unhandled error on ${req.method} ${req.path}:`, message);
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

/** UUID v4 format for Supabase team IDs */
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const teamIdParam = z.object({
  teamId: z.string().regex(uuidPattern, "Invalid team ID format"),
});

const createTeamSchema = z.object({
  name: z
    .string()
    .min(1, "Team name is required")
    .max(100, "Team name must not exceed 100 characters")
    .trim()
    .transform((v) => v.replace(/[<>&"']/g, "")), // Strip HTML-unsafe characters
});

const inviteSchema = z.object({
  email: z
    .string()
    .email("Invalid email address")
    .max(254)
    .trim()
    .toLowerCase(),
});

const analyticsQuerySchema = z.object({
  days: z.coerce.number().int().min(1).max(90).default(7),
});

// ---------------------------------------------------------------------------
// Reusable middleware: verify team membership
// ---------------------------------------------------------------------------

type TeamRole = "owner" | "admin" | "member";

/**
 * Verify the authenticated user is a member of the given team.
 * Returns the membership role or sends an appropriate error response.
 */
async function verifyTeamMembership(
  authReq: AuthenticatedRequest,
  teamId: string,
  res: Response,
  requiredRoles?: TeamRole[],
): Promise<TeamRole | null> {
  const sb = getSupabaseAdmin();
  const { data: membership } = await sb
    .from("team_members")
    .select("role")
    .eq("team_id", teamId)
    .eq("user_id", authReq.userId)
    .single();

  if (!membership) {
    res.status(403).json(apiError("NOT_TEAM_MEMBER", "You are not a member of this team"));
    return null;
  }

  if (requiredRoles && !requiredRoles.includes(membership.role as TeamRole)) {
    res.status(403).json(
      apiError(
        "INSUFFICIENT_ROLE",
        `This action requires one of: ${requiredRoles.join(", ")}`,
        { currentRole: membership.role },
      ),
    );
    return null;
  }

  return membership.role as TeamRole;
}

// ---------------------------------------------------------------------------
// POST /api/teams -- Create a team
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/teams
 * @desc    Create a new team. The caller becomes the owner. Each user may
 *          own at most one team (idempotency: returns existing team on 409).
 * @access  Private (Bearer token, Team plan required)
 * @body    { name: string }
 * @returns { team: Team } (201 on create, 409 if already owns a team)
 */
router.post(
  "/",
  requireAuth,
  requirePlan("team"),
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const body = validateBody(createTeamSchema, req, res);
    if (!body) return;

    const authReq = req as AuthenticatedRequest;
    const sb = getSupabaseAdmin();

    // Idempotency: check if user already owns a team
    const { data: existing } = await sb
      .from("teams")
      .select("id, name")
      .eq("owner_id", authReq.userId)
      .single();

    if (existing) {
      res.status(409).json(
        apiError("TEAM_EXISTS", "You already own a team", { teamId: existing.id }),
      );
      return;
    }

    const { data: team, error } = await sb
      .from("teams")
      .insert({
        name: body.name,
        owner_id: authReq.userId,
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) throw error;

    // Add the owner as the first member
    await sb.from("team_members").insert({
      team_id: team.id,
      user_id: authReq.userId,
      role: "owner",
      joined_at: new Date().toISOString(),
    });

    res.status(201).json({ team });
  }),
);

// ---------------------------------------------------------------------------
// GET /api/teams/:teamId -- Get team details
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/teams/:teamId
 * @desc    Return team metadata, member list, and the caller's role.
 * @access  Private (Bearer token, Team plan required, must be a member)
 * @returns { team, members, yourRole }
 */
router.get(
  "/:teamId",
  requireAuth,
  requirePlan("team"),
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const params = teamIdParam.safeParse(req.params);
    if (!params.success) {
      res.status(400).json(apiError("VALIDATION_ERROR", "Invalid team ID format"));
      return;
    }

    const authReq = req as AuthenticatedRequest;
    const role = await verifyTeamMembership(authReq, params.data.teamId, res);
    if (!role) return;

    const sb = getSupabaseAdmin();
    const { data: team } = await sb
      .from("teams")
      .select("*")
      .eq("id", params.data.teamId)
      .single();

    if (!team) {
      res.status(404).json(apiError("TEAM_NOT_FOUND", "Team not found"));
      return;
    }

    const { data: members } = await sb
      .from("team_members")
      .select("user_id, role, joined_at")
      .eq("team_id", params.data.teamId);

    const payload = { team, members: members ?? [], yourRole: role };

    if (handleConditionalGet(req, res, payload, 30)) return;
    res.json(payload);
  }),
);

// ---------------------------------------------------------------------------
// POST /api/teams/:teamId/invite -- Invite a member
// ---------------------------------------------------------------------------

/**
 * @route   POST /api/teams/:teamId/invite
 * @desc    Send a team invitation to an email address. Only owners and admins
 *          may invite. Enforces the plan's max-team-members limit.
 *          Idempotent -- re-inviting the same email returns the existing invite.
 * @access  Private (Bearer token, Team plan, owner/admin role)
 * @body    { email: string }
 * @returns { invite } (201)
 */
router.post(
  "/:teamId/invite",
  requireAuth,
  requirePlan("team"),
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const params = teamIdParam.safeParse(req.params);
    if (!params.success) {
      res.status(400).json(apiError("VALIDATION_ERROR", "Invalid team ID format"));
      return;
    }

    const body = validateBody(inviteSchema, req, res);
    if (!body) return;

    const authReq = req as AuthenticatedRequest;
    const role = await verifyTeamMembership(authReq, params.data.teamId, res, ["owner", "admin"]);
    if (!role) return;

    const sb = getSupabaseAdmin();

    // Check team size limit
    const plan = getPlan(authReq.userPlan);
    const { count } = await sb
      .from("team_members")
      .select("*", { count: "exact", head: true })
      .eq("team_id", params.data.teamId);

    if ((count ?? 0) >= plan.features.maxTeamMembers) {
      res.status(403).json(
        apiError("TEAM_LIMIT_REACHED", `Team size limit of ${plan.features.maxTeamMembers} members reached`),
      );
      return;
    }

    // Idempotency: check for existing pending invite to this email
    const { data: existingInvite } = await sb
      .from("team_invites")
      .select("*")
      .eq("team_id", params.data.teamId)
      .eq("email", body.email)
      .eq("status", "pending")
      .single();

    if (existingInvite) {
      res.status(200).json({ invite: existingInvite, alreadyInvited: true });
      return;
    }

    const { data: invite, error } = await sb
      .from("team_invites")
      .insert({
        team_id: params.data.teamId,
        email: body.email,
        invited_by: authReq.userId,
        status: "pending",
        created_at: new Date().toISOString(),
        expires_at: new Date(Date.now() + 7 * 86_400_000).toISOString(),
      })
      .select()
      .single();

    if (error) throw error;

    res.status(201).json({ invite });
  }),
);

// ---------------------------------------------------------------------------
// GET /api/teams/:teamId/analytics -- Team-wide analytics (paginated period)
// ---------------------------------------------------------------------------

/**
 * @route   GET /api/teams/:teamId/analytics
 * @desc    Return aggregate analytics across all team members for the last N
 *          days. Non-admin members see anonymised per-member stats.
 * @access  Private (Bearer token, Team plan, must be a member)
 * @query   days (1-90, default 7)
 * @returns { teamId, period, memberCount, totals, members[] }
 */
router.get(
  "/:teamId/analytics",
  requireAuth,
  requirePlan("team"),
  rateLimit("api"),
  asyncHandler(async (req: Request, res: Response) => {
    const params = teamIdParam.safeParse(req.params);
    if (!params.success) {
      res.status(400).json(apiError("VALIDATION_ERROR", "Invalid team ID format"));
      return;
    }

    const query = validateQuery(analyticsQuerySchema, req, res);
    if (!query) return;

    const authReq = req as AuthenticatedRequest;
    const role = await verifyTeamMembership(authReq, params.data.teamId, res);
    if (!role) return;

    const sb = getSupabaseAdmin();

    // Get all team member IDs
    const { data: members } = await sb
      .from("team_members")
      .select("user_id")
      .eq("team_id", params.data.teamId);

    const memberIds = (members ?? []).map((m) => m.user_id);

    if (memberIds.length === 0) {
      const emptyPayload = {
        teamId: params.data.teamId,
        period: `${query.days}d`,
        memberCount: 0,
        totalSessions: 0,
        totalTimeMs: 0,
        totalProductiveMs: 0,
        totalDistractionMs: 0,
        averageDriftScore: 0,
        members: [],
      };
      if (handleConditionalGet(req, res, emptyPayload, 60)) return;
      res.json(emptyPayload);
      return;
    }

    // Fetch sessions for the period
    const cutoff = new Date(Date.now() - query.days * 86_400_000).toISOString();
    const { data: sessions } = await sb
      .from("session_history")
      .select("*")
      .in("user_id", memberIds)
      .gte("start_time", cutoff)
      .order("start_time", { ascending: false });

    const allSessions = sessions ?? [];
    const totalSessions = allSessions.length;
    const totalTime = allSessions.reduce((s, e) => s + (e.total_active_time_ms ?? 0), 0);
    const totalProductive = allSessions.reduce((s, e) => s + (e.productive_time_ms ?? 0), 0);
    const totalDistraction = allSessions.reduce((s, e) => s + (e.distraction_time_ms ?? 0), 0);
    const avgDrift =
      totalSessions > 0
        ? Math.round(allSessions.reduce((s, e) => s + (e.drift_score ?? 0), 0) / totalSessions)
        : 0;

    const isPrivileged = ["owner", "admin"].includes(role);

    const memberStats = memberIds.map((uid) => {
      const userSessions = allSessions.filter((s) => s.user_id === uid);
      return {
        // Only reveal user IDs to owners/admins
        userId: isPrivileged ? uid : undefined,
        sessionCount: userSessions.length,
        totalTimeMs: userSessions.reduce((s, e) => s + (e.total_active_time_ms ?? 0), 0),
        avgDriftScore:
          userSessions.length > 0
            ? Math.round(
                userSessions.reduce((s, e) => s + (e.drift_score ?? 0), 0) / userSessions.length,
              )
            : 0,
      };
    });

    const payload = {
      teamId: params.data.teamId,
      period: `${query.days}d`,
      memberCount: memberIds.length,
      totalSessions,
      totalTimeMs: totalTime,
      totalProductiveMs: totalProductive,
      totalDistractionMs: totalDistraction,
      averageDriftScore: avgDrift,
      members: memberStats,
    };

    if (handleConditionalGet(req, res, payload, 60)) return;
    res.json(payload);
  }),
);

export default router;
