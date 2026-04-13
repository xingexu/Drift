// ---------------------------------------------------------------------------
// Metrics engine
// ---------------------------------------------------------------------------

import { BrowsingEvent, SessionStats, Category } from "./types";

/**
 * Compute aggregate statistics for a set of session events.
 *
 * Handles edge cases:
 * - Empty event arrays return zero-valued stats.
 * - Negative `durationMs` values are clamped to 0.
 * - Single-event sessions produce valid stats with 0 transitions.
 * - Division-by-zero is guarded when computing ratios.
 *
 * @param events - The session's browsing events.
 * @returns A `SessionStats` object with all aggregate metrics.
 */
export function computeSessionStats(events: BrowsingEvent[]): SessionStats {
  if (events.length === 0) {
    return emptyStats();
  }

  let productiveTimeMs = 0;
  let neutralTimeMs = 0;
  let distractionTimeMs = 0;
  let categorySwitchCount = 0;
  let longestProductiveStreakMs = 0;
  let longestDistractionStreakMs = 0;
  let longestSinglePageMs = 0;
  let revisitCount = 0;

  const domainTime = new Map<string, number>();
  const uniqueDomains = new Set<string>();
  const visitedUrls = new Set<string>();

  let currentStreakCategory: Category | null = null;
  let currentStreakMs = 0;

  for (let i = 0; i < events.length; i++) {
    const e = events[i];
    const cat: Category = e.category ?? "neutral";
    // Guard against negative durations from bad data
    const dur = Math.max(0, e.durationMs);

    // Time by category
    if (cat === "productive") productiveTimeMs += dur;
    else if (cat === "distraction") distractionTimeMs += dur;
    else neutralTimeMs += dur;

    // Domain tracking
    uniqueDomains.add(e.domain);
    domainTime.set(e.domain, (domainTime.get(e.domain) ?? 0) + dur);

    // Revisits
    if (visitedUrls.has(e.normalizedUrl)) {
      revisitCount++;
    }
    visitedUrls.add(e.normalizedUrl);

    // Longest single page
    if (dur > longestSinglePageMs) {
      longestSinglePageMs = dur;
    }

    // Category switches
    if (i > 0 && events[i - 1].category !== cat) {
      categorySwitchCount++;
    }

    // Streaks
    if (cat === currentStreakCategory) {
      currentStreakMs += dur;
    } else {
      // Finalize previous streak
      if (currentStreakCategory === "productive") {
        longestProductiveStreakMs = Math.max(
          longestProductiveStreakMs,
          currentStreakMs,
        );
      } else if (currentStreakCategory === "distraction") {
        longestDistractionStreakMs = Math.max(
          longestDistractionStreakMs,
          currentStreakMs,
        );
      }
      currentStreakCategory = cat;
      currentStreakMs = dur;
    }
  }

  // Finalize last streak
  if (currentStreakCategory === "productive") {
    longestProductiveStreakMs = Math.max(
      longestProductiveStreakMs,
      currentStreakMs,
    );
  } else if (currentStreakCategory === "distraction") {
    longestDistractionStreakMs = Math.max(
      longestDistractionStreakMs,
      currentStreakMs,
    );
  }

  // Most visited domain by total time
  let mostVisitedDomain = "";
  let maxTime = 0;
  for (const [domain, time] of domainTime) {
    if (time > maxTime) {
      maxTime = time;
      mostVisitedDomain = domain;
    }
  }

  const totalActive = productiveTimeMs + neutralTimeMs + distractionTimeMs;

  return {
    eventCount: events.length,
    uniqueDomains: uniqueDomains.size,
    transitionCount: Math.max(0, events.length - 1),
    driftPointCount: 0, // Set by pipeline after drift detection
    categorySwitchCount,
    productiveTimeMs,
    neutralTimeMs,
    distractionTimeMs,
    longestProductiveStreakMs,
    longestDistractionStreakMs,
    mostVisitedDomain,
    longestSinglePageMs,
    focusRatio: totalActive > 0 ? productiveTimeMs / totalActive : 0,
    distractionRatio: totalActive > 0 ? distractionTimeMs / totalActive : 0,
    revisitCount,
  };
}

/**
 * Return a zero-valued `SessionStats` for empty sessions.
 *
 * @returns An empty stats object with all numeric fields set to 0.
 */
function emptyStats(): SessionStats {
  return {
    eventCount: 0,
    uniqueDomains: 0,
    transitionCount: 0,
    driftPointCount: 0,
    categorySwitchCount: 0,
    productiveTimeMs: 0,
    neutralTimeMs: 0,
    distractionTimeMs: 0,
    longestProductiveStreakMs: 0,
    longestDistractionStreakMs: 0,
    mostVisitedDomain: "",
    longestSinglePageMs: 0,
    focusRatio: 0,
    distractionRatio: 0,
    revisitCount: 0,
  };
}

/**
 * Compute a drift score: percentage of active time spent in distraction.
 *
 * The score is an integer between 0 and 100 inclusive.  Returns 0 for
 * sessions with no active time.
 *
 * @param stats - The session stats to compute the score from.
 * @returns An integer drift score (0 = fully focused, 100 = fully distracted).
 */
export function computeDriftScore(stats: SessionStats): number {
  const total =
    stats.productiveTimeMs + stats.neutralTimeMs + stats.distractionTimeMs;
  if (total <= 0) return 0;
  return Math.round(
    Math.min(100, Math.max(0, (stats.distractionTimeMs / total) * 100)),
  );
}

/**
 * Generate a concise human-readable session label from stats and drift score.
 *
 * Labels are intentionally short so they fit in UI badges and sidebar entries.
 *
 * @param stats      - The session statistics.
 * @param driftScore - The session's drift score (0-100).
 * @returns A short descriptive label string.
 */
export function computeSummaryLabel(
  stats: SessionStats,
  driftScore: number,
): string {
  if (stats.eventCount === 0) return "Empty session";

  if (stats.focusRatio >= 0.8 && driftScore < 10) {
    return "Primarily productive";
  }
  if (stats.focusRatio >= 0.6 && driftScore < 25) {
    return "Focused with minor drift";
  }
  if (stats.distractionRatio >= 0.7) {
    return "Heavy distraction session";
  }
  if (stats.distractionRatio >= 0.5) {
    return "Entertainment-driven session";
  }
  return "Mixed attention";
}
