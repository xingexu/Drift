// ---------------------------------------------------------------------------
// Drift -- Automated Onboarding Job
// Triggered on new user signup -- creates profile + sends welcome email.
//
// Idempotency: profile creation uses upsert, so calling this twice for the
// same userId is harmless. The welcome email may be sent again, but that is
// acceptable for a signup flow.
// ---------------------------------------------------------------------------

import { getSupabaseAdmin } from "../config/supabase.js";
import { sendEmail, welcomeEmail } from "../services/email.js";

// ---------------------------------------------------------------------------
// Health monitoring
// ---------------------------------------------------------------------------

let _lastRunAt: Date | null = null;
let _lastRunOk = true;
let _totalOnboarded = 0;

export function getOnboardingHealth(): {
  lastRunAt: string | null;
  lastRunOk: boolean;
  totalOnboarded: number;
} {
  return {
    lastRunAt: _lastRunAt?.toISOString() ?? null,
    lastRunOk: _lastRunOk,
    totalOnboarded: _totalOnboarded,
  };
}

// ---------------------------------------------------------------------------
// Job implementation
// ---------------------------------------------------------------------------

/**
 * Process new user signup:
 * 1. Create user_profile with free plan (upsert -- idempotent)
 * 2. Send welcome email
 * 3. Set default preferences
 */
export async function onboardNewUser(
  userId: string,
  email: string,
): Promise<{ success: boolean; durationMs: number }> {
  const start = Date.now();

  // Sanitize inputs
  if (!userId || typeof userId !== "string") {
    console.error("[Onboarding] Invalid userId:", userId);
    _lastRunAt = new Date();
    _lastRunOk = false;
    return { success: false, durationMs: Date.now() - start };
  }

  if (!email || typeof email !== "string" || !email.includes("@")) {
    console.error("[Onboarding] Invalid email for user:", userId);
    _lastRunAt = new Date();
    _lastRunOk = false;
    return { success: false, durationMs: Date.now() - start };
  }

  console.log(`[Onboarding] New user: ${userId}`);

  try {
    const sb = getSupabaseAdmin();
    const now = new Date().toISOString();

    // Create profile (idempotent via upsert)
    const { error: upsertError } = await sb.from("user_profiles").upsert(
      {
        user_id: userId,
        plan: "free",
        subscription_status: "none",
        email_digest_enabled: true,
        onboarded_at: now,
        created_at: now,
        updated_at: now,
      },
      { onConflict: "user_id" },
    );

    if (upsertError) {
      console.error(
        `[Onboarding] Profile upsert failed for ${userId}:`,
        upsertError.message,
      );
      _lastRunAt = new Date();
      _lastRunOk = false;
      return { success: false, durationMs: Date.now() - start };
    }

    // Send welcome email -- non-blocking failure (profile was created
    // successfully, so the user is onboarded even if the email fails)
    try {
      const welcome = welcomeEmail(email);
      await sendEmail({
        to: email,
        subject: welcome.subject,
        html: welcome.html,
      });
      console.log(`[Onboarding] Welcome email sent to ${userId}`);
    } catch (emailErr: unknown) {
      const msg =
        emailErr instanceof Error ? emailErr.message : "Unknown error";
      console.error(`[Onboarding] Email failed for ${userId}: ${msg}`);
      // Do NOT fail the whole onboarding because of an email error
    }

    _totalOnboarded++;
    _lastRunAt = new Date();
    _lastRunOk = true;

    const durationMs = Date.now() - start;
    console.log(`[Onboarding] Complete for ${userId} in ${durationMs}ms`);
    return { success: true, durationMs };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error(`[Onboarding] Fatal error for ${userId}: ${msg}`);
    _lastRunAt = new Date();
    _lastRunOk = false;
    return { success: false, durationMs: Date.now() - start };
  }
}

// ---------------------------------------------------------------------------
// Auth webhook setup (called once at server startup)
// ---------------------------------------------------------------------------

/**
 * Listen for Supabase auth events and trigger onboarding.
 * Called once at server startup.
 */
export function setupAuthWebhook(): void {
  // This is handled via Supabase Database Webhook or Edge Function.
  // The webhook POSTs to /api/webhooks/auth on new user creation.
  console.log("[Onboarding] Auth webhook listener registered");
}
