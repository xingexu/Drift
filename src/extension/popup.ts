// ---------------------------------------------------------------------------
// Drift – Popup
// ---------------------------------------------------------------------------

import "../ui/theme.css";
import "../ui/popup.css";
import { BrowsingSession } from "../core/types";
import { processPipeline, exportSession } from "../core/pipeline";
import { loadEvents } from "./storage";
import { icons } from "../ui/icon";

let sessions: BrowsingSession[] = [];
const root = () => document.getElementById("popup-root")!;

function fmtMs(ms: number): string {
  const s = Math.round(ms / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m`;
  return `${Math.floor(m / 60)}h${m % 60 > 0 ? ` ${m % 60}m` : ""}`;
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
      <div class="hdr">
        <span class="hdr-logo">drift</span>
        <div class="hdr-right">
          <span class="hdr-dot"></span>
          <button class="hdr-btn" id="btn-theme">${isDark ? icons.sun(15) : icons.moon(15)}</button>
        </div>
      </div>
      ${latest ? renderSession(latest) : '<div class="empty">Tracking active. Browse the web and check back here.</div>'}
      <a class="report-link" href="dashboard.html" target="_blank">View full report</a>
    </div>
  `;

  document.getElementById("btn-theme")?.addEventListener("click", toggleTheme);
}

function renderSession(session: BrowsingSession): string {
  const { summary } = exportSession(session);
  const total = summary.productiveTimeMs + summary.neutralTimeMs + summary.distractionTimeMs;
  const pPct = total ? (summary.productiveTimeMs / total) * 100 : 0;
  const dPct = total ? (summary.distractionTimeMs / total) * 100 : 0;

  // Top domains by time
  const domainMap = new Map<string, number>();
  for (const e of session.events) {
    domainMap.set(e.domain, (domainMap.get(e.domain) ?? 0) + e.durationMs);
  }
  const topDomains = [...domainMap.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 4);

  return `
    <div class="hero">
      <div class="hero-time">${fmtMs(total)}</div>
      <div class="hero-sub">${esc(summary.entryDomain)} · ${session.events.length} pages</div>
    </div>

    <div class="ratio-bar">
      <div class="focused" style="width:${pPct}%"></div>
      <div class="drifted" style="width:${dPct}%"></div>
    </div>

    <div class="metrics">
      <div class="metric">
        <div class="metric-num green">${fmtMs(summary.productiveTimeMs)}</div>
        <div class="metric-label">Focused</div>
      </div>
      <div class="metric">
        <div class="metric-num red">${fmtMs(summary.distractionTimeMs)}</div>
        <div class="metric-label">Drifted</div>
      </div>
      <div class="metric">
        <div class="metric-num">${summary.driftScore}%</div>
        <div class="metric-label">Drift</div>
      </div>
      <div class="metric">
        <div class="metric-num">${session.driftPoints.length}</div>
        <div class="metric-label">Breaks</div>
      </div>
    </div>

    ${topDomains.map(([domain, ms]) => `
      <div class="domain-row">
        <span class="domain-name">${esc(domain)}</span>
        <span class="domain-time">${fmtMs(ms)}</span>
      </div>
    `).join("")}
  `;
}

async function processData(): Promise<void> {
  const events = await loadEvents();
  sessions = events.length > 0 ? processPipeline(events).sessions : [];
  render();
}

document.addEventListener("DOMContentLoaded", () => {
  initTheme();
  processData();
});
