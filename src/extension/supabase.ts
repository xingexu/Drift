// ---------------------------------------------------------------------------
// Drift – Supabase Client & Sync
// ---------------------------------------------------------------------------

import { createClient, SupabaseClient, Session, AuthChangeEvent } from "@supabase/supabase-js";
import {
  BrowsingSession,
  BrowsingEvent,
  Transition,
  DriftPoint,
  SessionHistoryEntry,
} from "../core/types";

// ---------------------------------------------------------------------------
// Config — replace with your Supabase project values
// ---------------------------------------------------------------------------

const SUPABASE_URL = "https://lbdiixdgsbhryulutpef.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_CxaOKaXH1tZ-WnATV8cPyQ_WpzbhdLA";

// ---------------------------------------------------------------------------
// Chrome storage adapter for Supabase auth persistence
// ---------------------------------------------------------------------------

const chromeStorageAdapter = {
  async getItem(key: string): Promise<string | null> {
    if (typeof chrome !== "undefined" && chrome.storage?.local) {
      return new Promise((resolve) => {
        chrome.storage.local.get(key, (result) => {
          resolve((result[key] as string) ?? null);
        });
      });
    }
    return localStorage.getItem(key);
  },
  async setItem(key: string, value: string): Promise<void> {
    if (typeof chrome !== "undefined" && chrome.storage?.local) {
      return new Promise((resolve) => {
        chrome.storage.local.set({ [key]: value }, resolve);
      });
    }
    localStorage.setItem(key, value);
  },
  async removeItem(key: string): Promise<void> {
    if (typeof chrome !== "undefined" && chrome.storage?.local) {
      return new Promise((resolve) => {
        chrome.storage.local.remove(key, resolve);
      });
    }
    localStorage.removeItem(key);
  },
};

// ---------------------------------------------------------------------------
// Singleton client
// ---------------------------------------------------------------------------

let client: SupabaseClient | null = null;

export function getSupabase(): SupabaseClient {
  if (!client) {
    // Detect if we're in a Chrome extension context (popup/background) vs regular browser tab
    const isExtensionContext =
      typeof chrome !== "undefined" &&
      !!chrome.runtime?.id &&
      !!chrome.storage?.local;

    client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        storage: chromeStorageAdapter,
        autoRefreshToken: true,
        persistSession: true,
        // Enable detectSessionInUrl in browser context so OAuth redirect callbacks work
        // Disable in extension context (popup/background) where URL hash tokens don't apply
        detectSessionInUrl: !isExtensionContext,
      },
    });
  }
  return client;
}

// ---------------------------------------------------------------------------
// Auth helpers
// ---------------------------------------------------------------------------

export async function getSession(): Promise<Session | null> {
  const { data } = await getSupabase().auth.getSession();
  return data.session;
}

export async function getCurrentUserId(): Promise<string | null> {
  const session = await getSession();
  return session?.user?.id ?? null;
}

export async function signInWithMagicLink(email: string): Promise<{ error: Error | null }> {
  const { error } = await getSupabase().auth.signInWithOtp({ email });
  return { error: error ? new Error(error.message) : null };
}

export async function signInWithGoogle(): Promise<{ error: Error | null }> {
  const isExtensionPopup =
    typeof chrome !== "undefined" &&
    !!chrome.runtime?.id &&
    !!chrome.identity?.launchWebAuthFlow;

  if (isExtensionPopup) {
    // -----------------------------------------------------------------------
    // Chrome extension popup context — use chrome.identity for popup-safe OAuth
    // -----------------------------------------------------------------------
    try {
      const redirectUri = chrome.identity.getRedirectURL();

      const { data } = await getSupabase().auth.signInWithOAuth({
        provider: "google",
        options: {
          skipBrowserRedirect: true,
          redirectTo: redirectUri,
        },
      });

      if (!data.url) {
        return { error: new Error("Failed to get OAuth URL. Check Google provider config in Supabase.") };
      }

      const responseUrl = await new Promise<string>((resolve, reject) => {
        chrome.identity.launchWebAuthFlow(
          { url: data.url, interactive: true },
          (callbackUrl) => {
            if (chrome.runtime.lastError || !callbackUrl) {
              reject(
                new Error(
                  chrome.runtime.lastError?.message ?? "Sign-in was cancelled."
                )
              );
            } else {
              resolve(callbackUrl);
            }
          }
        );
      });

      // Extract tokens from the callback URL hash
      const url = new URL(responseUrl);
      const hashParams = new URLSearchParams(url.hash.substring(1));
      const accessToken = hashParams.get("access_token");
      const refreshToken = hashParams.get("refresh_token");

      if (accessToken && refreshToken) {
        const { error } = await getSupabase().auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken,
        });
        return { error: error ? new Error(error.message) : null };
      }

      // Check for error in hash (e.g., provider not configured)
      const errorDesc = hashParams.get("error_description");
      if (errorDesc) {
        return { error: new Error(errorDesc) };
      }

      return { error: new Error("No tokens received. Ensure Google OAuth is configured in Supabase.") };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.includes("cancelled") || msg.includes("closed")) {
        return { error: new Error("Sign-in was cancelled.") };
      }
      return { error: new Error(msg) };
    }
  }

  // -----------------------------------------------------------------------
  // Browser context (dashboard opened in regular tab) — use OAuth redirect
  // Supabase redirects to Google, then back to our page with tokens in the URL
  // detectSessionInUrl: true will pick them up automatically on page load
  // -----------------------------------------------------------------------
  try {
    // Determine the best redirect target
    const currentUrl = window.location.href.split("#")[0].split("?")[0];

    const { data, error } = await getSupabase().auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: currentUrl,
      },
    });

    if (error) {
      // If Supabase returns an error, Google provider isn't configured
      return {
        error: new Error(
          error.message.includes("provider")
            ? "Google sign-in is not configured yet. Set up Google OAuth in your Supabase dashboard."
            : error.message
        ),
      };
    }

    // signInWithOAuth triggers a full page redirect to Google — won't reach here
    return { error: null };
  } catch (err) {
    return {
      error: new Error(
        "Google sign-in failed. Make sure Google OAuth is enabled in your Supabase project."
      ),
    };
  }
}

export async function signOut(): Promise<void> {
  await getSupabase().auth.signOut();
}

export function onAuthStateChange(
  callback: (event: AuthChangeEvent, session: Session | null) => void
): { unsubscribe: () => void } {
  const { data } = getSupabase().auth.onAuthStateChange(callback);
  return { unsubscribe: data.subscription.unsubscribe };
}

// ---------------------------------------------------------------------------
// Sync: push session data to Supabase
// ---------------------------------------------------------------------------

export async function syncSessionToSupabase(
  session: BrowsingSession,
  historyEntry: SessionHistoryEntry
): Promise<void> {
  const userId = await getCurrentUserId();
  if (!userId) return;

  const sb = getSupabase();

  // 1. Upsert session
  const { error: sessionErr } = await sb.from("browsing_sessions").upsert({
    id: session.id,
    user_id: userId,
    start_time: session.startTime,
    end_time: session.endTime,
    total_duration_ms: session.totalDurationMs,
    entry_event_id: session.entryEventId,
    exit_event_id: session.exitEventId,
    drift_score: session.driftScore,
    summary_label: session.summaryLabel,
    stats: session.stats,
    intent: session.intent ?? null,
  });
  if (sessionErr) throw sessionErr;

  // 2. Upsert events (batch, chunked to avoid request size limits)
  if (session.events.length > 0) {
    const eventRows = session.events.map((e: BrowsingEvent) => ({
      id: e.id,
      user_id: userId,
      session_id: session.id,
      tab_id: e.tabId,
      window_id: e.windowId,
      raw_url: e.rawUrl,
      normalized_url: e.normalizedUrl,
      domain: e.domain,
      path: e.path ?? null,
      title: e.title ?? null,
      start_time: e.startTime,
      end_time: e.endTime,
      duration_ms: e.durationMs,
      previous_event_id: e.previousEventId ?? null,
      transition_type: e.transitionType ?? null,
      category: e.category ?? null,
      classification_source: e.classification?.source ?? null,
      classification_reason: e.classification?.reason ?? null,
      drift: e.drift ?? false,
      drift_reasons: e.driftReasons ?? [],
    }));
    // Chunk to avoid exceeding Supabase request size limits
    const CHUNK_SIZE = 500;
    for (let i = 0; i < eventRows.length; i += CHUNK_SIZE) {
      const chunk = eventRows.slice(i, i + CHUNK_SIZE);
      const { error: eventsErr } = await sb.from("browsing_events").upsert(chunk);
      if (eventsErr) throw eventsErr;
    }
  }

  // 3. Upsert transitions
  if (session.transitions.length > 0) {
    const transRows = session.transitions.map((t: Transition) => ({
      id: t.id,
      user_id: userId,
      session_id: t.sessionId,
      source_event_id: t.sourceEventId,
      target_event_id: t.targetEventId,
      source_domain: t.sourceDomain,
      target_domain: t.targetDomain,
      source_normalized_url: t.sourceNormalizedUrl,
      target_normalized_url: t.targetNormalizedUrl,
      time_gap_ms: t.timeGapMs,
      is_category_shift: t.isCategoryShift,
      from_category: t.fromCategory ?? null,
      to_category: t.toCategory ?? null,
    }));
    const { error: transErr } = await sb.from("transitions").upsert(transRows);
    if (transErr) throw transErr;
  }

  // 4. Upsert drift points
  if (session.driftPoints.length > 0) {
    const dpRows = session.driftPoints.map((dp: DriftPoint) => ({
      id: dp.id,
      user_id: userId,
      session_id: dp.sessionId,
      event_id: dp.eventId ?? null,
      transition_id: dp.transitionId ?? null,
      timestamp: dp.timestamp,
      reason: dp.reason,
      trigger: dp.trigger,
    }));
    const { error: dpErr } = await sb.from("drift_points").upsert(dpRows);
    if (dpErr) throw dpErr;
  }

  // 5. Upsert history entry
  const { error: histErr } = await sb.from("session_history").upsert({
    session_id: historyEntry.sessionId,
    user_id: userId,
    start_time: historyEntry.startTime,
    end_time: historyEntry.endTime,
    total_active_time_ms: historyEntry.totalActiveTimeMs,
    productive_time_ms: historyEntry.productiveTimeMs,
    neutral_time_ms: historyEntry.neutralTimeMs,
    distraction_time_ms: historyEntry.distractionTimeMs,
    drift_score: historyEntry.driftScore,
    drift_point_count: historyEntry.driftPointCount,
    summary_label: historyEntry.summaryLabel,
    entry_domain: historyEntry.entryDomain,
    exit_domain: historyEntry.exitDomain,
    top_domains: historyEntry.topDomains,
    event_count: historyEntry.eventCount,
  });
  if (histErr) throw histErr;
}

// ---------------------------------------------------------------------------
// Sync: pull session history from Supabase
// ---------------------------------------------------------------------------

export async function pullSessionHistory(): Promise<SessionHistoryEntry[]> {
  const userId = await getCurrentUserId();
  if (!userId) return [];

  // Only pull last 90 days to avoid huge responses
  const cutoff = Date.now() - 90 * 24 * 60 * 60 * 1000;

  const { data, error } = await getSupabase()
    .from("session_history")
    .select("*")
    .eq("user_id", userId)
    .gte("end_time", cutoff)
    .order("start_time", { ascending: false })
    .limit(1000);

  if (error) throw error;
  if (!data) return [];

  return data.map((row) => ({
    sessionId: row.session_id ?? "",
    startTime: row.start_time ?? 0,
    endTime: row.end_time ?? 0,
    totalActiveTimeMs: row.total_active_time_ms ?? 0,
    productiveTimeMs: row.productive_time_ms ?? 0,
    neutralTimeMs: row.neutral_time_ms ?? 0,
    distractionTimeMs: row.distraction_time_ms ?? 0,
    driftScore: row.drift_score ?? 0,
    driftPointCount: row.drift_point_count ?? 0,
    summaryLabel: row.summary_label ?? "",
    entryDomain: row.entry_domain ?? "",
    exitDomain: row.exit_domain ?? "",
    topDomains: row.top_domains ?? [],
    eventCount: row.event_count ?? 0,
  }));
}

// ---------------------------------------------------------------------------
// Sync: push all local history entries (first-login migration)
// ---------------------------------------------------------------------------

export async function syncLocalHistoryToSupabase(
  entries: SessionHistoryEntry[]
): Promise<void> {
  const userId = await getCurrentUserId();
  if (!userId || entries.length === 0) return;

  const rows = entries.map((e) => ({
    session_id: e.sessionId,
    user_id: userId,
    start_time: e.startTime,
    end_time: e.endTime,
    total_active_time_ms: e.totalActiveTimeMs,
    productive_time_ms: e.productiveTimeMs,
    neutral_time_ms: e.neutralTimeMs,
    distraction_time_ms: e.distractionTimeMs,
    drift_score: e.driftScore,
    drift_point_count: e.driftPointCount,
    summary_label: e.summaryLabel,
    entry_domain: e.entryDomain,
    exit_domain: e.exitDomain,
    top_domains: e.topDomains,
    event_count: e.eventCount,
  }));

  // Chunk to avoid exceeding Supabase request size limits
  const CHUNK_SIZE = 500;
  for (let i = 0; i < rows.length; i += CHUNK_SIZE) {
    const chunk = rows.slice(i, i + CHUNK_SIZE);
    const { error } = await getSupabase().from("session_history").upsert(chunk);
    if (error) throw error;
  }
}

// ---------------------------------------------------------------------------
// Pending sync queue (for offline resilience)
// ---------------------------------------------------------------------------

const PENDING_SYNC_KEY = "drift_pending_sync";
const INITIAL_SYNC_KEY = "drift_initial_sync_done";

async function readKey<T>(key: string, fallback: T): Promise<T> {
  if (typeof chrome !== "undefined" && chrome.storage?.local) {
    return new Promise((resolve) => {
      chrome.storage.local.get(key, (r) => {
        if (chrome.runtime.lastError) {
          console.warn("[Drift] readKey error:", chrome.runtime.lastError.message);
          resolve(fallback);
          return;
        }
        resolve((r[key] as T) ?? fallback);
      });
    });
  }
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

async function writeKey(key: string, value: unknown): Promise<void> {
  if (typeof chrome !== "undefined" && chrome.storage?.local) {
    return new Promise((resolve) => {
      chrome.storage.local.set({ [key]: value }, () => {
        if (chrome.runtime.lastError) {
          console.warn("[Drift] writeKey error:", chrome.runtime.lastError.message);
        }
        resolve();
      });
    });
  }
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch (e) {
    console.warn("[Drift] localStorage writeKey error:", e);
  }
}

// Serialize pending sync operations to prevent race conditions
let pendingSyncLock: Promise<void> = Promise.resolve();

export async function addToPendingSync(sessionId: string): Promise<void> {
  const release = pendingSyncLock;
  let resolve: () => void;
  pendingSyncLock = new Promise<void>((r) => { resolve = r; });
  try {
    await release;
    const pending = await readKey<string[]>(PENDING_SYNC_KEY, []);
    if (!pending.includes(sessionId)) {
      pending.push(sessionId);
      await writeKey(PENDING_SYNC_KEY, pending);
    }
  } finally {
    resolve!();
  }
}

export async function getPendingSync(): Promise<string[]> {
  return readKey<string[]>(PENDING_SYNC_KEY, []);
}

export async function clearPendingSync(sessionId: string): Promise<void> {
  const pending = await readKey<string[]>(PENDING_SYNC_KEY, []);
  await writeKey(PENDING_SYNC_KEY, pending.filter((id) => id !== sessionId));
}

export async function isInitialSyncDone(): Promise<boolean> {
  return readKey<boolean>(INITIAL_SYNC_KEY, false);
}

export async function markInitialSyncDone(): Promise<void> {
  await writeKey(INITIAL_SYNC_KEY, true);
}

// ---------------------------------------------------------------------------
// Merge local + remote history (dedup by sessionId)
// ---------------------------------------------------------------------------

export function mergeHistoryEntries(
  local: SessionHistoryEntry[],
  remote: SessionHistoryEntry[]
): SessionHistoryEntry[] {
  const map = new Map<string, SessionHistoryEntry>();
  for (const entry of local) {
    map.set(entry.sessionId, entry);
  }
  for (const entry of remote) {
    const existing = map.get(entry.sessionId);
    // Remote wins if newer or not present locally
    if (!existing || entry.endTime >= existing.endTime) {
      map.set(entry.sessionId, entry);
    }
  }
  return [...map.values()].sort((a, b) => a.startTime - b.startTime);
}
