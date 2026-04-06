// ---------------------------------------------------------------------------
// Drift – Settings Page
// ---------------------------------------------------------------------------

import "./theme.css";
import "./settings.css";
import { loadSettings, saveSettings, DriftSettings } from "../extension/storage";
import { getProductiveDomains, getDistractionDomains } from "../core/classify";
import { icons } from "./icon";
import { Category } from "../core/types";

let settings: DriftSettings;
const app = () => document.getElementById("app")!;

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

function esc(s: string): string {
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

async function addDomainOverride(): Promise<void> {
  const input = document.getElementById("new-domain") as HTMLInputElement;
  const select = document.getElementById("new-category") as HTMLSelectElement;
  const domain = input.value.trim().toLowerCase().replace(/^https?:\/\//, "").replace(/^www\./, "").replace(/\/.*$/, "");
  if (!domain) return;

  const category = select.value as Category;
  settings.domainOverrides[domain] = category;
  await saveSettings(settings);
  input.value = "";
  render();
}

async function removeDomainOverride(domain: string): Promise<void> {
  delete settings.domainOverrides[domain];
  await saveSettings(settings);
  render();
}

async function updateSensitivity(value: string): Promise<void> {
  settings.sensitivity = value as DriftSettings["sensitivity"];
  await saveSettings(settings);
}

async function updateNotifications(enabled: boolean): Promise<void> {
  settings.notifications = enabled;
  await saveSettings(settings);
}

async function updateDailyGoal(value: number): Promise<void> {
  settings.dailyGoalMaxDrift = value;
  await saveSettings(settings);
  const label = document.getElementById("goal-label");
  if (label) label.textContent = `${value}%`;
}

function positionSensitivityIndicator(): void {
  const row = document.getElementById("sensitivity-row");
  const indicator = document.getElementById("sensitivity-indicator");
  const activeBtn = row?.querySelector(".sensitivity-btn.active") as HTMLElement | null;
  if (!row || !indicator || !activeBtn) return;
  const rowRect = row.getBoundingClientRect();
  const btnRect = activeBtn.getBoundingClientRect();
  indicator.style.width = `${btnRect.width}px`;
  indicator.style.transform = `translateX(${btnRect.left - rowRect.left}px)`;
}

function render(): void {
  const isDark = getTheme() === "dark";
  const overrideEntries = Object.entries(settings.domainOverrides);

  app().innerHTML = `
    <div class="settings-page">
      <div class="settings-hdr">
        <a href="dashboard.html" class="settings-back">${icons.arrowLeft(14)} Back</a>
        <span class="settings-logo">settings</span>
        <button class="icon-btn" id="btn-theme">${isDark ? icons.moon(16) : icons.sun(16)}</button>
      </div>

      <div class="settings-section">
        <div class="settings-section-title">Domain Classification</div>
        <div class="settings-section-desc">Override how sites are categorized. Your overrides take priority over defaults.</div>

        <div class="domain-add-row">
          <input type="text" id="new-domain" class="domain-input" placeholder="e.g. youtube.com" />
          <select id="new-category" class="domain-select">
            <option value="productive">Productive</option>
            <option value="distraction">Distraction</option>
            <option value="neutral">Neutral</option>
          </select>
          <button class="domain-add-btn" id="btn-add-domain">Add</button>
        </div>

        ${overrideEntries.length > 0 ? `
          <div class="domain-list">
            ${overrideEntries.map(([domain, cat]) => `
              <div class="domain-override-row">
                <span class="domain-override-dot ${cat}"></span>
                <span class="domain-override-name">${esc(domain)}</span>
                <span class="domain-override-cat">${cat}</span>
                <button class="domain-remove-btn" data-domain="${esc(domain)}">${icons.trash(14)}</button>
              </div>
            `).join("")}
          </div>
        ` : '<div class="settings-empty">No custom overrides yet.</div>'}
      </div>

      <div class="settings-section">
        <div class="settings-section-title">Drift Sensitivity</div>
        <div class="settings-section-desc">Controls how aggressively drift is detected.</div>
        <div class="sensitivity-row" id="sensitivity-row">
          <div class="sensitivity-indicator" id="sensitivity-indicator"></div>
          ${["low", "medium", "high"].map((level) => `
            <button class="sensitivity-btn ${settings.sensitivity === level ? "active" : ""}" data-level="${level}">
              ${level.charAt(0).toUpperCase() + level.slice(1)}
            </button>
          `).join("")}
        </div>
      </div>

      <div class="settings-section">
        <div class="settings-section-title">Daily Goal</div>
        <div class="settings-section-desc">Stay under this drift percentage to maintain your streak.</div>
        <div class="goal-row">
          <input type="range" id="goal-slider" class="goal-slider" min="10" max="60" step="5" value="${settings.dailyGoalMaxDrift}" />
          <span class="goal-value" id="goal-label">${settings.dailyGoalMaxDrift}%</span>
        </div>
      </div>

      <div class="settings-section">
        <div class="settings-section-title">Notifications</div>
        <div class="toggle-row">
          <span>Drift alerts</span>
          <label class="toggle">
            <input type="checkbox" id="notif-toggle" ${settings.notifications ? "checked" : ""} />
            <span class="toggle-slider"></span>
          </label>
        </div>
      </div>

      <div class="settings-footer">
        <a href="dashboard.html">Dashboard</a>
        <a href="privacy.html" target="_blank">Privacy</a>
      </div>
    </div>
  `;

  // Position sensitivity indicator
  positionSensitivityIndicator();

  // Bind events
  document.getElementById("btn-theme")?.addEventListener("click", toggleTheme);
  document.getElementById("btn-add-domain")?.addEventListener("click", addDomainOverride);
  document.getElementById("new-domain")?.addEventListener("keydown", (e) => {
    if ((e as KeyboardEvent).key === "Enter") addDomainOverride();
  });
  document.querySelectorAll(".domain-remove-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const domain = (btn as HTMLElement).dataset.domain;
      if (domain) removeDomainOverride(domain);
    });
  });
  document.querySelectorAll(".sensitivity-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const level = (btn as HTMLElement).dataset.level!;
      updateSensitivity(level);
      // Update active states without full re-render for smooth animation
      document.querySelectorAll(".sensitivity-btn").forEach((b) => {
        b.classList.toggle("active", (b as HTMLElement).dataset.level === level);
      });
      requestAnimationFrame(positionSensitivityIndicator);
    });
  });
  document.getElementById("goal-slider")?.addEventListener("input", (e) => {
    updateDailyGoal(Number((e.target as HTMLInputElement).value));
  });
  document.getElementById("notif-toggle")?.addEventListener("change", (e) => {
    updateNotifications((e.target as HTMLInputElement).checked);
  });
}

document.addEventListener("DOMContentLoaded", async () => {
  initTheme();
  settings = await loadSettings();
  render();
});
