// ---------------------------------------------------------------------------
// Drift – Dashboard
// ---------------------------------------------------------------------------

import "./theme.css";
import "./dashboard.css";
import { BrowsingSession } from "../core/types";
import { processPipeline, exportSession } from "../core/pipeline";
import { loadEvents, clearAll } from "../extension/storage";
import { icons } from "./icon";

let sessions: BrowsingSession[] = [];
let currentIdx = 0;

const app = () => document.getElementById("app")!;

function fmtMs(ms: number): string {
  const s = Math.round(ms / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m`;
  return `${Math.floor(m / 60)}h${m % 60 > 0 ? ` ${m % 60}m` : ""}`;
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

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

function render(): void {
  if (sessions.length === 0) {
    app().innerHTML = `
      <div class="dashboard">
        <div class="dash-hdr">
          <span class="dash-logo">drift</span>
          <div class="dash-controls">
            <button class="icon-btn" id="btn-theme">${getTheme() === "dark" ? icons.sun(16) : icons.moon(16)}</button>
          </div>
        </div>
        <div class="dash-empty">Tracking active. Browse the web and come back.</div>
      </div>
    `;
    document.getElementById("btn-theme")?.addEventListener("click", toggleTheme);
    return;
  }

  const session = sessions[currentIdx];
  if (!session) return;

  const { summary } = exportSession(session);
  const total = summary.productiveTimeMs + summary.neutralTimeMs + summary.distractionTimeMs;
  const pPct = total ? (summary.productiveTimeMs / total) * 100 : 0;
  const dPct = total ? (summary.distractionTimeMs / total) * 100 : 0;

  const options = sessions
    .map((s, i) => {
      const entry = s.events[0];
      return `<option value="${i}" ${i === currentIdx ? "selected" : ""}>${fmtDate(s.startTime)} ${fmtTime(s.startTime)} \u2014 ${esc(entry?.domain ?? "?")}</option>`;
    })
    .join("");

  const firstDrift = session.driftPoints[0];
  const driftAfter = firstDrift ? fmtMs(firstDrift.timestamp - session.startTime) : null;

  let subtext = `<strong>${esc(summary.entryDomain)}</strong>`;
  if (driftAfter) subtext += ` \u00b7 drifted after ${driftAfter}`;
  if (summary.entryDomain !== summary.exitDomain) subtext += ` \u00b7 ended on ${esc(summary.exitDomain)}`;

  app().innerHTML = `
    <div class="dashboard">
      <div class="dash-hdr">
        <span class="dash-logo">drift</span>
        <div class="dash-controls">
          <select class="dash-select" id="session-select">${options}</select>
          <button class="icon-btn" id="btn-theme">${getTheme() === "dark" ? icons.sun(16) : icons.moon(16)}</button>
          <button class="icon-btn" id="btn-export">${icons.download(16)}</button>
        </div>
      </div>

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
          <div class="dm-num">${summary.driftScore}%</div>
          <div class="dm-label">Drift score</div>
        </div>
        <div class="dash-metric">
          <div class="dm-num">${session.stats.uniqueDomains}</div>
          <div class="dm-label">Sites</div>
        </div>
      </div>

      <div class="sec">
        <div class="sec-title">Path</div>
        ${session.events.map((e) => {
          const cat = e.category ?? "neutral";
          return `
            <div class="path-row">
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

      <div class="sec">
        <div class="sec-title">Events</div>
        <table class="ev-table">
          <thead><tr><th>Time</th><th>Domain</th><th>Title</th><th>Duration</th><th>Category</th></tr></thead>
          <tbody>
            ${session.events.map((e) => `
              <tr>
                <td class="t-time">${fmtTime(e.startTime)}</td>
                <td class="t-domain">${esc(e.domain)}</td>
                <td class="t-title">${e.title ? esc(e.title) : "\u2014"}</td>
                <td class="t-dur">${fmtMs(e.durationMs)}</td>
                <td class="t-cat ${e.category ?? "neutral"}">${e.category ?? "neutral"}</td>
              </tr>
            `).join("")}
          </tbody>
        </table>
      </div>

      <div class="dash-footer">
        <button id="btn-clear">Clear data</button>
        <a href="privacy.html" target="_blank">Privacy</a>
      </div>
    </div>
  `;

  document.getElementById("session-select")?.addEventListener("change", (e) => {
    currentIdx = parseInt((e.target as HTMLSelectElement).value, 10);
    render();
  });
  document.getElementById("btn-theme")?.addEventListener("click", toggleTheme);
  document.getElementById("btn-export")?.addEventListener("click", doExport);
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
  await clearAll();
  sessions = [];
  currentIdx = 0;
  render();
}

document.addEventListener("DOMContentLoaded", () => {
  initTheme();
  processData();
});
