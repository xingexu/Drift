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
  Category,
} from "./types";
import { generateId } from "./normalize";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const RAPID_SWITCH_WINDOW_MS = 30_000;
const RAPID_SWITCH_MIN_COUNT = 3;
const DISTRACTION_STREAK_THRESHOLD_MS = 120_000; // 2 min streak
const BOUNCE_MIN_OCCURRENCES = 3;

// ---------------------------------------------------------------------------
// Session intent heuristic
// ---------------------------------------------------------------------------

export function inferSessionIntent(events: BrowsingEvent[]): SessionIntent {
  if (events.length === 0) {
    return { label: "unknown", confidence: 0, basedOnEventIds: [] };
  }
  const seedEvents = events.slice(0, 3).filter((e) => e.category);
  if (seedEvents.length === 0) {
    return { label: "unknown", confidence: 0, basedOnEventIds: [] };
  }

  const categories = seedEvents.map((e) => e.category!);
  const domains = seedEvents.map((e) => e.domain);
  const ids = seedEvents.map((e) => e.id);

  const productiveCount = categories.filter((c) => c === "productive").length;
  const distractionCount = categories.filter(
    (c) => c === "distraction",
  ).length;

  // Check domain-specific hints
  const hasCode = domains.some((d) =>
    ["github.com", "gitlab.com", "stackoverflow.com", "leetcode.com"].includes(
      d,
    ),
  );
  const hasDocs = domains.some((d) =>
    ["docs.google.com", "notion.so", "overleaf.com"].includes(d),
  );
  const hasSearch = domains.some((d) =>
    ["google.com", "bing.com", "duckduckgo.com"].includes(d),
  );
  const hasEntertainment = domains.some((d) =>
    ["youtube.com", "netflix.com", "twitch.tv"].includes(d),
  );

  let label: IntentLabel = "unknown";
  let confidence = 0.3;

  if (productiveCount >= 2) {
    if (hasCode) {
      label = "work";
      confidence = 0.8;
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
) => DriftPoint[];

// Rule 1: Productive → distraction transition
const productiveToDistraction: DriftRule = (events, transitions, sessionId) => {
  const points: DriftPoint[] = [];
  // Build lookup once: O(n) instead of O(n) per transition
  const eventById = new Map<string, BrowsingEvent>();
  for (const e of events) eventById.set(e.id, e);

  for (const t of transitions) {
    if (t.fromCategory === "productive" && t.toCategory === "distraction") {
      points.push({
        id: generateId(),
        sessionId,
        transitionId: t.id,
        eventId: t.targetEventId,
        timestamp: eventById.get(t.targetEventId)?.startTime ?? 0,
        reason: `Switched from productive (${t.sourceDomain}) to distraction (${t.targetDomain})`,
        trigger: "productive_to_distraction",
      });
    }
  }
  return points;
};

// Rule 2: Rapid tab switching
const rapidSwitching: DriftRule = (events, _transitions, sessionId) => {
  const points: DriftPoint[] = [];
  for (let i = 0; i <= events.length - RAPID_SWITCH_MIN_COUNT; i++) {
    const window = events.slice(i, i + RAPID_SWITCH_MIN_COUNT);
    const timeSpan =
      window[window.length - 1].startTime - window[0].startTime;
    const uniqueDomains = new Set(window.map((e) => e.domain)).size;

    if (timeSpan <= RAPID_SWITCH_WINDOW_MS && uniqueDomains >= RAPID_SWITCH_MIN_COUNT) {
      const alreadyMarked = points.some(
        (p) =>
          p.trigger === "rapid_switching" &&
          Math.abs(p.timestamp - window[0].startTime) < RAPID_SWITCH_WINDOW_MS,
      );
      if (!alreadyMarked) {
        points.push({
          id: generateId(),
          sessionId,
          eventId: window[0].id,
          timestamp: window[0].startTime,
          reason: `Rapid switching between ${uniqueDomains} domains within ${Math.round(timeSpan / 1000)}s`,
          trigger: "rapid_switching",
        });
      }
    }
  }
  return points;
};

// Rule 3: Sharp domain jump (productive → unrelated distraction)
const sharpJump: DriftRule = (events, transitions, sessionId) => {
  const points: DriftPoint[] = [];
  // Build lookup once: O(n) instead of O(n) per transition
  const eventById = new Map<string, BrowsingEvent>();
  for (const e of events) eventById.set(e.id, e);

  for (const t of transitions) {
    if (
      t.fromCategory === "productive" &&
      t.toCategory === "distraction" &&
      t.sourceDomain !== t.targetDomain
    ) {
      // Avoid duplicating productiveToDistraction – only fire if the gap is very small
      // indicating an impulsive jump
      if (t.timeGapMs < 2000) {
        points.push({
          id: generateId(),
          sessionId,
          transitionId: t.id,
          eventId: t.targetEventId,
          timestamp:
            eventById.get(t.targetEventId)?.startTime ?? 0,
          reason: `Sharp jump from ${t.sourceDomain} to unrelated ${t.targetDomain}`,
          trigger: "sharp_jump",
        });
      }
    }
  }
  return points;
};

// Rule 4: Long distraction streak after productive start
const distractionStreak: DriftRule = (events, _transitions, sessionId) => {
  const points: DriftPoint[] = [];
  const firstProductive = events.find((e) => e.category === "productive");
  if (!firstProductive) return points;

  let streakStart: BrowsingEvent | null = null;
  let streakMs = 0;

  for (const e of events) {
    if (e.startTime < firstProductive.startTime) continue;
    if (e.category === "distraction") {
      if (!streakStart) streakStart = e;
      streakMs += e.durationMs;
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

// Rule 5: Repeated bouncing back to distraction
const repeatedBounce: DriftRule = (events, _transitions, sessionId) => {
  const points: DriftPoint[] = [];
  // Count how many times user goes productive→distraction→productive→distraction…
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

export function detectDrift(
  sessionId: string,
  events: BrowsingEvent[],
  transitions: Transition[],
  rules: DriftRule[] = ALL_RULES,
): DriftPoint[] {
  const allPoints: DriftPoint[] = [];
  for (const rule of rules) {
    allPoints.push(...rule(events, transitions, sessionId));
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
 */
export function applyDriftToEvents(
  events: BrowsingEvent[],
  driftPoints: DriftPoint[],
): void {
  const driftEventIds = new Set<string>();
  const reasonsByEvent = new Map<string, string[]>();

  for (const dp of driftPoints) {
    if (dp.eventId) {
      driftEventIds.add(dp.eventId);
      const existing = reasonsByEvent.get(dp.eventId) ?? [];
      existing.push(dp.reason);
      reasonsByEvent.set(dp.eventId, existing);
    }
  }

  for (const e of events) {
    if (driftEventIds.has(e.id)) {
      e.drift = true;
      e.driftReasons = reasonsByEvent.get(e.id);
    } else {
      // Reset stale flags if pipeline is re-run on the same events
      e.drift = false;
      e.driftReasons = undefined;
    }
  }
}
