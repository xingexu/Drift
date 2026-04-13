// ---------------------------------------------------------------------------
// Transition modelling
// ---------------------------------------------------------------------------

import { BrowsingEvent, Transition } from "./types";
import { generateId } from "./normalize";

/**
 * Build an ordered list of transitions for a session's events.
 *
 * Each transition captures the navigation from one event to the next,
 * including domain information, category shift detection, and the time
 * gap between events.
 *
 * **Bug fix**: `timeGapMs` is clamped to `>= 0` so overlapping events
 * (where `endTime > nextStartTime`) produce a zero gap rather than a
 * negative value.
 *
 * @param sessionId - The session these transitions belong to.
 * @param events    - Chronologically-sorted events for the session.
 * @returns An ordered array of transitions.
 */
export function buildTransitions(
  sessionId: string,
  events: BrowsingEvent[],
): Transition[] {
  if (events.length < 2) return [];

  const transitions: Transition[] = [];
  for (let i = 1; i < events.length; i++) {
    const src = events[i - 1];
    const tgt = events[i];
    transitions.push({
      id: generateId(),
      sessionId,
      sourceEventId: src.id,
      targetEventId: tgt.id,
      sourceDomain: src.domain,
      targetDomain: tgt.domain,
      sourceNormalizedUrl: src.normalizedUrl,
      targetNormalizedUrl: tgt.normalizedUrl,
      // Clamp to zero: overlapping events should not produce negative gaps
      timeGapMs: Math.max(0, tgt.startTime - src.endTime),
      isCategoryShift: (src.category ?? "neutral") !== (tgt.category ?? "neutral"),
      fromCategory: src.category,
      toCategory: tgt.category,
    });
  }
  return transitions;
}
