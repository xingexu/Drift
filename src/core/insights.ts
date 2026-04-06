// ---------------------------------------------------------------------------
// Drift – Smart Insights (pattern detection from session history)
// ---------------------------------------------------------------------------

import { SessionHistoryEntry } from "./types";

export interface Insight {
  icon: string;
  title: string;
  detail: string;
  type: "positive" | "negative" | "neutral";
  priority: number; // higher = more important
}

/**
 * Generate actionable insights from session history entries.
 * Returns top 3 insights, sorted by priority.
 */
export function generateInsights(entries: SessionHistoryEntry[]): Insight[] {
  if (entries.length < 2) return [];

  const insights: Insight[] = [];
  const now = Date.now();
  const SEVEN_DAYS = 7 * 24 * 60 * 60 * 1000;

  const thisWeek = entries.filter((e) => e.endTime >= now - SEVEN_DAYS);
  const lastWeek = entries.filter(
    (e) => e.endTime >= now - 2 * SEVEN_DAYS && e.endTime < now - SEVEN_DAYS
  );

  // --- Insight: Week-over-week trend ---
  if (thisWeek.length > 0 && lastWeek.length > 0) {
    const thisAvg = Math.round(
      thisWeek.reduce((s, e) => s + e.driftScore, 0) / thisWeek.length
    );
    const lastAvg = Math.round(
      lastWeek.reduce((s, e) => s + e.driftScore, 0) / lastWeek.length
    );
    const diff = thisAvg - lastAvg;

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

  // --- Insight: Top distraction domain ---
  if (thisWeek.length > 0) {
    const domainTime = new Map<string, number>();
    for (const e of thisWeek) {
      for (const d of e.topDomains) {
        domainTime.set(d.domain, (domainTime.get(d.domain) ?? 0) + d.timeMs);
      }
    }
    const totalDistraction = thisWeek.reduce((s, e) => s + e.distractionTimeMs, 0);
    if (totalDistraction > 60000) {
      // Find domain with most distraction-correlated time
      const sorted = [...domainTime.entries()].sort((a, b) => b[1] - a[1]);
      const top = sorted[0];
      if (top) {
        const totalTime = thisWeek.reduce((s, e) => s + e.totalActiveTimeMs, 0);
        const pct = Math.round((top[1] / totalTime) * 100);
        if (pct >= 15) {
          insights.push({
            icon: "alert",
            title: `${top[0]} dominates`,
            detail: `${top[0]} accounts for ${pct}% of your browsing time this week.`,
            type: "negative",
            priority: 80,
          });
        }
      }
    }
  }

  // --- Insight: Peak drift time of day ---
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
      const label = `${worstHour % 12 || 12}${worstHour < 12 ? "AM" : "PM"}-${(worstHour + 2) % 12 || 12}${worstHour + 2 < 12 ? "AM" : "PM"}`;
      insights.push({
        icon: "clock",
        title: "Peak drift window",
        detail: `You drift most between ${label} (avg ${Math.round(worstAvg)}% drift).`,
        type: "neutral",
        priority: 70,
      });
    }
  }

  // --- Insight: Worst day of week ---
  if (entries.length >= 7) {
    const dayBuckets = new Map<number, { drift: number; count: number }>();
    const recentEntries = entries.filter((e) => e.endTime >= now - 30 * 24 * 60 * 60 * 1000);
    for (const e of recentEntries) {
      const day = new Date(e.startTime).getDay();
      const prev = dayBuckets.get(day) ?? { drift: 0, count: 0 };
      dayBuckets.set(day, {
        drift: prev.drift + e.driftScore,
        count: prev.count + 1,
      });
    }
    let worstDay = -1;
    let worstDayAvg = 0;
    const dayNames = ["Sundays", "Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays"];
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

  // --- Insight: Productive streak ---
  if (thisWeek.length > 0) {
    const lowDriftDays = thisWeek.filter((e) => e.driftScore <= 25).length;
    if (lowDriftDays >= 3) {
      insights.push({
        icon: "zap",
        title: "On a roll",
        detail: `${lowDriftDays} of your sessions this week had under 25% drift.`,
        type: "positive",
        priority: 75,
      });
    }
  }

  // Sort by priority and return top 3
  return insights.sort((a, b) => b.priority - a.priority).slice(0, 3);
}
