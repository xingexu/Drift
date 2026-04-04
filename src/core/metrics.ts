// ---------------------------------------------------------------------------
// Metrics engine
// ---------------------------------------------------------------------------

import { BrowsingEvent, SessionStats, Category } from "./types";

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
    const cat = e.category ?? "neutral";

    // Time by category
    if (cat === "productive") productiveTimeMs += e.durationMs;
    else if (cat === "distraction") distractionTimeMs += e.durationMs;
    else neutralTimeMs += e.durationMs;

    // Domain tracking
    uniqueDomains.add(e.domain);
    domainTime.set(e.domain, (domainTime.get(e.domain) ?? 0) + e.durationMs);

    // Revisits
    if (visitedUrls.has(e.normalizedUrl)) {
      revisitCount++;
    }
    visitedUrls.add(e.normalizedUrl);

    // Longest single page
    if (e.durationMs > longestSinglePageMs) {
      longestSinglePageMs = e.durationMs;
    }

    // Category switches
    if (i > 0 && events[i - 1].category !== cat) {
      categorySwitchCount++;
    }

    // Streaks
    if (cat === currentStreakCategory) {
      currentStreakMs += e.durationMs;
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
      currentStreakMs = e.durationMs;
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

  // Most visited domain
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
    driftPointCount: events.filter((e) => e.drift).length,
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
 */
export function computeDriftScore(stats: SessionStats): number {
  const total =
    stats.productiveTimeMs + stats.neutralTimeMs + stats.distractionTimeMs;
  if (total === 0) return 0;
  return Math.round((stats.distractionTimeMs / total) * 100);
}

/**
 * Generate a concise session label from stats and drift score.
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
