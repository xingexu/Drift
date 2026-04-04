// ---------------------------------------------------------------------------
// Summary & narrative generation
// ---------------------------------------------------------------------------

import {
  BrowsingEvent,
  BrowsingSession,
  SessionSummary,
  SessionStats,
} from "./types";

function formatMs(ms: number): string {
  const seconds = Math.round(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes} minute${minutes !== 1 ? "s" : ""}`;
  const hours = Math.floor(minutes / 60);
  const rem = minutes % 60;
  return `${hours}h ${rem}m`;
}

export function buildSessionSummary(session: BrowsingSession): SessionSummary {
  const { events, stats } = session;
  const entry = events[0];
  const exit = events[events.length - 1];

  return {
    sessionId: session.id,
    startTime: session.startTime,
    endTime: session.endTime,
    entryDomain: entry?.domain ?? "",
    exitDomain: exit?.domain ?? "",
    inferredIntent: session.intent?.label ?? "unknown",
    totalActiveTimeMs: session.totalDurationMs,
    productiveTimeMs: stats.productiveTimeMs,
    neutralTimeMs: stats.neutralTimeMs,
    distractionTimeMs: stats.distractionTimeMs,
    driftScore: session.driftScore,
    driftPointCount: stats.driftPointCount,
    longestDistractionStreakMs: stats.longestDistractionStreakMs,
    summaryLabel: session.summaryLabel,
    narrative: generateNarrative(session),
  };
}

function generateNarrative(session: BrowsingSession): string {
  const { events, stats, driftScore, intent } = session;
  if (events.length === 0) return "Empty session.";

  const entry = events[0];
  const exit = events[events.length - 1];
  const parts: string[] = [];

  // Opening
  const intentLabel = intent?.label ?? "unknown";
  if (intentLabel === "work" || intentLabel === "study") {
    parts.push(
      `Started in ${entry.domain}, likely for ${intentLabel}.`,
    );
  } else if (intentLabel === "entertainment") {
    parts.push(`Started with ${entry.domain} in an entertainment mode.`);
  } else {
    parts.push(`Started browsing at ${entry.domain}.`);
  }

  // Productive time
  if (stats.productiveTimeMs > 0) {
    parts.push(
      `Spent ${formatMs(stats.productiveTimeMs)} on productive pages.`,
    );
  }

  // Drift info
  if (stats.driftPointCount > 0 && stats.distractionTimeMs > 0) {
    parts.push(
      `Drifted into distraction for ${formatMs(stats.distractionTimeMs)}.`,
    );
  } else if (stats.distractionTimeMs > 0) {
    parts.push(
      `${formatMs(stats.distractionTimeMs)} spent on distracting pages.`,
    );
  }

  // Closing
  if (stats.focusRatio >= 0.7) {
    parts.push("Overall a focused session.");
  } else if (driftScore >= 50) {
    parts.push("Attention drifted significantly during this session.");
  }

  if (entry.domain !== exit.domain) {
    parts.push(`Ended on ${exit.domain}.`);
  }

  return parts.join(" ");
}
