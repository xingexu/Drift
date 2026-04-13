// ---------------------------------------------------------------------------
// Chrome extension storage layer (with localStorage fallback for dev/preview)
// ---------------------------------------------------------------------------

import {
  BrowsingEvent,
  BrowsingSession,
  SessionHistoryEntry,
  Category,
} from "../core/types";
import {
  syncSessionToSupabase,
  pullSessionHistory,
  syncLocalHistoryToSupabase,
  addToPendingSync,
  getCurrentUserId,
  isInitialSyncDone,
  markInitialSyncDone,
  mergeHistoryEntries,
} from "./supabase";

const EVENTS_KEY = "drift_events";
const SESSIONS_KEY = "drift_sessions";
const SESSION_HISTORY_KEY = "drift_session_history";
const TRACKING_KEY = "drift_tracking_enabled";

type StorageBackend = "chrome" | "local" | "memory";

let memoryStore: Record<string, unknown> = {};

function getBackend(): StorageBackend {
  if (typeof chrome !== "undefined" && chrome.storage?.local) return "chrome";
  if (typeof localStorage !== "undefined") return "local";
  return "memory";
}

async function read<T>(key: string, fallback: T): Promise<T> {
  const backend = getBackend();
  if (backend === "chrome") {
    return new Promise((resolve) => {
      chrome.storage.local.get(key, (result) => {
        // Check for runtime errors (e.g., storage quota exceeded)
        if (chrome.runtime.lastError) {
          console.warn("[Drift] storage read error:", chrome.runtime.lastError.message);
          resolve(fallback);
          return;
        }
        resolve((result[key] as T) ?? fallback);
      });
    });
  }
  if (backend === "local") {
    try {
      const raw = localStorage.getItem(key);
      return raw ? (JSON.parse(raw) as T) : fallback;
    } catch {
      return fallback;
    }
  }
  return (memoryStore[key] as T) ?? fallback;
}

async function write(key: string, value: unknown): Promise<void> {
  const backend = getBackend();
  if (backend === "chrome") {
    return new Promise((resolve, reject) => {
      chrome.storage.local.set({ [key]: value }, () => {
        if (chrome.runtime.lastError) {
          console.warn("[Drift] storage write error:", chrome.runtime.lastError.message);
          // Resolve anyway to avoid unhandled rejections crashing the extension
          resolve();
          return;
        }
        resolve();
      });
    });
  }
  if (backend === "local") {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch (e) {
      console.warn("[Drift] localStorage write error:", e);
    }
    return;
  }
  memoryStore[key] = value;
}

// ---------------------------------------------------------------------------
// Events (local-only during active sessions)
// ---------------------------------------------------------------------------

export async function loadEvents(): Promise<BrowsingEvent[]> {
  return read<BrowsingEvent[]>(EVENTS_KEY, []);
}

export async function saveEvents(events: BrowsingEvent[]): Promise<void> {
  return write(EVENTS_KEY, events);
}

// Simple mutex to prevent race conditions in read-modify-write operations
let appendLock: Promise<void> = Promise.resolve();

export async function appendEvent(event: BrowsingEvent): Promise<void> {
  const release = appendLock;
  let resolve: () => void;
  appendLock = new Promise<void>((r) => { resolve = r; });
  try {
    await release;
    const events = await loadEvents();
    events.push(event);
    await saveEvents(events);
  } finally {
    resolve!();
  }
}

// ---------------------------------------------------------------------------
// Sessions
// ---------------------------------------------------------------------------

export async function loadSessions(): Promise<BrowsingSession[]> {
  return read<BrowsingSession[]>(SESSIONS_KEY, []);
}

export async function saveSessions(sessions: BrowsingSession[]): Promise<void> {
  return write(SESSIONS_KEY, sessions);
}

// ---------------------------------------------------------------------------
// Session History (persisted across session resets)
// ---------------------------------------------------------------------------

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

export async function loadSessionHistory(): Promise<SessionHistoryEntry[]> {
  return read<SessionHistoryEntry[]>(SESSION_HISTORY_KEY, []);
}

export async function saveSessionHistory(entries: SessionHistoryEntry[]): Promise<void> {
  return write(SESSION_HISTORY_KEY, entries);
}

/**
 * Append a session history entry locally, then sync to Supabase if authenticated.
 * Pass the full BrowsingSession to enable cloud sync of events/transitions/drift points.
 */
export async function appendSessionToHistory(
  entry: SessionHistoryEntry,
  session?: BrowsingSession
): Promise<void> {
  // Local save first (always)
  const history = await loadSessionHistory();
  history.push(entry);
  const cutoff = Date.now() - THIRTY_DAYS_MS;
  const pruned = history.filter((e) => e.endTime >= cutoff);
  await saveSessionHistory(pruned);

  // Sync to Supabase if authenticated and session provided
  if (session) {
    try {
      await syncSessionToSupabase(session, entry);
    } catch (err) {
      console.warn("[Drift] Sync failed, queued for retry", err);
      await addToPendingSync(entry.sessionId);
    }
  }
}

export async function purgeOldSessions(): Promise<void> {
  const history = await loadSessionHistory();
  const cutoff = Date.now() - THIRTY_DAYS_MS;
  const pruned = history.filter((e) => e.endTime >= cutoff);
  if (pruned.length !== history.length) {
    await saveSessionHistory(pruned);
  }
}

// ---------------------------------------------------------------------------
// Merged history (local + remote)
// ---------------------------------------------------------------------------

/**
 * Load session history from local storage and Supabase, merging results.
 * Falls back to local-only if not authenticated or network fails.
 */
export async function loadSessionHistoryMerged(): Promise<SessionHistoryEntry[]> {
  const local = await loadSessionHistory();
  const userId = await getCurrentUserId();
  if (!userId) return local;

  try {
    const remote = await pullSessionHistory();
    const merged = mergeHistoryEntries(local, remote);
    // Persist merged result locally for offline access
    await saveSessionHistory(merged);
    return merged;
  } catch {
    return local;
  }
}

// ---------------------------------------------------------------------------
// First-login migration
// ---------------------------------------------------------------------------

export async function runInitialSync(): Promise<void> {
  const done = await isInitialSyncDone();
  if (done) return;

  const userId = await getCurrentUserId();
  if (!userId) return;

  try {
    const localHistory = await loadSessionHistory();
    if (localHistory.length > 0) {
      await syncLocalHistoryToSupabase(localHistory);
    }
    await markInitialSyncDone();
  } catch (err) {
    console.warn("[Drift] Initial sync failed", err);
  }
}

// ---------------------------------------------------------------------------
// Tracking State (shared between popup, dashboard, and tracker)
// ---------------------------------------------------------------------------

export async function loadTrackingState(): Promise<boolean> {
  if (typeof chrome !== "undefined" && chrome.storage?.local) {
    return new Promise((resolve) => {
      chrome.storage.local.get(TRACKING_KEY, (r) => {
        if (chrome.runtime.lastError) {
          console.warn("[Drift] loadTrackingState error:", chrome.runtime.lastError.message);
          resolve(true); // Default to enabled
          return;
        }
        resolve(r[TRACKING_KEY] !== false);
      });
    });
  }
  try {
    const raw = localStorage.getItem(TRACKING_KEY);
    return raw !== "false";
  } catch {
    return true; // Default to enabled
  }
}

export async function setTrackingState(enabled: boolean): Promise<void> {
  if (typeof chrome !== "undefined" && chrome.storage?.local) {
    return new Promise((resolve) => {
      chrome.storage.local.set({ [TRACKING_KEY]: enabled }, () => {
        if (chrome.runtime.lastError) {
          console.warn("[Drift] setTrackingState error:", chrome.runtime.lastError.message);
        }
        resolve();
      });
    });
  }
  try {
    localStorage.setItem(TRACKING_KEY, String(enabled));
  } catch {
    // Silently fail if localStorage is not available
  }
}

// ---------------------------------------------------------------------------
// Clear (current session only — preserves history)
// ---------------------------------------------------------------------------

export async function clearCurrentSession(): Promise<void> {
  await write(EVENTS_KEY, []);
  await write(SESSIONS_KEY, []);
}

// ---------------------------------------------------------------------------
// Clear All (full wipe including history)
// ---------------------------------------------------------------------------

export async function clearAll(): Promise<void> {
  const backend = getBackend();
  if (backend === "chrome") {
    return new Promise((resolve) => {
      chrome.storage.local.clear(() => {
        if (chrome.runtime.lastError) {
          console.warn("[Drift] storage clear error:", chrome.runtime.lastError.message);
        }
        resolve();
      });
    });
  }
  if (backend === "local") {
    localStorage.removeItem(EVENTS_KEY);
    localStorage.removeItem(SESSIONS_KEY);
    localStorage.removeItem(SESSION_HISTORY_KEY);
    localStorage.removeItem(TRACKING_KEY);
    return;
  }
  memoryStore = {};
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

const SETTINGS_KEY = "drift_settings";

export interface DriftSettings {
  domainOverrides: Record<string, Category>;
  notifications: boolean;
  sensitivity: "low" | "medium" | "high";
  dailyGoalMaxDrift: number;
}

const DEFAULT_SETTINGS: DriftSettings = {
  domainOverrides: {},
  notifications: true,
  sensitivity: "medium",
  dailyGoalMaxDrift: 30,
};

export async function loadSettings(): Promise<DriftSettings> {
  const saved = await read<Partial<DriftSettings>>(SETTINGS_KEY, {});
  return { ...DEFAULT_SETTINGS, ...saved };
}

export async function saveSettings(settings: DriftSettings): Promise<void> {
  return write(SETTINGS_KEY, settings);
}

// ---------------------------------------------------------------------------
// Goals & Streaks
// ---------------------------------------------------------------------------

const GOALS_KEY = "drift_goals";

export interface GoalData {
  streak: number;
  lastDate: string;
  history: { date: string; met: boolean; driftScore: number }[];
}

export async function loadGoals(): Promise<GoalData> {
  return read<GoalData>(GOALS_KEY, { streak: 0, lastDate: "", history: [] });
}

export async function saveGoals(data: GoalData): Promise<void> {
  return write(GOALS_KEY, data);
}
