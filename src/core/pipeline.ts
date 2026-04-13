// ---------------------------------------------------------------------------
// Pipeline – orchestrates the full processing flow
// ---------------------------------------------------------------------------

import { BrowsingEvent, BrowsingSession } from "./types";
import { assignSessionIds } from "./sessionize";
import { classifyEvents } from "./classify";
import { buildTransitions } from "./transitions";
import { detectDrift, applyDriftToEvents, inferSessionIntent } from "./detectDrift";
import { computeSessionStats, computeDriftScore, computeSummaryLabel } from "./metrics";
import { buildReplaySteps } from "./replay";
import { buildSessionGraph } from "./graph";
import { buildSessionSummary } from "./summaries";
import { generateId } from "./normalize";

export interface ProcessedOutput {
  sessions: BrowsingSession[];
}

/**
 * Run the full Drift processing pipeline on raw browsing events.
 *
 * 1. Classify events
 * 2. Sessionize
 * 3. For each session: build transitions, detect drift, compute metrics
 */
export function processPipeline(
  events: BrowsingEvent[],
  gapThresholdMs?: number,
): ProcessedOutput {
  if (events.length === 0) {
    return { sessions: [] };
  }

  // Step 1: classify
  classifyEvents(events);

  // Step 2: sessionize
  const groups = assignSessionIds(events, gapThresholdMs);

  // Step 3: build sessions
  const sessions: BrowsingSession[] = groups.map(({ sessionId, events: sessionEvents }) => {
    // Transitions
    const transitions = buildTransitions(sessionId, sessionEvents);

    // Intent
    const intent = inferSessionIntent(sessionEvents);

    // Drift
    const driftPoints = detectDrift(sessionId, sessionEvents, transitions);
    applyDriftToEvents(sessionEvents, driftPoints);

    // Metrics
    const stats = computeSessionStats(sessionEvents);
    stats.driftPointCount = driftPoints.length;
    const driftScore = computeDriftScore(stats);
    const summaryLabel = computeSummaryLabel(stats, driftScore);

    const first = sessionEvents[0];
    const last = sessionEvents[sessionEvents.length - 1];

    const session: BrowsingSession = {
      id: sessionId,
      events: sessionEvents,
      startTime: first.startTime,
      endTime: last.endTime,
      totalDurationMs: last.endTime - first.startTime,
      entryEventId: first.id,
      exitEventId: last.id,
      intent,
      driftScore,
      stats,
      transitions,
      driftPoints,
      summaryLabel,
    };

    return session;
  });

  return { sessions };
}

/**
 * Convenience: get all exportable shapes from a processed session.
 */
export function exportSession(session: BrowsingSession) {
  return {
    session,
    events: session.events,
    transitions: session.transitions,
    driftPoints: session.driftPoints,
    graph: buildSessionGraph(session.id, session.events, session.transitions),
    replay: buildReplaySteps(session.events),
    summary: buildSessionSummary(session),
  };
}
