// ---------------------------------------------------------------------------
// Sessionizer -- groups BrowsingEvents into sessions
// ---------------------------------------------------------------------------

import { BrowsingEvent, SessionId } from "./types";
import { generateId } from "./normalize";

/** Default inactivity gap that triggers a new session (10 minutes). */
const DEFAULT_GAP_THRESHOLD_MS = 10 * 60 * 1000;

/**
 * Split a list of events into session buckets based on inactivity gaps.
 *
 * Events are sorted by `startTime` internally so callers do not need to
 * pre-sort.  A new session is created whenever the gap between the end
 * of one event and the start of the next exceeds `gapThresholdMs`.
 *
 * @param events          - The browsing events to sessionize.
 * @param gapThresholdMs  - Minimum gap (ms) between events to start a new
 *                          session.  Defaults to 10 minutes.
 * @returns An array of arrays, each sub-array being a session's events.
 */
export function sessionizeEvents(
  events: BrowsingEvent[],
  gapThresholdMs: number = DEFAULT_GAP_THRESHOLD_MS,
): BrowsingEvent[][] {
  if (events.length === 0) return [];

  const sorted = [...events].sort((a, b) => a.startTime - b.startTime);
  const sessions: BrowsingEvent[][] = [];
  let current: BrowsingEvent[] = [sorted[0]];

  for (let i = 1; i < sorted.length; i++) {
    const prev = sorted[i - 1];
    const curr = sorted[i];
    // Clamp gap to zero when events overlap (endTime > next startTime).
    const gap = Math.max(0, curr.startTime - prev.endTime);

    if (gap > gapThresholdMs) {
      sessions.push(current);
      current = [curr];
    } else {
      current.push(curr);
    }
  }
  sessions.push(current);
  return sessions;
}

/**
 * Assign session IDs to events in-place and return session groups.
 *
 * Each group contains a generated `sessionId` and its events, which
 * have been mutated to carry that session ID.
 *
 * @param events          - The browsing events (mutated in-place).
 * @param gapThresholdMs  - Optional gap threshold override.
 * @returns An array of `{ sessionId, events }` objects.
 */
export function assignSessionIds(
  events: BrowsingEvent[],
  gapThresholdMs?: number,
): { sessionId: SessionId; events: BrowsingEvent[] }[] {
  const groups = sessionizeEvents(events, gapThresholdMs);
  return groups.map((group) => {
    const sessionId = generateId();
    for (const e of group) {
      e.sessionId = sessionId;
    }
    return { sessionId, events: group };
  });
}
