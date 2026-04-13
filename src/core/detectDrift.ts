// ---------------------------------------------------------------------------
// Drift detection engine
// ---------------------------------------------------------------------------

import {
  BrowsingEvent,
  Transition,
  DriftPoint,
  DriftTrigger,
  SessionIntent,
  IntentLabel,
} from "./types";
import { generateId } from "./normalize";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

/** Window (ms) within which rapid tab switches are counted. */
const RAPID_SWITCH_WINDOW_MS = 30_000;

/** Minimum number of unique-domain switches to trigger the rapid-switching rule. */
const RAPID_SWITCH_MIN_COUNT = 3;

/** Minimum streak duration (ms) of distraction events to trigger the streak rule. */
const DISTRACTION_STREAK_THRESHOLD_MS = 120_000; // 2 min

/** Minimum number of productive-to-distraction bounces to trigger the bounce rule. */
const BOUNCE_MIN_OCCURRENCES = 3;

// ---------------------------------------------------------------------------
// Session intent heuristic
// ---------------------------------------------------------------------------

/**
 * Infer the high-level intent of a session from its first few events.
 *
 * The heuristic examines up to the first 3 classified events and uses
 * domain-specific signals (code repos, doc editors, streaming sites)
 * to assign a label and confidence score.
 *
 * @param events - The session's events (should already be classified).
 * @returns A `SessionIntent` with label, confidence, and source event IDs.
 */
export function inferSessionIntent(events: BrowsingEvent[]): SessionIntent {
  const seedEvents = events.slice(0, 3).filter((e) => e.category);
  if (seedEvents.length === 0) {
    return { label: "unknown", confidence: 0, basedOnEventIds: [] };
  }

  const categories = seedEvents.map((e) => e.category!);
  const domains = seedEvents.map((e) => e.domain);
  const ids = seedEvents.map((e) => e.id);

  const productiveCount = categories.filter((c) => c === "productive").length;
  const distractionCount = categories.filter((c) => c === "distraction").length;

  // Check domain-specific hints
  const hasCode = domains.some((d) =>
    ["github.com", "gitlab.com", "stackoverflow.com", "leetcode.com",
     "bitbucket.org", "codepen.io", "codesandbox.io", "stackblitz.com",
     "replit.com", "dev.azure.com"].includes(d),
  );
  const hasDocs = domains.some((d) =>
    ["docs.google.com", "notion.so", "overleaf.com", "coda.io",
     "sheets.google.com", "slides.google.com", "quip.com"].includes(d),
  );
  const hasSearch = domains.some((d) =>
    ["google.com", "bing.com", "duckduckgo.com", "scholar.google.com",
     "perplexity.ai"].includes(d),
  );
  const hasEntertainment = domains.some((d) =>
    ["youtube.com", "netflix.com", "twitch.tv", "hulu.com",
     "disneyplus.com", "spotify.com", "music.youtube.com"].includes(d),
  );
  const hasDesign = domains.some((d) =>
    ["figma.com", "canva.com", "miro.com", "sketch.com",
     "whimsical.com", "excalidraw.com"].includes(d),
  );

  let label: IntentLabel = "unknown";
  let confidence = 0.3;

  if (productiveCount >= 2) {
    if (hasCode) {
      label = "work";
      confidence = 0.8;
    } else if (hasDesign) {
      label = "work";
      confidence = 0.75;
    } else if (hasDocs) {
      label = "study";
      confidence = 0.7;
    } else {
      label = "work";
      confidence = 0.6;
    }
  } else if (distractionCount >= 2 || hasEntertainment) {
    label = "entertainment";
    confidence = 0.7;
  } else if (hasSearch && productiveCount >= 1) {
    label = "research";
    confidence = 0.5;
  } else if (productiveCount > 0 && distractionCount > 0) {
    label = "mixed";
    confidence = 0.4;
  }

  return { label, confidence, basedOnEventIds: ids };
}

// ---------------------------------------------------------------------------
// Drift rules
// ---------------------------------------------------------------------------

type DriftRule = (
  events: BrowsingEvent[],
  transitions: Transition[],
  sessionId: string,
  eventById: ReadonlyMap<string, BrowsingEvent>,
) => DriftPoint[];

/**
 * Rule 1: Productive-to-distraction transition.
 *
 * Fires whenever a transition moves from a productive page to a
 * distraction page.
 */
const productiveToDistraction: DriftRule = (_events, transitions, sessionId, eventById) => {
  const points: DriftPoint[] = [];
  for (const t of transitions) {
    if (t.fromCategory === "productive" && t.toCategory === "distraction") {
      const targetEvent = eventById.get(t.targetEventId);
      points.push({
        id: generateId(),
        sessionId,
        transitionId: t.id,
        eventId: t.targetEventId,
        timestamp: targetEvent?.startTime ?? 0,
        reason: `Switched from productive (${t.sourceDomain}) to distraction (${t.targetDomain})`,
        trigger: "productive_to_distraction",
      });
    }
  }
  return points;
};

/**
 * Rule 2: Rapid tab switching.
 *
 * Fires when the user switches between >= RAPID_SWITCH_MIN_COUNT unique
 * domains within RAPID_SWITCH_WINDOW_MS.  Uses a sliding-window approach
 * (no array copies) for O(n) performance.
 */
const rapidSwitching: DriftRule = (events, _transitions, sessionId, _eventById) => {
  const points: DriftPoint[] = [];
  const n = events.length;
  if (n < RAPID_SWITCH_MIN_COUNT) return points;

  for (let i = 0; i <= n - RAPID_SWITCH_MIN_COUNT; i++) {
    const windowEnd = i + RAPID_SWITCH_MIN_COUNT;
    const timeSpan = events[windowEnd - 1].startTime - events[i].startTime;

    if (timeSpan > RAPID_SWITCH_WINDOW_MS) continue;

    // Count unique domains in the window
    const windowDomains = new Set<string>();
    for (let j = i; j < windowEnd; j++) {
      windowDomains.add(events[j].domain);
    }

    if (windowDomains.size >= RAPID_SWITCH_MIN_COUNT) {
      const alreadyMarked = points.some(
        (p) =>
          p.trigger === "rapid_switching" &&
          Math.abs(p.timestamp - events[i].startTime) < RAPID_SWITCH_WINDOW_MS,
      );
      if (!alreadyMarked) {
        points.push({
          id: generateId(),
          sessionId,
          eventId: events[i].id,
          timestamp: events[i].startTime,
          reason: `Rapid switching between ${windowDomains.size} domains within ${Math.round(timeSpan / 1000)}s`,
          trigger: "rapid_switching",
        });
      }
    }
  }
  return points;
};

/**
 * Rule 3: Sharp domain jump.
 *
 * Fires when the user makes an impulsive jump (< 2 s gap) from a
 * productive page to an unrelated distraction page.
 */
const sharpJump: DriftRule = (_events, transitions, sessionId, eventById) => {
  const points: DriftPoint[] = [];
  for (const t of transitions) {
    if (
      t.fromCategory === "productive" &&
      t.toCategory === "distraction" &&
      t.sourceDomain !== t.targetDomain &&
      t.timeGapMs < 2000
    ) {
      const targetEvent = eventById.get(t.targetEventId);
      points.push({
        id: generateId(),
        sessionId,
        transitionId: t.id,
        eventId: t.targetEventId,
        timestamp: targetEvent?.startTime ?? 0,
        reason: `Sharp jump from ${t.sourceDomain} to unrelated ${t.targetDomain}`,
        trigger: "sharp_jump",
      });
    }
  }
  return points;
};

/**
 * Rule 4: Long distraction streak after a productive start.
 *
 * Fires when the user accumulates >= DISTRACTION_STREAK_THRESHOLD_MS
 * of consecutive distraction events after having been productive.
 */
const distractionStreak: DriftRule = (events, _transitions, sessionId, _eventById) => {
  const points: DriftPoint[] = [];
  const firstProductive = events.find((e) => e.category === "productive");
  if (!firstProductive) return points;

  let streakStart: BrowsingEvent | null = null;
  let streakMs = 0;

  for (const e of events) {
    if (e.startTime < firstProductive.startTime) continue;
    if (e.category === "distraction") {
      if (!streakStart) streakStart = e;
      streakMs += Math.max(0, e.durationMs);
    } else {
      if (streakStart && streakMs >= DISTRACTION_STREAK_THRESHOLD_MS) {
        points.push({
          id: generateId(),
          sessionId,
          eventId: streakStart.id,
          timestamp: streakStart.startTime,
          reason: `Distraction streak of ${Math.round(streakMs / 1000)}s after productive start`,
          trigger: "distraction_streak",
        });
      }
      streakStart = null;
      streakMs = 0;
    }
  }

  // Check trailing streak
  if (streakStart && streakMs >= DISTRACTION_STREAK_THRESHOLD_MS) {
    points.push({
      id: generateId(),
      sessionId,
      eventId: streakStart.id,
      timestamp: streakStart.startTime,
      reason: `Distraction streak of ${Math.round(streakMs / 1000)}s after productive start`,
      trigger: "distraction_streak",
    });
  }
  return points;
};

/**
 * Rule 5: Repeated bouncing back to distraction.
 *
 * Fires when the user alternates productive -> distraction
 * at least BOUNCE_MIN_OCCURRENCES times in a session.
 */
const repeatedBounce: DriftRule = (events, _transitions, sessionId, _eventById) => {
  const points: DriftPoint[] = [];
  let bounceCount = 0;
  let bounceStartEvent: BrowsingEvent | null = null;

  for (let i = 1; i < events.length; i++) {
    const prev = events[i - 1];
    const curr = events[i];
    if (prev.category === "productive" && curr.category === "distraction") {
      bounceCount++;
      if (!bounceStartEvent) bounceStartEvent = curr;
    }
  }

  if (bounceCount >= BOUNCE_MIN_OCCURRENCES && bounceStartEvent) {
    points.push({
      id: generateId(),
      sessionId,
      eventId: bounceStartEvent.id,
      timestamp: bounceStartEvent.startTime,
      reason: `Repeatedly bounced back to distraction ${bounceCount} times`,
      trigger: "repeated_bounce",
    });
  }
  return points;
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

const ALL_RULES: DriftRule[] = [
  productiveToDistraction,
  rapidSwitching,
  sharpJump,
  distractionStreak,
  repeatedBounce,
];

/**
 * Run all drift-detection rules against a session's events and transitions.
 *
 * Performance: builds an O(1) event-by-ID lookup map up front so
 * individual rules avoid repeated linear scans.  Results are
 * deduplicated by `eventId + trigger` and sorted by timestamp.
 *
 * @param sessionId   - The session ID.
 * @param events      - The session's classified events.
 * @param transitions - The session's transitions.
 * @param rules       - Optional custom rule set (defaults to all rules).
 * @returns Deduplicated, timestamp-sorted array of drift points.
 */
export function detectDrift(
  sessionId: string,
  events: BrowsingEvent[],
  transitions: Transition[],
  rules: DriftRule[] = ALL_RULES,
): DriftPoint[] {
  if (events.length === 0) return [];

  // Pre-build event lookup map -- O(n) once instead of O(n) per find call
  const eventById = new Map<string, BrowsingEvent>();
  for (const e of events) {
    eventById.set(e.id, e);
  }

  const allPoints: DriftPoint[] = [];
  for (const rule of rules) {
    const points = rule(events, transitions, sessionId, eventById);
    for (const p of points) {
      allPoints.push(p);
    }
  }

  // Sort by timestamp and deduplicate by eventId+trigger
  allPoints.sort((a, b) => a.timestamp - b.timestamp);
  const seen = new Set<string>();
  return allPoints.filter((p) => {
    const key = `${p.eventId ?? ""}:${p.trigger}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/**
 * Mark drift flags on events in-place based on detected drift points.
 *
 * After calling this, events referenced by drift points will have
 * `drift = true` and a `driftReasons` array.
 *
 * @param events      - The session's events (mutated in-place).
 * @param driftPoints - The drift points detected for this session.
 */
export function applyDriftToEvents(
  events: BrowsingEvent[],
  driftPoints: DriftPoint[],
): void {
  if (driftPoints.length === 0) return;

  const driftEventIds = new Set<string>();
  const reasonsByEvent = new Map<string, string[]>();

  for (const dp of driftPoints) {
    if (dp.eventId) {
      driftEventIds.add(dp.eventId);
      const existing = reasonsByEvent.get(dp.eventId);
      if (existing) {
        existing.push(dp.reason);
      } else {
        reasonsByEvent.set(dp.eventId, [dp.reason]);
      }
    }
  }

  for (const e of events) {
    if (driftEventIds.has(e.id)) {
      e.drift = true;
      e.driftReasons = reasonsByEvent.get(e.id);
    }
  }
}
