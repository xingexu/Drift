// ---------------------------------------------------------------------------
// Chrome extension storage layer (with localStorage fallback for dev/preview)
// ---------------------------------------------------------------------------

import { BrowsingEvent, BrowsingSession } from "../core/types";

const EVENTS_KEY = "drift_events";
const SESSIONS_KEY = "drift_sessions";

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
    return new Promise((resolve) => {
      chrome.storage.local.set({ [key]: value }, resolve);
    });
  }
  if (backend === "local") {
    localStorage.setItem(key, JSON.stringify(value));
    return;
  }
  memoryStore[key] = value;
}

async function clearStore(): Promise<void> {
  const backend = getBackend();
  if (backend === "chrome") {
    return new Promise((resolve) => {
      chrome.storage.local.clear(resolve);
    });
  }
  if (backend === "local") {
    localStorage.removeItem(EVENTS_KEY);
    localStorage.removeItem(SESSIONS_KEY);
    return;
  }
  memoryStore = {};
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

export async function loadEvents(): Promise<BrowsingEvent[]> {
  return read<BrowsingEvent[]>(EVENTS_KEY, []);
}

export async function saveEvents(events: BrowsingEvent[]): Promise<void> {
  return write(EVENTS_KEY, events);
}

export async function appendEvent(event: BrowsingEvent): Promise<void> {
  const events = await loadEvents();
  events.push(event);
  await saveEvents(events);
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
// Clear
// ---------------------------------------------------------------------------

export async function clearAll(): Promise<void> {
  return clearStore();
}
