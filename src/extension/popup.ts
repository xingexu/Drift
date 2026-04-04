// ---------------------------------------------------------------------------
// Drift – Popup
// ---------------------------------------------------------------------------

import "../ui/theme.css";
import "../ui/popup.css";
import { BrowsingEvent, BrowsingSession } from "../core/types";
import { processPipeline, exportSession } from "../core/pipeline";
import { allMockEvents } from "../mocks/sessions";
import { loadEvents, saveEvents, clearAll } from "./storage";
import { driftLogo, icons } from "../ui/icon";

let sessions: BrowsingSession[] = [];
const root = () => document.getElementById("popup-root")!;

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

function esc(s: string): string {
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

function getTheme(): string {
  return document.documentElement.getAttribute("data-theme") || "dark";
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

function render(): void {
  const latest = sessions[sessions.length - 1];
  const isDark = getTheme() === "dark";

  root().innerHTML = `
    <div class="popup">
      <div class="popup-header">
        <div class="popup-logo">${driftLogo(16)}</div>
        <div class="popup-right">
          <div class="tracking-pill">
            <span class="tracking-dot"></span>
            Active
          </div>
          <button class="icon-btn" id="btn-theme" title="Toggle theme">
            ${isDark ? icons.sun(16) : icons.moon(16)}
          </button>
        </div>
      </div>

      ${latest ? renderSession(latest) : renderEmpty()}

      <a class="cta-btn" href="dashboard.html" target="_blank">
        <span class="cta-icon">${icons.layers(16)}</span>
        Open session report
      </a>

      <div class="popup-footer">
        <button class="footer-btn" id="btn-demo">${icons.download(14)} Demo</button>
        <button class="footer-btn" id="btn-clear">${icons.trash(14)} Clear</button>
      </div>
    </div>
  `;

  document.getElementById("btn-theme")?.addEventListener("click", toggleTheme);
  document.getElementById("btn-demo")?.addEventListener("click", loadMock);
  document.getElementById("btn-clear")?.addEventListener("click", doClear);
}

function renderSession(session: BrowsingSession): string {
  const exp = exportSession(session);
  const { summary } = exp;
  const firstDrift = session.driftPoints[0];
  const driftAfter = firstDrift ? fmtMs(firstDrift.timestamp - session.startTime) : null;
  const total = summary.productiveTimeMs + summary.neutralTimeMs + summary.distractionTimeMs;
  const pPct = total ? (summary.productiveTimeMs / total) * 100 : 0;
  const dPct = total ? (summary.distractionTimeMs / total) * 100 : 0;

  let detail = `${fmtMs(session.totalDurationMs)} total`;
  if (summary.productiveTimeMs > 0) detail += `, ${fmtMs(summary.productiveTimeMs)} focused`;
  if (driftAfter) detail += ` \u2014 drifted after ${driftAfter}`;
  if (summary.entryDomain !== summary.exitDomain) detail += `. Ended on ${esc(summary.exitDomain)}`;

  const labelClass = summary.driftScore < 20 ? "good" : summary.driftScore > 50 ? "bad" : "muted";

  return `
    <div class="session-card fade-in">
      <div class="card-eyebrow">
        <span class="icon-inline">${icons.clock(14)}</span>
        Latest session \u00b7 ${fmtTime(session.startTime)}
      </div>
      <div class="card-domain">${esc(summary.entryDomain)}</div>
      <div class="card-detail">${detail}</div>
      <div class="badges">
        <span class="badge badge-${labelClass}">${summary.summaryLabel}</span>
        ${session.driftPoints.length > 0
          ? `<span class="badge badge-bad">${icons.alertCircle(12)} ${session.driftPoints.length} drift${session.driftPoints.length !== 1 ? "s" : ""}</span>`
          : ""}
      </div>
      <div class="progress-bar">
        <div class="seg seg-productive" style="width:${pPct}%"></div>
        <div class="seg seg-distraction" style="width:${dPct}%"></div>
      </div>
    </div>

    <div class="stats-row fade-in">
      <div class="stat">
        <div class="stat-icon">${icons.layers(16)}</div>
        <div class="stat-num">${session.events.length}</div>
        <div class="stat-label">Events</div>
      </div>
      <div class="stat green">
        <div class="stat-icon">${icons.target(16)}</div>
        <div class="stat-num">${fmtMs(summary.productiveTimeMs)}</div>
        <div class="stat-label">Focus</div>
      </div>
      <div class="stat red">
        <div class="stat-icon">${icons.trendingDown(16)}</div>
        <div class="stat-num">${summary.driftScore}%</div>
        <div class="stat-label">Drift</div>
      </div>
      <div class="stat">
        <div class="stat-icon">${icons.globe(16)}</div>
        <div class="stat-num">${session.stats.uniqueDomains}</div>
        <div class="stat-label">Sites</div>
      </div>
    </div>
  `;
}

function renderEmpty(): string {
  return `
    <div class="empty fade-in">
      <div class="empty-icon">${icons.activity(32)}</div>
      <h3>No sessions yet</h3>
      <p>Browse the web to start tracking, or load demo data to preview.</p>
      <button class="empty-btn" id="btn-demo-empty">Load demo data</button>
    </div>
  `;
}

async function processData(): Promise<void> {
  const events = await loadEvents();
  sessions = events.length > 0 ? processPipeline(events).sessions : [];
  render();
  document.getElementById("btn-demo-empty")?.addEventListener("click", loadMock);
}

async function loadMock(): Promise<void> {
  const events = JSON.parse(JSON.stringify(allMockEvents)) as BrowsingEvent[];
  await saveEvents(events);
  sessions = processPipeline(events).sessions;
  render();
}

async function doClear(): Promise<void> {
  await clearAll();
  sessions = [];
  render();
}

document.addEventListener("DOMContentLoaded", () => {
  initTheme();
  processData();
});
