// ---------------------------------------------------------------------------
// Drift Backend -- Supabase Admin Client (service role)
// ---------------------------------------------------------------------------

import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { getEnv } from "./env.js";

let adminClient: SupabaseClient | null = null;

/**
 * Get Supabase admin client with service_role key.
 * Bypasses RLS -- use only in backend services.
 */
export function getSupabaseAdmin(): SupabaseClient {
  if (!adminClient) {
    const env = getEnv();
    adminClient = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
  }
  return adminClient;
}

/**
 * Create a Supabase client scoped to a specific user (for RLS enforcement).
 * Uses the anon key so RLS policies are properly enforced against the user's JWT.
 */
export function getSupabaseForUser(accessToken: string): SupabaseClient {
  const env = getEnv();
  return createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

// ---------------------------------------------------------------------------
// Health check -- used by the /api/health endpoint to report dependency
// status without leaking credentials or internal details.
// ---------------------------------------------------------------------------

export interface SupabaseHealthResult {
  status: "ok" | "degraded" | "down";
  latencyMs: number;
  error?: string;
}

/**
 * Ping Supabase with a lightweight query and return connectivity status.
 * Never throws -- always returns a result object.
 */
export async function checkSupabaseHealth(): Promise<SupabaseHealthResult> {
  const start = Date.now();
  try {
    const sb = getSupabaseAdmin();
    // A zero-row select is the cheapest possible round-trip.
    const { error } = await sb
      .from("user_profiles")
      .select("user_id")
      .limit(1);

    const latencyMs = Date.now() - start;

    if (error) {
      return { status: "degraded", latencyMs, error: error.message };
    }
    return { status: "ok", latencyMs };
  } catch (err: unknown) {
    const latencyMs = Date.now() - start;
    const message = err instanceof Error ? err.message : "Unknown error";
    return { status: "down", latencyMs, error: message };
  }
}
