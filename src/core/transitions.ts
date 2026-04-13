// ---------------------------------------------------------------------------
// Transition modelling
// ---------------------------------------------------------------------------

import { BrowsingEvent, Transition } from "./types";
import { generateId } from "./normalize";

/**
 * Build an ordered list of transitions for a session's events.
 * Events must already be sorted chronologically.
 */
export function buildTransitions(
  sessionId: string,
  events: BrowsingEvent[],
): Transition[] {
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
      timeGapMs: Math.max(0, tgt.startTime - src.endTime),
      isCategoryShift: src.category !== tgt.category,
      fromCategory: src.category,
      toCategory: tgt.category,
    });
  }
  return transitions;
}
