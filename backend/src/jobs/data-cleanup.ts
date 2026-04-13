// ---------------------------------------------------------------------------
// Drift -- Automated Data Cleanup Job
// Runs daily -- enforces data retention per plan.
//
// Idempotency: safe to re-run. Deletes are filtered by cutoff timestamp so
// running twice in a row produces no additional deletions.
// ---------------------------------------------------------------------------

import { getSupabaseAdmin } from "../config/supabase.js";
import { getPlanSafe } from "../config/plans.js";

// ---------------------------------------------------------------------------
// Health monitoring -- exposed so the health endpoint can report staleness
// ---------------------------------------------------------------------------

let _lastRunAt: Date | null = null;
let _lastRunOk = true;

export function getDataCleanupHealth(): {
  lastRunAt: string | null;
  lastRunOk: boolean;
  staleSinceMs: number | null;
} {
  const staleSinceMs = _lastRunAt
    ? Date.now() - _lastRunAt.getTime()
    : null;
  return {
    lastRunAt: _lastRunAt?.toISOString() ?? null,
    lastRunOk: _lastRunOk,
    staleSinceMs,
  };
}

// ---------------------------------------------------------------------------
// Job implementation
// ---------------------------------------------------------------------------

export interface DataCleanupResult {
  usersProcessed: number;
  sessionsDeleted: number;
  durationMs: number;
  errors: number;
}

export async function runDataCleanup(): Promise<DataCleanupResult> {
  const start = Date.now();
  const sb = getSupabaseAdmin();
  let usersProcessed = 0;
  let sessionsDeleted = 0;
  let errors = 0;

  console.log("[Data Cleanup] Starting...");

  try {
    // Fetch all user profiles in a single query
    const { data: profiles, error: fetchError } = await sb
      .from("user_profiles")
      .select("user_id, plan");

    if (fetchError) {
      console.error("[Data Cleanup] Failed to fetch profiles:", fetchError.message);
      _lastRunAt = new Date();
      _lastRunOk = false;
      return { usersProcessed: 0, sessionsDeleted: 0, durationMs: Date.now() - start, errors: 1 };
    }

    if (!profiles || profiles.length === 0) {
      console.log("[Data Cleanup] No users to process");
      _lastRunAt = new Date();
      _lastRunOk = true;
      return { usersProcessed: 0, sessionsDeleted: 0, durationMs: Date.now() - start, errors: 0 };
    }

    for (const profile of profiles) {
      try {
        const plan = getPlanSafe(profile.plan);
        const cutoffIso = new Date(
          Date.now() - plan.features.maxHistoryDays * 86_400_000,
        ).toISOString();

        // Delete old session history beyond retention period
        const { count } = await sb
          .from("session_history")
          .delete({ count: "exact" })
          .eq("user_id", profile.user_id)
          .lt("start_time", cutoffIso);

        if (count && count > 0) {
          sessionsDeleted += count;
        }

        // Delete old browsing events
        await sb
          .from("browsing_events")
          .delete()
          .eq("user_id", profile.user_id)
          .lt("start_time", cutoffIso);

        // Delete old browsing sessions (cascades to transitions, drift_points)
        await sb
          .from("browsing_sessions")
          .delete()
          .eq("user_id", profile.user_id)
          .lt("start_time", cutoffIso);

        usersProcessed++;
      } catch (err: unknown) {
        errors++;
        const msg = err instanceof Error ? err.message : "Unknown error";
        console.error(
          `[Data Cleanup] Error processing user ${profile.user_id}: ${msg}`,
        );
        // Continue with next user -- do not let one failure block others
      }
    }
  } catch (err: unknown) {
    errors++;
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("[Data Cleanup] Fatal error:", msg);
  }

  const durationMs = Date.now() - start;
  _lastRunAt = new Date();
  _lastRunOk = errors === 0;

  console.log(
    `[Data Cleanup] Complete in ${durationMs}ms. ` +
      `Users: ${usersProcessed}, Sessions deleted: ${sessionsDeleted}, Errors: ${errors}`,
  );

  return { usersProcessed, sessionsDeleted, durationMs, errors };
}
