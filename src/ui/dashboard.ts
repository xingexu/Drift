// ---------------------------------------------------------------------------
// Drift – Dashboard
// ---------------------------------------------------------------------------

import "./theme.css";
import "./dashboard.css";
import { BrowsingSession, SessionHistoryEntry, WeeklyReport, MonthlyReport } from "../core/types";
import { processPipeline, exportSession } from "../core/pipeline";
import { buildHistoryEntry, computeWeeklyReport, computeMonthlyReport } from "../core/history";
import {
  loadEvents,
  clearAll,
  clearCurrentSession,
  appendSessionToHistory,
  loadSessionHistory,
  loadSessionHistoryMerged,
  loadTrackingState,
  setTrackingState,
  runInitialSync,
} from "../extension/storage";
import {
  getSession,
  signOut as supabaseSignOut,
  onAuthStateChange,
  getSupabase,
} from "../extension/supabase";
import { icons } from "./icon";
import { renderSparkline, renderStreakCalendar } from "./charts";
import { generateInsights } from "../core/insights";
import { loadGoals, GoalData } from "../extension/storage";

let sessions: BrowsingSession[] = [];
let currentIdx = 0;
let tracking = true;
let historyEntries: SessionHistoryEntry[] = [];
let weeklyReport: WeeklyReport | null = null;
let monthlyReport: MonthlyReport | null = null;
let activeTab: "session" | "weekly" | "monthly" = "session";
let isTransitioning = false;
let isAuthenticated = false;
let userEmail: string | null = null;
let goalData: GoalData = { streak: 0, lastDate: "", history: [] };
const app = () => document.getElementById("app")!;

// ---------------------------------------------------------------------------
// Tracking toggle
// ---------------------------------------------------------------------------

async function toggleTracking(): Promise<void> {
  if (!tracking) {
    // Starting a new session — clear current data (preserves history)
    await clearCurrentSession();
    sessions = [];
    currentIdx = 0;
    tracking = true;
    await setTrackingState(true);
    render();
  } else {
    // Ending session — save to history, then show final results
    tracking = false;
    await setTrackingState(false);
    const events = await loadEvents();
    if (events.length > 0) {
      const { sessions: processed } = processPipeline(events);
      for (const session of processed) {
        await appendSessionToHistory(buildHistoryEntry(session), session);
      }
    }
    // Reload history + reports (merged with remote if authenticated)
    historyEntries = await loadSessionHistoryMerged();
    weeklyReport = computeWeeklyReport(historyEntries);
    monthlyReport = computeMonthlyReport(historyEntries);
    await processData();
  }
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

function fmtMs(ms: number): string {
  const totalSec = Math.round(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  const pad = (n: number) => String(n).padStart(2, "0");
  if (h > 0) return `${h}:${pad(m)}:${pad(s)}`;
  return `${m}:${pad(s)}`;
}

function fmtTime(ts: number): string {
  return new Date(ts).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function fmtDate(ts: number): string {
  return new Date(ts).toLocaleDateString([], { month: "short", day: "numeric" });
}

function driftColor(score: number): string {
  // 0% = green, 50% = amber, 100% = red
  if (score <= 25) return "var(--color-productive)";
  if (score <= 50) return "#b8860b";
  if (score <= 75) return "#d4730d";
  return "var(--color-distraction)";
}

function esc(s: string): string {
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

function getTheme(): string {
  return document.documentElement.getAttribute("data-theme") || "light";
}

function initTheme(): void {
  const saved = localStorage.getItem("drift_theme");
  if (saved) document.documentElement.setAttribute("data-theme", saved);
}

function toggleTheme(): void {
  const next = getTheme() === "dark" ? "light" : "dark";
  document.documentElement.setAttribute("data-theme", next);
  localStorage.setItem("drift_theme", next);
  render();
}

// ---------------------------------------------------------------------------
// UI Components
// ---------------------------------------------------------------------------

function renderShimmer(): string {
  return `
    <div class="shimmer-block">
      <div class="shimmer-line lg"></div>
      <div class="shimmer-line md"></div>
      <div class="shimmer-line bar"></div>
      <div class="shimmer-metrics">
        <div class="shimmer-metric"><div class="shimmer-line"></div><div class="shimmer-line"></div></div>
        <div class="shimmer-metric"><div class="shimmer-line"></div><div class="shimmer-line"></div></div>
        <div class="shimmer-metric"><div class="shimmer-line"></div><div class="shimmer-line"></div></div>
        <div class="shimmer-metric"><div class="shimmer-line"></div><div class="shimmer-line"></div></div>
      </div>
      <div class="shimmer-rows">
        <div class="shimmer-row"><div class="shimmer-line"></div><div class="shimmer-line"></div><div class="shimmer-line"></div></div>
        <div class="shimmer-row"><div class="shimmer-line"></div><div class="shimmer-line"></div><div class="shimmer-line"></div></div>
        <div class="shimmer-row"><div class="shimmer-line"></div><div class="shimmer-line"></div><div class="shimmer-line"></div></div>
        <div class="shimmer-row"><div class="shimmer-line"></div><div class="shimmer-line"></div><div class="shimmer-line"></div></div>
        <div class="shimmer-row"><div class="shimmer-line"></div><div class="shimmer-line"></div><div class="shimmer-line"></div></div>
        <div class="shimmer-row"><div class="shimmer-line"></div><div class="shimmer-line"></div><div class="shimmer-line"></div></div>
      </div>
    </div>
  `;
}

function trackingBtn(): string {
  return tracking
    ? `<button class="track-btn active" id="btn-track"><span class="track-dot"></span>End session</button>`
    : `<button class="track-btn" id="btn-track">Start session</button>`;
}

function renderTabs(): string {
  const tabIndex = activeTab === "session" ? 0 : activeTab === "weekly" ? 1 : 2;
  return `
    <div class="dash-tabs" id="dash-tabs">
      <div class="dash-tab-indicator" id="tab-indicator"></div>
      <button class="dash-tab ${activeTab === "session" ? "active" : ""}" data-tab="session">Session</button>
      <button class="dash-tab ${activeTab === "weekly" ? "active" : ""}" data-tab="weekly">Weekly</button>
      <button class="dash-tab ${activeTab === "monthly" ? "active" : ""}" data-tab="monthly">Monthly</button>
    </div>
  `;
}

function positionTabIndicator(): void {
  const tabs = document.getElementById("dash-tabs");
  const indicator = document.getElementById("tab-indicator");
  const activeBtn = tabs?.querySelector(".dash-tab.active") as HTMLElement | null;
  if (!tabs || !indicator || !activeBtn) return;
  const tabsRect = tabs.getBoundingClientRect();
  const btnRect = activeBtn.getBoundingClientRect();
  indicator.style.width = `${btnRect.width}px`;
  indicator.style.transform = `translateX(${btnRect.left - tabsRect.left}px)`;
}

function renderReportCard(report: WeeklyReport | MonthlyReport, label: string): string {
  const total = report.productiveTimeMs + report.neutralTimeMs + report.distractionTimeMs;
  const barTotal = report.productiveTimeMs + report.distractionTimeMs;
  const pPct = barTotal ? (report.productiveTimeMs / barTotal) * 100 : 50;
  const dPct = barTotal ? (report.distractionTimeMs / barTotal) * 100 : 50;
  const maxDomain = report.topDomains[0]?.timeMs ?? 1;

  const isMonthly = "weeklyTrend" in report;
  const monthly = isMonthly ? (report as MonthlyReport) : null;

  return `
    <div class="report-card">
      <div class="report-header">
        <div>
          <div class="report-big">${fmtMs(report.totalTimeMs)}</div>
          <div class="report-sub">${report.sessionCount} session${report.sessionCount !== 1 ? "s" : ""} ${label}</div>
        </div>
        <div class="report-score" style="border-color: ${driftColor(report.averageDriftScore)}20; background: ${driftColor(report.averageDriftScore)}0d">
          <div class="report-score-num" style="color:${driftColor(report.averageDriftScore)}">${report.averageDriftScore}%</div>
          <div class="report-score-label">drift</div>
        </div>
      </div>

      <div class="dash-bar" style="margin-bottom:20px">
        <div class="focused" style="width:${pPct}%"></div>
        <div class="drifted" style="width:${dPct}%"></div>
      </div>

      <div class="dash-metrics" style="margin-bottom:20px">
        <div class="dash-metric">
          <div class="dm-num green">${fmtMs(report.productiveTimeMs)}</div>
          <div class="dm-label">Focused</div>
        </div>
        <div class="dash-metric">
          <div class="dm-num red">${fmtMs(report.distractionTimeMs)}</div>
          <div class="dm-label">Drifted</div>
        </div>
        <div class="dash-metric">
          <div class="dm-num">${report.averageDriftScore}%</div>
          <div class="dm-label">Avg drift</div>
        </div>
        ${monthly ? `
          <div class="dash-metric">
            <div class="dm-num">${fmtMs(monthly.dailyAverageMs)}</div>
            <div class="dm-label">Daily avg</div>
          </div>
        ` : ""}
      </div>

      ${monthly && (monthly.bestDay || monthly.worstDay) ? `
        <div class="insight-row">
          ${monthly.bestDay ? `<div class="insight-card good"><div class="insight-label">Best day</div><div class="insight-val">${fmtDate(monthly.bestDay.date)}</div><div class="insight-detail">${monthly.bestDay.driftScore}% drift</div></div>` : ""}
          ${monthly.worstDay ? `<div class="insight-card bad"><div class="insight-label">Worst day</div><div class="insight-val">${fmtDate(monthly.worstDay.date)}</div><div class="insight-detail">${monthly.worstDay.driftScore}% drift</div></div>` : ""}
        </div>
      ` : ""}

      ${monthly && monthly.weeklyTrend.length >= 2 ? `
        <div class="sec" style="margin-top:20px">
          <div class="sec-title">Drift trend</div>
          ${renderSparkline(
            monthly.weeklyTrend.map((w, i) => ({
              label: `W${i + 1}`,
              value: w.driftScore,
            })),
            undefined,
            64,
          )}
        </div>
      ` : ""}

      <div class="sec" style="margin-top:20px">
        <div class="sec-title">Top sites</div>
        ${report.topDomains.slice(0, 5).map((d) => {
          const barPct = Math.round((d.timeMs / maxDomain) * 100);
          return `
          <div class="weekly-domain">
            <span class="weekly-domain-name">${esc(d.domain)}</span>
            <div class="weekly-domain-bar"><div class="weekly-domain-bar-fill" style="width:${barPct}%"></div></div>
            <span class="weekly-domain-time">${fmtMs(d.timeMs)}</span>
          </div>`;
        }).join("")}
      </div>
    </div>
  `;
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

function renderSessionTab(): string {
  if (sessions.length === 0) {
    return `<div class="dash-empty">${tracking ? "Session active. Browse the web and come back." : "Start a session to begin tracking."}</div>`;
  }

  const session = sessions[currentIdx];
  if (!session) return "";

  const { summary } = exportSession(session);
  const total = summary.productiveTimeMs + summary.neutralTimeMs + summary.distractionTimeMs;
  const barTotal = summary.productiveTimeMs + summary.distractionTimeMs;
  const pPct = barTotal ? (summary.productiveTimeMs / barTotal) * 100 : 50;
  const dPct = barTotal ? (summary.distractionTimeMs / barTotal) * 100 : 50;

  const firstDrift = session.driftPoints[0];
  const driftAfter = firstDrift ? fmtMs(firstDrift.timestamp - session.startTime) : null;

  const anchorDomain = session.stats.mostVisitedDomain || summary.entryDomain;
  let subtext = `<strong>${esc(anchorDomain)}</strong>`;
  if (driftAfter) subtext += ` \u00b7 drifted after ${driftAfter}`;
  if (anchorDomain !== summary.exitDomain) subtext += ` \u00b7 ended on ${esc(summary.exitDomain)}`;

  return `
    <div class="dash-hero">
      <div class="dash-hero-time">${fmtMs(total)}</div>
      <div class="dash-hero-sub">${subtext}</div>
    </div>

    <div class="dash-bar">
      <div class="focused" style="width:${pPct}%"></div>
      <div class="drifted" style="width:${dPct}%"></div>
    </div>

    <div class="dash-metrics">
      <div class="dash-metric">
        <div class="dm-num green">${fmtMs(summary.productiveTimeMs)}</div>
        <div class="dm-label">Focused</div>
      </div>
      <div class="dash-metric">
        <div class="dm-num red">${fmtMs(summary.distractionTimeMs)}</div>
        <div class="dm-label">Drifted</div>
      </div>
      <div class="dash-metric">
        <div class="dm-num" style="color:${driftColor(summary.driftScore)}">${summary.driftScore}%</div>
        <div class="dm-label">Drift</div>
      </div>
      <div class="dash-metric">
        <div class="dm-num">${session.stats.uniqueDomains}</div>
        <div class="dm-label">Sites</div>
      </div>
    </div>

    <div class="sec">
      <div class="sec-title">Path</div>
      ${[...session.events].reverse().map((e, i) => {
        const cat = e.category ?? "neutral";
        const delay = Math.min(i * 0.03, 0.6);
        return `
          <div class="path-row" style="animation-delay:${delay}s">
            <div class="pr-indicator ${cat}"></div>
            <span class="pr-time">${fmtTime(e.startTime)}</span>
            <span class="pr-domain">${esc(e.domain)}</span>
            ${e.drift ? '<span class="pr-drift">drift</span>' : ""}
            <span class="pr-detail">${fmtMs(e.durationMs)}</span>
          </div>`;
      }).join("")}
    </div>

    ${session.driftPoints.length > 0 ? `
      <div class="sec">
        <div class="sec-title">Drift breakpoints</div>
        ${session.driftPoints.map((dp) => `
          <div class="drift-item">
            <div class="di-text">${esc(dp.reason)}</div>
            <div class="di-meta">${fmtTime(dp.timestamp)} \u00b7 <span class="trigger">${dp.trigger}</span></div>
          </div>
        `).join("")}
      </div>
    ` : ""}
  `;
}

function renderHistorySection(): string {
  if (historyEntries.length === 0) return "";
  return `
    <div class="sec">
      <div class="sec-title">Recent sessions</div>
      ${[...historyEntries].reverse().slice(0, 10).map((h, i) => `
        <div class="history-row" style="animation-delay:${0.05 + i * 0.04}s">
          <span class="history-date">${fmtDate(h.startTime)}</span>
          <span class="history-domain">${esc(h.entryDomain)}</span>
          <span class="history-score dm-num" style="color:${driftColor(h.driftScore)}">${h.driftScore}%</span>
          <span class="history-time">${fmtMs(h.totalActiveTimeMs)}</span>
        </div>
      `).join("")}
    </div>
  `;
}

function renderInsightsSection(): string {
  const insights = generateInsights(historyEntries);
  if (insights.length === 0) return "";

  return `
    <div class="sec insights-section">
      <div class="sec-title">Insights</div>
      ${insights.map((insight) => {
        const colorClass = insight.type === "positive" ? "good" : insight.type === "negative" ? "bad" : "";
        return `
          <div class="insight-item ${colorClass}">
            <div class="insight-item-title">${esc(insight.title)}</div>
            <div class="insight-item-detail">${esc(insight.detail)}</div>
          </div>
        `;
      }).join("")}
    </div>
  `;
}

function renderGoalSection(): string {
  if (goalData.history.length === 0 && goalData.streak === 0) return "";
  return renderStreakCalendar(goalData.history, goalData.streak);
}

function getTabContent(): string {
  if (activeTab === "session") {
    return renderSessionTab() + renderGoalSection() + renderHistorySection();
  } else if (activeTab === "weekly") {
    let content = renderInsightsSection();
    content += weeklyReport
      ? renderReportCard(weeklyReport, "this week")
      : '<div class="dash-empty">No data this week yet. Complete a session first.</div>';
    content += renderHistorySection();
    return content;
  } else {
    let content = renderInsightsSection();
    content += monthlyReport
      ? renderReportCard(monthlyReport, "this month")
      : '<div class="dash-empty">No data this month yet. Complete a session first.</div>';
    content += renderHistorySection();
    return content;
  }
}

function switchTab(newTab: typeof activeTab): void {
  if (newTab === activeTab || isTransitioning) return;
  isTransitioning = true;

  const contentEl = document.getElementById("tab-content");
  if (!contentEl) {
    activeTab = newTab;
    isTransitioning = false;
    render();
    return;
  }

  // Phase 1: fade out current content
  contentEl.classList.add("exit");
  contentEl.classList.remove("tab-content");

  setTimeout(() => {
    // Phase 2: show shimmer loading state
    activeTab = newTab;
    // Update active tab button styles + slide indicator
    document.querySelectorAll(".dash-tab").forEach((btn) => {
      const tab = (btn as HTMLElement).dataset.tab;
      btn.classList.toggle("active", tab === activeTab);
    });
    requestAnimationFrame(positionTabIndicator);
    contentEl.classList.remove("exit");
    contentEl.innerHTML = renderShimmer();

    setTimeout(() => {
      // Phase 3: fade out shimmer, then fade in real content
      contentEl.style.opacity = "0";
      contentEl.style.transform = "translateY(4px)";

      setTimeout(() => {
        contentEl.innerHTML = getTabContent();
        contentEl.classList.add("tab-content");
        contentEl.style.opacity = "";
        contentEl.style.transform = "";
        isTransitioning = false;
        bindTabContentEvents();
      }, 120);
    }, 450);
  }, 180);
}

function bindTabContentEvents(): void {
  // Re-bind any events inside tab content if needed
}

function render(): void {
  const tabContent = getTabContent();

  app().innerHTML = `
    <div class="dashboard">
      <div class="dash-hdr">
        <span class="dash-logo">drift</span>
        <div class="dash-controls">
          ${isAuthenticated
            ? `<button class="icon-btn dash-auth-btn" id="btn-signout" title="Sign out (${esc(userEmail ?? "")})">${icons.user(16)}</button>`
            : ""}
          ${trackingBtn()}
          <button class="icon-btn" id="btn-theme">${getTheme() === "dark" ? icons.moon(16) : icons.sun(16)}</button>
          ${sessions.length > 0 ? `<button class="icon-btn" id="btn-export">${icons.download(16)}</button>` : ""}
        </div>
      </div>

      ${renderTabs()}

      <div id="tab-content" class="tab-content">
        ${tabContent}
      </div>

      <div class="dash-footer">
        <button id="btn-clear">Clear all data</button>
        <a href="settings.html">Settings</a>
        <a href="privacy.html" target="_blank">Privacy</a>
      </div>
    </div>
  `;

  bindCommonEvents();
  document.getElementById("btn-export")?.addEventListener("click", doExport);

  // Tab click handlers
  document.querySelectorAll(".dash-tab").forEach((btn) => {
    btn.addEventListener("click", () => {
      switchTab((btn as HTMLElement).dataset.tab as typeof activeTab);
    });
  });

  // Position the sliding tab indicator after layout
  requestAnimationFrame(positionTabIndicator);
}

// ---------------------------------------------------------------------------
// Event binding (shared between empty & session views)
// ---------------------------------------------------------------------------

function bindCommonEvents(): void {
  document.getElementById("btn-track")?.addEventListener("click", toggleTracking);
  document.getElementById("btn-theme")?.addEventListener("click", toggleTheme);
  document.getElementById("btn-clear")?.addEventListener("click", doClear);
  document.getElementById("btn-signout")?.addEventListener("click", async () => {
    await supabaseSignOut();
    isAuthenticated = false;
    userEmail = null;
    render();
  });
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

async function processData(): Promise<void> {
  const events = await loadEvents();
  sessions = events.length > 0 ? processPipeline(events).sessions : [];
  currentIdx = sessions.length > 0 ? sessions.length - 1 : 0;
  render();
}

async function doExport(): Promise<void> {
  if (sessions.length === 0) return;
  const exported = sessions.map(exportSession);
  const blob = new Blob([JSON.stringify(exported, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `drift-${Date.now()}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

async function doClear(): Promise<void> {
  if (!confirm("Clear all session data? This cannot be undone.")) return;
  await clearAll();
  sessions = [];
  currentIdx = 0;
  historyEntries = [];
  weeklyReport = null;
  monthlyReport = null;
  render();
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

document.addEventListener("DOMContentLoaded", async () => {
  initTheme();

  // Handle OAuth / magic link redirect (hash contains access_token or error)
  const hash = window.location.hash;
  if (hash.includes("access_token") || hash.includes("refresh_token")) {
    // Supabase client with detectSessionInUrl:true auto-parses the hash
    // Give it a moment to process, then clean the URL
    await getSupabase().auth.getSession();
    // Clean up the URL hash so tokens aren't visible
    history.replaceState(null, "", window.location.pathname);
  } else if (hash.includes("error")) {
    const hashParams = new URLSearchParams(hash.substring(1));
    const errorDesc = hashParams.get("error_description");
    if (errorDesc) {
      console.warn("[Drift] OAuth error:", errorDesc);
    }
    history.replaceState(null, "", window.location.pathname);
  }

  // Check auth state
  const session = await getSession();
  isAuthenticated = !!session;
  userEmail = session?.user?.email ?? null;

  // Run initial sync on first login
  if (isAuthenticated) {
    await runInitialSync();
  }

  // Listen for auth changes
  onAuthStateChange(async (_event, s) => {
    isAuthenticated = !!s;
    userEmail = s?.user?.email ?? null;
    if (isAuthenticated) {
      await runInitialSync();
      historyEntries = await loadSessionHistoryMerged();
      weeklyReport = computeWeeklyReport(historyEntries);
      monthlyReport = computeMonthlyReport(historyEntries);
    }
    render();
  });

  tracking = await loadTrackingState();
  goalData = await loadGoals();
  // Use merged history (local + remote) if authenticated
  historyEntries = await loadSessionHistoryMerged();
  weeklyReport = computeWeeklyReport(historyEntries);
  monthlyReport = computeMonthlyReport(historyEntries);
  processData();
});
