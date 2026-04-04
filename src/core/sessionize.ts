// ---------------------------------------------------------------------------
// Sessionizer – groups BrowsingEvents into sessions
// ---------------------------------------------------------------------------

import { BrowsingEvent } from "./types";
import { generateId } from "./normalize";

const DEFAULT_GAP_THRESHOLD_MS = 10 * 60 * 1000; // 10 minutes

/**
 * Split a chronologically-sorted list of events into session buckets.
 * A new session starts whenever the gap between the end of one event
 * and the start of the next exceeds the threshold.
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
    const gap = curr.startTime - prev.endTime;

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
 * Assign session IDs to events in place and return the session groups.
 */
export function assignSessionIds(
  events: BrowsingEvent[],
  gapThresholdMs?: number,
): { sessionId: string; events: BrowsingEvent[] }[] {
  const groups = sessionizeEvents(events, gapThresholdMs);
  return groups.map((group) => {
    const sessionId = generateId();
    for (const e of group) {
      e.sessionId = sessionId;
    }
    return { sessionId, events: group };
  });
}
