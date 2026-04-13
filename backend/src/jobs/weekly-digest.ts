// ---------------------------------------------------------------------------
// Drift -- Automated Weekly Digest Job
// Runs every Monday at 8am via cron.
// Generates AI-powered weekly email for all Pro/Team users.
//
// Idempotency: each user is processed independently and failures do not
// affect other users. Re-running will re-send digests, but since the data
// window is fixed to the previous 7 days the content is identical.
// ---------------------------------------------------------------------------

import { getSupabaseAdmin } from "../config/supabase.js";
import {
  generateWeeklyDigest,
  WeeklyDigestData,
} from "../services/ai-coach.js";
import { sendEmail } from "../services/email.js";

// ---------------------------------------------------------------------------
// Health monitoring
// ---------------------------------------------------------------------------

let _lastRunAt: Date | null = null;
let _lastRunOk = true;

export function getWeeklyDigestHealth(): {
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

export interface WeeklyDigestResult {
  sent: number;
  errors: number;
  skipped: number;
  durationMs: number;
}

export async function runWeeklyDigest(): Promise<WeeklyDigestResult> {
  const start = Date.now();
  const sb = getSupabaseAdmin();
  let sent = 0;
  let errors = 0;
  let skipped = 0;

  console.log("[Weekly Digest] Starting...");

  try {
    // Get all users with Pro or Team plan who have email digest enabled
    const { data: users, error: usersError } = await sb
      .from("user_profiles")
      .select("user_id, email_digest_enabled")
      .in("plan", ["pro", "team"]);

    if (usersError || !users) {
      console.error(
        "[Weekly Digest] Failed to fetch users:",
        usersError?.message,
      );
      _lastRunAt = new Date();
      _lastRunOk = false;
      return { sent: 0, errors: 1, skipped: 0, durationMs: Date.now() - start };
    }

    const digestUsers = users.filter((u) => u.email_digest_enabled !== false);
    console.log(`[Weekly Digest] Processing ${digestUsers.length} users`);

    const now = Date.now();
    const weekAgo = now - 7 * 86_400_000;
    const twoWeeksAgo = now - 14 * 86_400_000;

    for (const user of digestUsers) {
      const userStart = Date.now();

      try {
        // Get user email
        const { data: authUser } = await sb.auth.admin.getUserById(
          user.user_id,
        );
        if (!authUser?.user?.email) {
          skipped++;
          continue;
        }

        // Get this week's sessions
        const { data: thisWeekSessions } = await sb
          .from("session_history")
          .select("*")
          .eq("user_id", user.user_id)
          .gte("start_time", weekAgo)
          .order("start_time", { ascending: true });

        if (!thisWeekSessions || thisWeekSessions.length === 0) {
          skipped++;
          continue;
        }

        // Get last week's sessions for comparison
        const { data: lastWeekSessions } = await sb
          .from("session_history")
          .select("drift_score")
          .eq("user_id", user.user_id)
          .gte("start_time", twoWeeksAgo)
          .lt("start_time", weekAgo);

        const previousWeekAvgDrift =
          lastWeekSessions && lastWeekSessions.length > 0
            ? Math.round(
                lastWeekSessions.reduce((s, e) => s + e.drift_score, 0) /
                  lastWeekSessions.length,
              )
            : null;

        // Aggregate weekly data
        const totalTimeMs = thisWeekSessions.reduce(
          (s, e) => s + e.total_active_time_ms,
          0,
        );
        const productiveTimeMs = thisWeekSessions.reduce(
          (s, e) => s + e.productive_time_ms,
          0,
        );
        const distractionTimeMs = thisWeekSessions.reduce(
          (s, e) => s + e.distraction_time_ms,
          0,
        );
        const averageDriftScore = Math.round(
          thisWeekSessions.reduce((s, e) => s + e.drift_score, 0) /
            thisWeekSessions.length,
        );

        // Aggregate top domains
        const domainTime = new Map<string, number>();
        for (const session of thisWeekSessions) {
          for (const d of session.top_domains ?? []) {
            domainTime.set(
              d.domain,
              (domainTime.get(d.domain) ?? 0) + d.timeMs,
            );
          }
        }
        const topDomains = [...domainTime.entries()]
          .sort((a, b) => b[1] - a[1])
          .slice(0, 10)
          .map(([domain, timeMs]) => ({ domain, timeMs }));

        // Best/worst days
        const dayScores = new Map<
          string,
          { drift: number; count: number }
        >();
        for (const s of thisWeekSessions) {
          const day = new Date(s.start_time).toLocaleDateString("en-US", {
            weekday: "long",
            month: "short",
            day: "numeric",
          });
          const prev = dayScores.get(day) ?? { drift: 0, count: 0 };
          dayScores.set(day, {
            drift: prev.drift + s.drift_score,
            count: prev.count + 1,
          });
        }

        let bestDay: { date: string; driftScore: number } | null = null;
        let worstDay: { date: string; driftScore: number } | null = null;

        for (const [date, data] of dayScores) {
          const avg = Math.round(data.drift / data.count);
          if (!bestDay || avg < bestDay.driftScore)
            bestDay = { date, driftScore: avg };
          if (!worstDay || avg > worstDay.driftScore)
            worstDay = { date, driftScore: avg };
        }

        const digestData: WeeklyDigestData = {
          weekStart: new Date(weekAgo).toLocaleDateString("en-US", {
            month: "short",
            day: "numeric",
          }),
          weekEnd: new Date(now).toLocaleDateString("en-US", {
            month: "short",
            day: "numeric",
          }),
          sessionCount: thisWeekSessions.length,
          totalTimeMs,
          productiveTimeMs,
          distractionTimeMs,
          averageDriftScore,
          topDomains,
          bestDay,
          worstDay,
          previousWeekAvgDrift,
        };

        // Generate AI-powered digest
        const { subject, htmlBody, plainBody } =
          await generateWeeklyDigest(user.user_id, digestData);

        // Send email
        await sendEmail({
          to: authUser.user.email,
          subject,
          html: htmlBody,
          text: plainBody,
        });

        sent++;
        const userMs = Date.now() - userStart;
        console.log(
          `[Weekly Digest] Sent to user ${user.user_id} (${userMs}ms)`,
        );
      } catch (err: unknown) {
        errors++;
        const msg = err instanceof Error ? err.message : "Unknown error";
        console.error(
          `[Weekly Digest] Error for user ${user.user_id}: ${msg}`,
        );
        // Continue with next user -- one failure must not block others
      }
    }
  } catch (err: unknown) {
    errors++;
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("[Weekly Digest] Fatal error:", msg);
  }

  const durationMs = Date.now() - start;
  _lastRunAt = new Date();
  _lastRunOk = errors === 0;

  console.log(
    `[Weekly Digest] Complete in ${durationMs}ms. ` +
      `Sent: ${sent}, Skipped: ${skipped}, Errors: ${errors}`,
  );

  return { sent, errors, skipped, durationMs };
}
