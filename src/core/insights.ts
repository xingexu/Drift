// ---------------------------------------------------------------------------
// Drift -- Smart Insights (pattern detection from session history)
// ---------------------------------------------------------------------------

import { SessionHistoryEntry } from "./types";

/** A single actionable insight derived from session history patterns. */
export interface Insight {
  /** Icon name used by the UI (e.g. "trending-down", "clock"). */
  icon: string;
  /** Short headline (< 50 chars). */
  title: string;
  /** Explanatory detail string shown below the title. */
  detail: string;
  /** Sentiment: positive is encouraging, negative is a warning. */
  type: "positive" | "negative" | "neutral";
  /** Sorting priority (higher = more important, shown first). */
  priority: number;
}

/** Seven days in milliseconds. */
const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;

/** Thirty days in milliseconds. */
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Format an hour range as a human-readable string.
 *
 * Correctly handles 12-hour clock edge cases (0 -> 12AM, 12 -> 12PM,
 * 24 -> 12AM wrap).
 *
 * @param startHour - The starting hour (0-23).
 * @param endHour   - The ending hour (can be 24 for midnight wrap).
 * @returns A string like "2PM-4PM" or "10AM-12PM".
 */
function formatHourRange(startHour: number, endHour: number): string {
  const fmt = (h: number): string => {
    const wrapped = h % 24;
    const display = wrapped % 12 || 12;
    const suffix = wrapped < 12 ? "AM" : "PM";
    return `${display}${suffix}`;
  };
  return `${fmt(startHour)}-${fmt(endHour)}`;
}

/**
 * Generate actionable insights from session history entries.
 *
 * Analyses patterns across recent sessions and returns the top insights
 * sorted by priority.  Each insight type has independent eligibility
 * criteria (minimum data requirements, significance thresholds).
 *
 * Insight types:
 * 1. **Week-over-week drift trend** -- compares this week's average drift to last week's.
 * 2. **Top distraction domain** -- identifies the single domain consuming the most time.
 * 3. **Peak drift time of day** -- finds the 2-hour window with the highest average drift.
 * 4. **Worst day of week** -- finds the weekday with the highest average drift over 30 days.
 * 5. **Productive streak** -- congratulates low-drift runs.
 * 6. **App-switching frequency** -- warns when sessions have very high event counts (rapid switching).
 * 7. **Focus session duration trend** -- compares average productive time this week vs last week.
 * 8. **Productivity by time of day** -- finds the most productive 2-hour window.
 * 9. **Session length correlation** -- detects whether longer sessions tend to drift more.
 *
 * @param entries - Session history entries, typically spanning several weeks.
 * @returns Up to 5 insights sorted by priority (highest first).
 */
export function generateInsights(entries: SessionHistoryEntry[]): Insight[] {
  if (entries.length < 2) return [];

  const insights: Insight[] = [];
  const now = Date.now();

  const thisWeek = entries.filter((e) => e.endTime >= now - SEVEN_DAYS_MS);
  const lastWeek = entries.filter(
    (e) => e.endTime >= now - 2 * SEVEN_DAYS_MS && e.endTime < now - SEVEN_DAYS_MS,
  );
  const recentMonth = entries.filter((e) => e.endTime >= now - THIRTY_DAYS_MS);

  // --- 1. Week-over-week drift trend ---
  if (thisWeek.length > 0 && lastWeek.length > 0) {
    const thisAvg = thisWeek.reduce((s, e) => s + e.driftScore, 0) / thisWeek.length;
    const lastAvg = lastWeek.reduce((s, e) => s + e.driftScore, 0) / lastWeek.length;
    const diff = Math.round(thisAvg - lastAvg);

    if (Math.abs(diff) >= 5) {
      if (diff < 0) {
        insights.push({
          icon: "trending-down",
          title: "Drift is dropping",
          detail: `Your average drift is ${Math.abs(diff)}% lower than last week. Keep it up.`,
          type: "positive",
          priority: 90,
        });
      } else {
        insights.push({
          icon: "trending-up",
          title: "Drift is climbing",
          detail: `Your average drift is ${diff}% higher than last week.`,
          type: "negative",
          priority: 85,
        });
      }
    }
  }

  // --- 2. Top distraction domain ---
  if (thisWeek.length > 0) {
    const domainTime = new Map<string, number>();
    for (const e of thisWeek) {
      for (const d of e.topDomains) {
        domainTime.set(d.domain, (domainTime.get(d.domain) ?? 0) + d.timeMs);
      }
    }
    const totalDistraction = thisWeek.reduce((s, e) => s + e.distractionTimeMs, 0);
    if (totalDistraction > 60_000) {
      let topDomain = "";
      let topTime = 0;
      for (const [domain, time] of domainTime) {
        if (time > topTime) {
          topTime = time;
          topDomain = domain;
        }
      }
      if (topDomain) {
        const totalTime = thisWeek.reduce((s, e) => s + e.totalActiveTimeMs, 0);
        const pct = totalTime > 0 ? Math.round((topTime / totalTime) * 100) : 0;
        if (pct >= 15) {
          insights.push({
            icon: "alert",
            title: `${topDomain} dominates`,
            detail: `${topDomain} accounts for ${pct}% of your browsing time this week.`,
            type: "negative",
            priority: 80,
          });
        }
      }
    }
  }

  // --- 3. Peak drift time of day ---
  if (thisWeek.length >= 3) {
    const hourBuckets = new Map<number, { drift: number; count: number }>();
    for (const e of thisWeek) {
      const hour = new Date(e.startTime).getHours();
      const bucket = Math.floor(hour / 2) * 2; // 2-hour windows
      const prev = hourBuckets.get(bucket) ?? { drift: 0, count: 0 };
      hourBuckets.set(bucket, {
        drift: prev.drift + e.driftScore,
        count: prev.count + 1,
      });
    }
    let worstHour = -1;
    let worstAvg = 0;
    for (const [hour, data] of hourBuckets) {
      const avg = data.drift / data.count;
      if (avg > worstAvg && data.count >= 2) {
        worstAvg = avg;
        worstHour = hour;
      }
    }
    if (worstHour >= 0 && worstAvg > 30) {
      const label = formatHourRange(worstHour, worstHour + 2);
      insights.push({
        icon: "clock",
        title: "Peak drift window",
        detail: `You drift most between ${label} (avg ${Math.round(worstAvg)}% drift).`,
        type: "neutral",
        priority: 70,
      });
    }
  }

  // --- 4. Worst day of week ---
  if (recentMonth.length >= 7) {
    const dayBuckets = new Map<number, { drift: number; count: number }>();
    for (const e of recentMonth) {
      const day = new Date(e.startTime).getDay();
      const prev = dayBuckets.get(day) ?? { drift: 0, count: 0 };
      dayBuckets.set(day, {
        drift: prev.drift + e.driftScore,
        count: prev.count + 1,
      });
    }
    let worstDay = -1;
    let worstDayAvg = 0;
    const dayNames = [
      "Sundays", "Mondays", "Tuesdays", "Wednesdays",
      "Thursdays", "Fridays", "Saturdays",
    ];
    for (const [day, data] of dayBuckets) {
      const avg = data.drift / data.count;
      if (avg > worstDayAvg && data.count >= 2) {
        worstDayAvg = avg;
        worstDay = day;
      }
    }
    if (worstDay >= 0 && worstDayAvg > 25) {
      insights.push({
        icon: "calendar",
        title: `${dayNames[worstDay]} are rough`,
        detail: `Your average drift on ${dayNames[worstDay]} is ${Math.round(worstDayAvg)}%.`,
        type: "neutral",
        priority: 60,
      });
    }
  }

  // --- 5. Productive streak ---
  if (thisWeek.length > 0) {
    const lowDriftSessions = thisWeek.filter((e) => e.driftScore <= 25).length;
    if (lowDriftSessions >= 3) {
      insights.push({
        icon: "zap",
        title: "On a roll",
        detail: `${lowDriftSessions} of your sessions this week had under 25% drift.`,
        type: "positive",
        priority: 75,
      });
    }
  }

  // --- 6. App-switching frequency (high event count per unit time) ---
  if (thisWeek.length >= 2) {
    const switchRates: number[] = [];
    for (const e of thisWeek) {
      const durationMin = e.totalActiveTimeMs / 60_000;
      if (durationMin >= 5) {
        switchRates.push(e.eventCount / durationMin);
      }
    }
    if (switchRates.length >= 2) {
      const avgRate =
        switchRates.reduce((a, b) => a + b, 0) / switchRates.length;
      if (avgRate >= 3) {
        insights.push({
          icon: "shuffle",
          title: "Frequent switching",
          detail: `You average ${avgRate.toFixed(1)} page switches per minute. Try longer focus blocks.`,
          type: "negative",
          priority: 65,
        });
      }
    }
  }

  // --- 7. Focus session duration trend (productive time this week vs last) ---
  if (thisWeek.length > 0 && lastWeek.length > 0) {
    const thisAvgProductive =
      thisWeek.reduce((s, e) => s + e.productiveTimeMs, 0) / thisWeek.length;
    const lastAvgProductive =
      lastWeek.reduce((s, e) => s + e.productiveTimeMs, 0) / lastWeek.length;

    if (lastAvgProductive > 0) {
      const pctChange = Math.round(
        ((thisAvgProductive - lastAvgProductive) / lastAvgProductive) * 100,
      );
      if (pctChange >= 20) {
        insights.push({
          icon: "target",
          title: "Longer focus sessions",
          detail: `Your average productive time per session is up ${pctChange}% vs last week.`,
          type: "positive",
          priority: 72,
        });
      } else if (pctChange <= -20) {
        insights.push({
          icon: "target",
          title: "Shorter focus sessions",
          detail: `Your average productive time per session is down ${Math.abs(pctChange)}% vs last week.`,
          type: "negative",
          priority: 68,
        });
      }
    }
  }

  // --- 8. Productivity by time of day (best window) ---
  if (thisWeek.length >= 3) {
    const hourBuckets = new Map<number, { productiveMs: number; totalMs: number; count: number }>();
    for (const e of thisWeek) {
      const hour = new Date(e.startTime).getHours();
      const bucket = Math.floor(hour / 2) * 2;
      const prev = hourBuckets.get(bucket) ?? { productiveMs: 0, totalMs: 0, count: 0 };
      hourBuckets.set(bucket, {
        productiveMs: prev.productiveMs + e.productiveTimeMs,
        totalMs: prev.totalMs + e.totalActiveTimeMs,
        count: prev.count + 1,
      });
    }
    let bestHour = -1;
    let bestRatio = 0;
    for (const [hour, data] of hourBuckets) {
      if (data.count >= 2 && data.totalMs > 0) {
        const ratio = data.productiveMs / data.totalMs;
        if (ratio > bestRatio) {
          bestRatio = ratio;
          bestHour = hour;
        }
      }
    }
    if (bestHour >= 0 && bestRatio >= 0.6) {
      const label = formatHourRange(bestHour, bestHour + 2);
      insights.push({
        icon: "sun",
        title: "Peak productivity window",
        detail: `You're most productive between ${label} (${Math.round(bestRatio * 100)}% focus).`,
        type: "positive",
        priority: 66,
      });
    }
  }

  // --- 9. Session length correlation with drift ---
  if (recentMonth.length >= 5) {
    const longSessions = recentMonth.filter((e) => e.totalActiveTimeMs >= 30 * 60_000);
    const shortSessions = recentMonth.filter(
      (e) => e.totalActiveTimeMs >= 5 * 60_000 && e.totalActiveTimeMs < 30 * 60_000,
    );
    if (longSessions.length >= 3 && shortSessions.length >= 3) {
      const longAvgDrift =
        longSessions.reduce((s, e) => s + e.driftScore, 0) / longSessions.length;
      const shortAvgDrift =
        shortSessions.reduce((s, e) => s + e.driftScore, 0) / shortSessions.length;
      const diff = Math.round(longAvgDrift - shortAvgDrift);
      if (diff >= 15) {
        insights.push({
          icon: "hourglass",
          title: "Longer sessions drift more",
          detail: `Sessions over 30 min average ${Math.round(longAvgDrift)}% drift vs ${Math.round(shortAvgDrift)}% for shorter ones.`,
          type: "neutral",
          priority: 55,
        });
      }
    }
  }

  // Sort by priority and return top 5
  return insights.sort((a, b) => b.priority - a.priority).slice(0, 5);
}
