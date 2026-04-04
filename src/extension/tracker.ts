// ---------------------------------------------------------------------------
// Drift – Browser event tracker (runs as service worker)
// ---------------------------------------------------------------------------

import {
  BrowsingEvent,
  RawTrackerEvent,
  TransitionType,
} from "../core/types";
import {
  isTrackableUrl,
  getDomain,
  getPath,
  normalizeUrl,
  generateId,
} from "../core/normalize";
import { appendEvent } from "./storage";

const MIN_EVENT_DURATION_MS = 500;
const TRACKING_ENABLED_KEY = "drift_tracking_enabled";

let trackingEnabled = true;
let activeEvent: RawTrackerEvent | null = null;
let previousEventId: string | null = null;
let lastFinalizedUrl: string | null = null;

// ---------------------------------------------------------------------------
// Finalize the currently active event
// ---------------------------------------------------------------------------

function finalizeActiveEvent(
  transitionType: TransitionType = "unknown",
): BrowsingEvent | null {
  if (!activeEvent) return null;

  const now = Date.now();
  const endTime = activeEvent.endTime ?? now;
  const durationMs = endTime - activeEvent.startTime;

  if (durationMs < MIN_EVENT_DURATION_MS) {
    activeEvent = null;
    return null;
  }

  if (!isTrackableUrl(activeEvent.url)) {
    activeEvent = null;
    return null;
  }

  const event: BrowsingEvent = {
    id: generateId(),
    tabId: activeEvent.tabId,
    windowId: activeEvent.windowId,
    rawUrl: activeEvent.url,
    normalizedUrl: normalizeUrl(activeEvent.url),
    domain: getDomain(activeEvent.url),
    path: getPath(activeEvent.url),
    title: activeEvent.title || undefined,
    startTime: activeEvent.startTime,
    endTime,
    durationMs,
    previousEventId: previousEventId ?? undefined,
    transitionType,
  };

  previousEventId = event.id;
  lastFinalizedUrl = event.rawUrl;
  activeEvent = null;

  appendEvent(event).catch(() => {});
  return event;
}

// ---------------------------------------------------------------------------
// Start tracking a new page
// ---------------------------------------------------------------------------

function startTracking(
  tabId: number,
  windowId: number,
  url: string,
  title: string | undefined,
  transitionType: TransitionType,
): void {
  finalizeActiveEvent(transitionType);

  if (!trackingEnabled) return;
  if (!isTrackableUrl(url)) return;

  activeEvent = {
    tabId,
    windowId,
    url,
    title,
    startTime: Date.now(),
    transitionType,
  };
}

// ---------------------------------------------------------------------------
// Determine transition type between previous and new URL
// ---------------------------------------------------------------------------

function inferTransitionType(
  newUrl: string,
  trigger: "tab_switch" | "url_change",
): TransitionType {
  if (trigger === "tab_switch") return "tab_switch";
  if (lastFinalizedUrl && getDomain(lastFinalizedUrl) === getDomain(newUrl)) {
    return "navigation";
  }
  return "unknown";
}

// ---------------------------------------------------------------------------
// Chrome listener setup
// ---------------------------------------------------------------------------

export function installListeners(): void {
  // Load tracking enabled state
  if (typeof chrome !== "undefined" && chrome.storage?.local) {
    chrome.storage.local.get(TRACKING_ENABLED_KEY, (result) => {
      trackingEnabled = result[TRACKING_ENABLED_KEY] !== false;
    });
    chrome.storage.onChanged.addListener((changes) => {
      if (TRACKING_ENABLED_KEY in changes) {
        trackingEnabled = changes[TRACKING_ENABLED_KEY].newValue !== false;
        if (!trackingEnabled) {
          finalizeActiveEvent("unknown");
        }
      }
    });
  }

  // Tab activated (user switches tabs)
  chrome.tabs.onActivated.addListener((activeInfo) => {
    chrome.tabs.get(activeInfo.tabId, (tab) => {
      if (chrome.runtime.lastError || !tab?.url) return;
      const tt = inferTransitionType(tab.url, "tab_switch");
      startTracking(
        activeInfo.tabId,
        activeInfo.windowId ?? tab.windowId,
        tab.url,
        tab.title,
        tt,
      );
    });
  });

  // Tab updated (URL changes in the active tab)
  chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (changeInfo.status !== "complete") return;
    if (!tab.active) return;
    if (!tab.url) return;

    // If URL hasn't actually changed, just update title
    if (activeEvent && activeEvent.url === tab.url) {
      if (tab.title) activeEvent.title = tab.title;
      return;
    }

    const tt = inferTransitionType(tab.url, "url_change");
    startTracking(tabId, tab.windowId, tab.url, tab.title, tt);
  });

  // Tab closed
  chrome.tabs.onRemoved.addListener((_tabId) => {
    if (activeEvent && activeEvent.tabId === _tabId) {
      finalizeActiveEvent("tab_switch");
    }
  });

  // Window focus changed
  chrome.windows.onFocusChanged.addListener((windowId) => {
    if (windowId === chrome.windows.WINDOW_ID_NONE) {
      // Browser lost focus – finalize current event
      if (activeEvent) {
        activeEvent.endTime = Date.now();
        finalizeActiveEvent("unknown");
      }
      return;
    }
    // Browser regained focus – query active tab in focused window
    chrome.tabs.query({ active: true, windowId }, (tabs) => {
      if (chrome.runtime.lastError || !tabs?.[0]?.url) return;
      const tab = tabs[0];
      startTracking(
        tab.id!,
        windowId,
        tab.url!,
        tab.title,
        "tab_switch",
      );
    });
  });

  // Idle detection
  chrome.idle.setDetectionInterval(60);
  chrome.idle.onStateChanged.addListener((state) => {
    if (state === "idle" || state === "locked") {
      if (activeEvent) {
        activeEvent.endTime = Date.now();
        finalizeActiveEvent("unknown");
      }
    } else if (state === "active") {
      chrome.tabs.query({ active: true, lastFocusedWindow: true }, (tabs) => {
        if (chrome.runtime.lastError || !tabs?.[0]?.url) return;
        const tab = tabs[0];
        startTracking(
          tab.id!,
          tab.windowId,
          tab.url!,
          tab.title,
          "tab_switch",
        );
      });
    }
  });

  // Extension shutdown – try to finalize
  chrome.runtime.onSuspend.addListener(() => {
    finalizeActiveEvent("unknown");
  });
}

// Expose for testing
export const __test = {
  finalizeActiveEvent,
  startTracking,
  get activeEvent() {
    return activeEvent;
  },
  reset() {
    activeEvent = null;
    previousEventId = null;
    lastFinalizedUrl = null;
  },
};
