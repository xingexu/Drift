// ---------------------------------------------------------------------------
// Replay step generator
// ---------------------------------------------------------------------------

import { BrowsingEvent, ReplayStep } from "./types";

/**
 * Build an ordered list of replay steps from session events.
 *
 * Each step captures a snapshot of the event at that point in the
 * timeline, suitable for driving a session-replay UI.
 *
 * @param events - The session's events in chronological order.
 * @returns An array of replay steps, one per event, numbered starting at 1.
 */
export function buildReplaySteps(events: BrowsingEvent[]): ReplayStep[] {
  return events.map((e, i) => ({
    step: i + 1,
    eventId: e.id,
    timestamp: e.startTime,
    domain: e.domain,
    normalizedUrl: e.normalizedUrl,
    title: e.title,
    durationMs: e.durationMs,
    category: e.category ?? "neutral",
    drift: e.drift ?? false,
    driftReasons: e.driftReasons,
  }));
}
