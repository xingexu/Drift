// ---------------------------------------------------------------------------
// Drift – Dashboard
// ---------------------------------------------------------------------------

import "./theme.css";
import "./dashboard.css";
import { BrowsingEvent, BrowsingSession } from "../core/types";
import { processPipeline, exportSession } from "../core/pipeline";
import { allMockEvents } from "../mocks/sessions";
import { loadEvents, saveEvents, clearAll } from "../extension/storage";
import { driftLogo, icons } from "./icon";

let sessions: BrowsingSession[] = [];
let currentIdx = 0;

const app = () => document.getElementById("app")!;

function fmtMs(ms: number): string {
  const s = Math.round(ms / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m`;
  return `${Math.floor(m / 60)}h ${m % 60}m`;
}

function fmtTime(ts: number): string {
  return new Date(ts).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function fmtDate(ts: number): string {
  return new Date(ts).toLocaleDateString([], { month: "short", day: "numeric" });
}

function esc(s: string): string {
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

function initTheme(): void {
  const saved = localStorage.getItem("drift_theme");
  if (saved) document.documentElement.setAttribute("data-theme", saved);
}

function toggleTheme(): void {
  const current = document.documentElement.getAttribute("data-theme") || "dark";
  const next = current === "dark" ? "light" : "dark";
  document.documentElement.setAttribute("data-theme", next);
  localStorage.setItem("drift_theme", next);
  render();
}

// ---------------------------------------------------------------------------
// Section renderers
// ---------------------------------------------------------------------------

function renderTopbar(): string {
  const options = sessions
    .map((s, i) => {
      const entry = s.events[0];
      const label = `${fmtDate(s.startTime)} ${fmtTime(s.startTime)} \u2014 ${esc(entry?.domain ?? "?")}`;
      return `<option value="${i}" ${i === currentIdx ? "selected" : ""}>${label}</option>`;
    })
    .join("");

  const isDark = (document.documentElement.getAttribute("data-theme") || "dark") === "dark";

  return `
    <div class="topbar fade-in">
      <div class="topbar-left">${driftLogo(18)}</div>
      <div class="topbar-right">
        <select class="session-select" id="session-select">${options}</select>
        <button class="icon-btn" id="btn-theme" title="Toggle theme">${isDark ? icons.sun(16) : icons.moon(16)}</button>
        <button class="icon-btn" id="btn-export" title="Export">${icons.download(16)}</button>
      </div>
    </div>
  `;
}

function renderOverview(session: BrowsingSession): string {
  const s = session.stats;
  const total = s.productiveTimeMs + s.neutralTimeMs + s.distractionTimeMs;
  const pPct = total ? Math.round((s.productiveTimeMs / total) * 100) : 0;

  return `
    <div class="overview-grid fade-in">
      <div class="overview-cell">
        <div class="ov-label">Duration</div>
        <div class="ov-value">${fmtMs(session.totalDurationMs)}</div>
        <div class="ov-sub">${session.events.length} events</div>
      </div>
      <div class="overview-cell productive">
        <div class="ov-label">Focused</div>
        <div class="ov-value">${fmtMs(s.productiveTimeMs)}</div>
        <div class="ov-sub">${pPct}% of session</div>
      </div>
      <div class="overview-cell distraction">
        <div class="ov-label">Drifted</div>
        <div class="ov-value">${fmtMs(s.distractionTimeMs)}</div>
        <div class="ov-sub">${session.driftPoints.length} break${session.driftPoints.length !== 1 ? "s" : ""}</div>
      </div>
      <div class="overview-cell">
        <div class="ov-label">Drift Score</div>
        <div class="ov-value">${session.driftScore}%</div>
        <div class="ov-sub">${s.uniqueDomains} sites</div>
      </div>
    </div>
  `;
}

function renderHeadline(session: BrowsingSession): string {
  const exp = exportSession(session);
  const { summary } = exp;
  const firstDrift = session.driftPoints[0];
  const driftAfter = firstDrift ? fmtMs(firstDrift.timestamp - session.startTime) : null;
  const total = summary.productiveTimeMs + summary.neutralTimeMs + summary.distractionTimeMs;
  const pPct = total ? (summary.productiveTimeMs / total) * 100 : 0;
  const dPct = total ? (summary.distractionTimeMs / total) * 100 : 0;

  let detailParts: string[] = [];
  if (driftAfter) detailParts.push(`Drifted after ${driftAfter}.`);
  else detailParts.push("No drift detected.");
  if (summary.entryDomain !== summary.exitDomain) detailParts.push(`Ended on ${esc(summary.exitDomain)}.`);

  return `
    <div class="session-headline fade-in">
      <h1>Started on ${esc(summary.entryDomain)}</h1>
      <p class="headline-detail">${detailParts.join(" ")}</p>
      <div class="headline-meta">
        ${fmtTime(session.startTime)} \u2013 ${fmtTime(session.endTime)}
        &nbsp;/&nbsp; ${fmtMs(session.totalDurationMs)}
        &nbsp;/&nbsp; ${session.events.length} events
        &nbsp;/&nbsp; drift ${summary.driftScore}%
      </div>
      <div class="headline-bar">
        <div class="seg seg-productive" style="width:${pPct}%"></div>
        <div class="seg seg-distraction" style="width:${dPct}%"></div>
      </div>
    </div>
  `;
}

function renderPath(session: BrowsingSession): string {
  const rows = session.events
    .map((e) => {
      const cat = e.category ?? "neutral";
      return `
        <li class="path-row cat-${cat}">
          <span class="path-time">${fmtTime(e.startTime)}</span>
          <span class="path-domain">${esc(e.domain)}</span>
          ${e.title ? `<span class="path-title">${esc(e.title)}</span>` : ""}
          ${e.drift ? '<span class="drift-tag">drift</span>' : ""}
          <span class="path-duration">${fmtMs(e.durationMs)}</span>
        </li>`;
    })
    .join("");

  return `
    <div class="session-path fade-in">
      <div class="section-label">Path</div>
      <ul class="path-list">${rows}</ul>
    </div>
  `;
}

function renderDriftBreakpoints(session: BrowsingSession): string {
  const inner =
    session.driftPoints.length === 0
      ? '<div class="no-drift">No drift detected in this session.</div>'
      : session.driftPoints
          .map(
            (dp) => `
        <div class="drift-item">
          <div class="drift-time">${fmtTime(dp.timestamp)}</div>
          <div class="drift-reason">${esc(dp.reason)}</div>
          <span class="drift-trigger">${dp.trigger}</span>
        </div>`,
          )
          .join("");

  return `
    <div class="drift-breakpoints fade-in">
      <div class="section-label">Drift breakpoints</div>
      <div class="drift-card">${inner}</div>
    </div>
  `;
}

function renderEvidence(session: BrowsingSession): string {
  const rows = session.events
    .map((e) => {
      const cat = e.category ?? "neutral";
      return `
        <tr class="${e.drift ? "drift-row" : ""}">
          <td class="col-time">${fmtTime(e.startTime)}</td>
          <td class="col-domain">${esc(e.domain)}</td>
          <td class="col-title">${e.title ? esc(e.title) : "\u2014"}</td>
          <td class="col-duration">${fmtMs(e.durationMs)}</td>
          <td class="col-category ${cat}">${cat}</td>
        </tr>`;
    })
    .join("");

  return `
    <div class="session-evidence fade-in">
      <div class="section-label">Evidence</div>
      <div class="evidence-wrap">
        <table class="evidence-table">
          <thead><tr><th>Time</th><th>Domain</th><th>Title</th><th>Duration</th><th>Category</th></tr></thead>
          <tbody>${rows}</tbody>
        </table>
      </div>
    </div>
  `;
}

function renderSettings(): string {
  return `
    <div class="settings-section fade-in">
      <div class="section-label">Settings</div>
      <div class="settings-actions">
        <button id="btn-demo">${icons.download(14)} Load demo data</button>
        <button class="danger" id="btn-clear">${icons.trash(14)} Clear all data</button>
        <a href="privacy.html" target="_blank">${icons.shield(14)} Privacy</a>
      </div>
    </div>
  `;
}

// ---------------------------------------------------------------------------
// Main render
// ---------------------------------------------------------------------------

function render(): void {
  if (sessions.length === 0) {
    app().innerHTML = `
      <div class="dashboard">
        <div class="topbar fade-in">
          <div class="topbar-left">${driftLogo(18)}</div>
          <div class="topbar-right">
            <button class="icon-btn" id="btn-theme" title="Toggle theme">${(document.documentElement.getAttribute("data-theme") || "dark") === "dark" ? icons.sun(16) : icons.moon(16)}</button>
          </div>
        </div>
        <div class="dash-empty fade-in">
          <div class="empty-icon" style="display:flex;justify-content:center;color:var(--text-muted);margin-bottom:16px">${icons.activity(40)}</div>
          <h2>No sessions recorded</h2>
          <p>Start browsing and come back to see how your attention moved, or load demo data to preview.</p>
          <button id="btn-demo-empty">Load demo data</button>
        </div>
      </div>
    `;
    document.getElementById("btn-demo-empty")?.addEventListener("click", loadMock);
    document.getElementById("btn-theme")?.addEventListener("click", toggleTheme);
    return;
  }

  const session = sessions[currentIdx];
  if (!session) return;

  app().innerHTML = `
    <div class="dashboard">
      ${renderTopbar()}
      ${renderOverview(session)}
      ${renderHeadline(session)}
      ${renderPath(session)}
      ${renderDriftBreakpoints(session)}
      ${renderEvidence(session)}
      ${renderSettings()}
    </div>
  `;

  document.getElementById("session-select")?.addEventListener("change", (e) => {
    currentIdx = parseInt((e.target as HTMLSelectElement).value, 10);
    render();
  });
  document.getElementById("btn-theme")?.addEventListener("click", toggleTheme);
  document.getElementById("btn-export")?.addEventListener("click", doExport);
  document.getElementById("btn-demo")?.addEventListener("click", loadMock);
  document.getElementById("btn-clear")?.addEventListener("click", doClear);
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

async function loadMock(): Promise<void> {
  const events = JSON.parse(JSON.stringify(allMockEvents)) as BrowsingEvent[];
  await saveEvents(events);
  sessions = processPipeline(events).sessions;
  currentIdx = sessions.length - 1;
  render();
}

async function doExport(): Promise<void> {
  if (sessions.length === 0) return;
  const exported = sessions.map(exportSession);
  const blob = new Blob([JSON.stringify(exported, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `drift-export-${Date.now()}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

async function doClear(): Promise<void> {
  await clearAll();
  sessions = [];
  currentIdx = 0;
  render();
}

document.addEventListener("DOMContentLoaded", () => {
  initTheme();
  processData();
});
