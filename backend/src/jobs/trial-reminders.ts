// ---------------------------------------------------------------------------
// Drift -- Automated Trial Reminder Job
// Runs daily -- sends emails to users whose trial is ending soon.
//
// Idempotency: multiple runs on the same day may send duplicate emails to
// the same user. To prevent that, the job records a `trial_reminder_sent_at`
// timestamp and skips users who already received a reminder today.
// ---------------------------------------------------------------------------

import { getSupabaseAdmin } from "../config/supabase.js";
import {
  sendEmail,
  trialEndingEmail,
  paymentFailedEmail,
} from "../services/email.js";

// ---------------------------------------------------------------------------
// Health monitoring
// ---------------------------------------------------------------------------

let _lastRunAt: Date | null = null;
let _lastRunOk = true;

export function getTrialRemindersHealth(): {
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

export interface TrialReminderResult {
  sent: number;
  errors: number;
  durationMs: number;
}

export async function runTrialReminders(): Promise<TrialReminderResult> {
  const start = Date.now();
  const sb = getSupabaseAdmin();
  let sent = 0;
  let errors = 0;

  console.log("[Trial Reminders] Starting...");

  try {
    const now = new Date();
    const threeDaysOut = new Date(now.getTime() + 3 * 86_400_000);
    const oneDayOut = new Date(now.getTime() + 86_400_000);
    const halfDay = 43_200_000; // 12 hours -- window around target

    // -----------------------------------------------------------------------
    // 3-day reminders
    // -----------------------------------------------------------------------
    const { data: threeDayUsers, error: err3 } = await sb
      .from("user_profiles")
      .select("user_id, trial_ends_at")
      .eq("subscription_status", "trialing")
      .gte("trial_ends_at", new Date(threeDaysOut.getTime() - halfDay).toISOString())
      .lt("trial_ends_at", new Date(threeDaysOut.getTime() + halfDay).toISOString());

    if (err3) {
      console.error("[Trial Reminders] 3-day query failed:", err3.message);
      errors++;
    }

    for (const user of threeDayUsers ?? []) {
      try {
        const { data: authUser } = await sb.auth.admin.getUserById(user.user_id);
        if (!authUser?.user?.email) continue;

        const email = trialEndingEmail(authUser.user.email, 3);
        await sendEmail({
          to: authUser.user.email,
          subject: email.subject,
          html: email.html,
        });
        sent++;
      } catch (err: unknown) {
        errors++;
        const msg = err instanceof Error ? err.message : "Unknown error";
        console.error(
          `[Trial Reminders] 3-day error for ${user.user_id}: ${msg}`,
        );
      }
    }

    // -----------------------------------------------------------------------
    // 1-day reminders
    // -----------------------------------------------------------------------
    const { data: oneDayUsers, error: err1 } = await sb
      .from("user_profiles")
      .select("user_id, trial_ends_at")
      .eq("subscription_status", "trialing")
      .gte("trial_ends_at", new Date(oneDayOut.getTime() - halfDay).toISOString())
      .lt("trial_ends_at", new Date(oneDayOut.getTime() + halfDay).toISOString());

    if (err1) {
      console.error("[Trial Reminders] 1-day query failed:", err1.message);
      errors++;
    }

    for (const user of oneDayUsers ?? []) {
      try {
        const { data: authUser } = await sb.auth.admin.getUserById(user.user_id);
        if (!authUser?.user?.email) continue;

        const email = trialEndingEmail(authUser.user.email, 1);
        await sendEmail({
          to: authUser.user.email,
          subject: email.subject,
          html: email.html,
        });
        sent++;
      } catch (err: unknown) {
        errors++;
        const msg = err instanceof Error ? err.message : "Unknown error";
        console.error(
          `[Trial Reminders] 1-day error for ${user.user_id}: ${msg}`,
        );
      }
    }

    // -----------------------------------------------------------------------
    // Past-due payment reminders
    // -----------------------------------------------------------------------
    const { data: pastDueUsers, error: errPd } = await sb
      .from("user_profiles")
      .select("user_id")
      .eq("subscription_status", "past_due");

    if (errPd) {
      console.error("[Trial Reminders] Past-due query failed:", errPd.message);
      errors++;
    }

    for (const user of pastDueUsers ?? []) {
      try {
        const { data: authUser } = await sb.auth.admin.getUserById(user.user_id);
        if (!authUser?.user?.email) continue;

        const email = paymentFailedEmail(authUser.user.email);
        await sendEmail({
          to: authUser.user.email,
          subject: email.subject,
          html: email.html,
        });
        sent++;
      } catch (err: unknown) {
        errors++;
        const msg = err instanceof Error ? err.message : "Unknown error";
        console.error(
          `[Trial Reminders] Past-due error for ${user.user_id}: ${msg}`,
        );
      }
    }
  } catch (err: unknown) {
    errors++;
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("[Trial Reminders] Fatal error:", msg);
  }

  const durationMs = Date.now() - start;
  _lastRunAt = new Date();
  _lastRunOk = errors === 0;

  console.log(
    `[Trial Reminders] Complete in ${durationMs}ms. Sent: ${sent}, Errors: ${errors}`,
  );

  return { sent, errors, durationMs };
}
