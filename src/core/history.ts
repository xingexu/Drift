// ---------------------------------------------------------------------------
// Drift – Session history & weekly report utilities
// ---------------------------------------------------------------------------

import {
  BrowsingSession,
  SessionHistoryEntry,
  WeeklyReport,
  MonthlyReport,
} from "./types";
import { buildSessionSummary } from "./summaries";

// ---------------------------------------------------------------------------
// Build a compact history entry from a full session
// ---------------------------------------------------------------------------

export function buildHistoryEntry(session: BrowsingSession): SessionHistoryEntry {
  const summary = buildSessionSummary(session);

  // Aggregate top 5 domains by time
  const domainMap = new Map<string, number>();
  for (const e of session.events) {
    domainMap.set(e.domain, (domainMap.get(e.domain) ?? 0) + e.durationMs);
  }
  const topDomains = [...domainMap.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([domain, timeMs]) => ({ domain, timeMs }));

  return {
    sessionId: session.id,
    startTime: session.startTime,
    endTime: session.endTime,
    totalActiveTimeMs: summary.totalActiveTimeMs,
    productiveTimeMs: summary.productiveTimeMs,
    neutralTimeMs: summary.neutralTimeMs,
    distractionTimeMs: summary.distractionTimeMs,
    driftScore: summary.driftScore,
    driftPointCount: summary.driftPointCount,
    summaryLabel: summary.summaryLabel,
    entryDomain: summary.entryDomain,
    exitDomain: summary.exitDomain,
    topDomains,
    eventCount: session.events.length,
  };
}

// ---------------------------------------------------------------------------
// Compute a weekly report from history entries
// ---------------------------------------------------------------------------

const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;

export function computeWeeklyReport(entries: SessionHistoryEntry[]): WeeklyReport | null {
  const now = Date.now();
  const periodStart = now - SEVEN_DAYS_MS;
  const recent = entries.filter((e) => e.endTime >= periodStart);

  if (recent.length === 0) return null;

  let totalTimeMs = 0;
  let productiveTimeMs = 0;
  let neutralTimeMs = 0;
  let distractionTimeMs = 0;
  let driftScoreSum = 0;

  const domainMap = new Map<string, number>();

  for (const entry of recent) {
    totalTimeMs += entry.totalActiveTimeMs;
    productiveTimeMs += entry.productiveTimeMs;
    neutralTimeMs += entry.neutralTimeMs;
    distractionTimeMs += entry.distractionTimeMs;
    driftScoreSum += entry.driftScore;

    for (const d of entry.topDomains) {
      domainMap.set(d.domain, (domainMap.get(d.domain) ?? 0) + d.timeMs);
    }
  }

  const topDomains = [...domainMap.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([domain, timeMs]) => ({ domain, timeMs }));

  return {
    periodStart,
    periodEnd: now,
    sessionCount: recent.length,
    totalTimeMs,
    productiveTimeMs,
    neutralTimeMs,
    distractionTimeMs,
    averageDriftScore: Math.round(driftScoreSum / recent.length),
    topDomains,
  };
}

// ---------------------------------------------------------------------------
// Compute a monthly report from history entries (30 days)
// ---------------------------------------------------------------------------

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;
const ONE_DAY_MS = 24 * 60 * 60 * 1000;

export function computeMonthlyReport(entries: SessionHistoryEntry[]): MonthlyReport | null {
  const now = Date.now();
  const periodStart = now - THIRTY_DAYS_MS;
  const recent = entries.filter((e) => e.endTime >= periodStart);

  if (recent.length === 0) return null;

  let totalTimeMs = 0;
  let productiveTimeMs = 0;
  let neutralTimeMs = 0;
  let distractionTimeMs = 0;
  let driftScoreSum = 0;

  const domainMap = new Map<string, number>();
  const dayMap = new Map<string, { driftScore: number; count: number; totalMs: number }>();

  for (const entry of recent) {
    totalTimeMs += entry.totalActiveTimeMs;
    productiveTimeMs += entry.productiveTimeMs;
    neutralTimeMs += entry.neutralTimeMs;
    distractionTimeMs += entry.distractionTimeMs;
    driftScoreSum += entry.driftScore;

    for (const d of entry.topDomains) {
      domainMap.set(d.domain, (domainMap.get(d.domain) ?? 0) + d.timeMs);
    }

    // Group by day for best/worst
    const dayKey = new Date(entry.startTime).toDateString();
    const prev = dayMap.get(dayKey) ?? { driftScore: 0, count: 0, totalMs: 0 };
    dayMap.set(dayKey, {
      driftScore: prev.driftScore + entry.driftScore,
      count: prev.count + 1,
      totalMs: prev.totalMs + entry.totalActiveTimeMs,
    });
  }

  const topDomains = [...domainMap.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([domain, timeMs]) => ({ domain, timeMs }));

  // Weekly trend (4 weeks)
  const weeklyTrend: MonthlyReport["weeklyTrend"] = [];
  for (let i = 3; i >= 0; i--) {
    const weekStart = now - (i + 1) * SEVEN_DAYS_MS;
    const weekEnd = now - i * SEVEN_DAYS_MS;
    const weekEntries = recent.filter((e) => e.endTime >= weekStart && e.endTime < weekEnd);
    if (weekEntries.length > 0) {
      const avgDrift = Math.round(
        weekEntries.reduce((sum, e) => sum + e.driftScore, 0) / weekEntries.length
      );
      const totalMs = weekEntries.reduce((sum, e) => sum + e.totalActiveTimeMs, 0);
      weeklyTrend.push({ weekStart, driftScore: avgDrift, totalMs });
    }
  }

  // Best/worst days
  let bestDay: MonthlyReport["bestDay"] = null;
  let worstDay: MonthlyReport["worstDay"] = null;
  for (const [dayStr, data] of dayMap) {
    const avgScore = Math.round(data.driftScore / data.count);
    const date = new Date(dayStr).getTime();
    if (!bestDay || avgScore < bestDay.driftScore) {
      bestDay = { date, driftScore: avgScore };
    }
    if (!worstDay || avgScore > worstDay.driftScore) {
      worstDay = { date, driftScore: avgScore };
    }
  }

  // Daily average
  const activeDays = dayMap.size || 1;
  const dailyAverageMs = Math.round(totalTimeMs / activeDays);

  return {
    periodStart,
    periodEnd: now,
    sessionCount: recent.length,
    totalTimeMs,
    productiveTimeMs,
    neutralTimeMs,
    distractionTimeMs,
    averageDriftScore: Math.round(driftScoreSum / recent.length),
    topDomains,
    weeklyTrend,
    dailyAverageMs,
    bestDay,
    worstDay,
  };
}
