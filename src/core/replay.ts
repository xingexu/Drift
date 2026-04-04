// ---------------------------------------------------------------------------
// Replay step generator
// ---------------------------------------------------------------------------

import { BrowsingEvent, ReplayStep } from "./types";

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
