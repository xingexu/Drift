// ---------------------------------------------------------------------------
// Drift – Popup
// ---------------------------------------------------------------------------

import "../ui/theme.css";
import "../ui/popup.css";
import { BrowsingSession } from "../core/types";
import { processPipeline, exportSession } from "../core/pipeline";
import { buildHistoryEntry } from "../core/history";
import {
  loadEvents,
  clearCurrentSession,
  appendSessionToHistory,
  setTrackingState,
  loadTrackingState,
} from "./storage";
import {
  getSession,
  signInWithGoogle,
  signInWithMagicLink,
  signOut,
  onAuthStateChange,
} from "./supabase";
import { icons } from "../ui/icon";

let sessions: BrowsingSession[] = [];
let tracking = true;
let isAuthenticated = false;
let userEmail: string | null = null;
let authLoading = false;
let magicLinkSent = false;
let loginSkipped = false;
let showLoginOverlay = false;
let authError: string | null = null;
const root = () => document.getElementById("popup-root")!;

function fmtMs(ms: number): string {
  const totalSec = Math.round(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  const pad = (n: number) => String(n).padStart(2, "0");
  if (h > 0) return `${h}:${pad(m)}:${pad(s)}`;
  return `${m}:${pad(s)}`;
}

function esc(s: string): string {
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

function driftColor(score: number): string {
  if (score <= 25) return "var(--color-productive)";
  if (score <= 50) return "#b8860b";
  if (score <= 75) return "#d4730d";
  return "var(--color-distraction)";
}

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
// Toggle session: end current or start new
// ---------------------------------------------------------------------------

async function toggleSession(): Promise<void> {
  if (tracking) {
    // End session — save to history, stop tracking
    const events = await loadEvents();
    if (events.length > 0) {
      const { sessions: processed } = processPipeline(events);
      for (const session of processed) {
        // Pass full session for Supabase sync
        await appendSessionToHistory(buildHistoryEntry(session), session);
      }
    }
    await setTrackingState(false);
    tracking = false;
    await processData();
  } else {
    // Start new session — clear old data, begin tracking
    await clearCurrentSession();
    await setTrackingState(true);
    tracking = true;
    sessions = [];
    render();
  }
}

// ---------------------------------------------------------------------------
// Auth actions
// ---------------------------------------------------------------------------

async function handleGoogleSignIn(): Promise<void> {
  authLoading = true;
  authError = null;
  render();

  try {
    const { error } = await signInWithGoogle();
    authLoading = false;

    if (error) {
      // Show the error but don't loop — stay on the login view
      authError = error.message || "Google sign-in failed. Try magic link instead.";
      render();
      return;
    }

    // Re-check auth state after successful sign-in
    await checkAuth();
    if (isAuthenticated) {
      showLoginOverlay = false;
      loginSkipped = true;
      authError = null;
    } else {
      // Sign-in returned no error but we're still not authenticated
      // This means redirect flow was used — page will reload with tokens
      // Don't re-render to login view, just wait for the redirect
      authError = null;
    }
    render();
  } catch (err) {
    authLoading = false;
    authError = "Something went wrong. Try again or use magic link.";
    render();
  }
}

async function handleMagicLink(): Promise<void> {
  const input = document.getElementById("magic-email") as HTMLInputElement | null;
  const email = input?.value?.trim();
  if (!email) {
    authError = "Please enter your email address.";
    render();
    return;
  }

  authLoading = true;
  authError = null;
  render();
  const { error } = await signInWithMagicLink(email);
  authLoading = false;

  if (error) {
    authError = "Failed to send magic link. Try again.";
  } else {
    magicLinkSent = true;
    authError = null;
  }
  render();
}

async function handleSignOut(): Promise<void> {
  await signOut();
  isAuthenticated = false;
  userEmail = null;
  render();
}

async function checkAuth(): Promise<void> {
  const session = await getSession();
  isAuthenticated = !!session;
  userEmail = session?.user?.email ?? null;
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

function renderLoginView(): string {
  if (magicLinkSent) {
    return `
      <div class="auth-card">
        <div class="auth-title">Check your email</div>
        <div class="auth-subtitle">We sent a sign-in link. Click it to continue.</div>
        <button class="auth-back-btn" id="btn-auth-back">Back</button>
      </div>
    `;
  }

  return `
    <div class="auth-card">
      <div class="auth-title">Sign in to sync</div>
      <div class="auth-subtitle">Back up your data and access it anywhere.</div>
      ${authError ? `<div class="auth-error">${esc(authError)}</div>` : ""}
      <button class="auth-google-btn" id="btn-google" ${authLoading ? "disabled" : ""}>
        ${authLoading ? '<span class="auth-loading-spinner"></span>Signing in...' : '<svg width="16" height="16" viewBox="0 0 24 24" style="margin-right:8px;vertical-align:middle"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>Continue with Google'}
      </button>
      <div class="auth-divider"><span>or</span></div>
      <div class="auth-email-row">
        <input type="email" id="magic-email" class="auth-email-input" placeholder="your@email.com" />
        <button class="auth-email-btn" id="btn-magic" ${authLoading ? "disabled" : ""}>Send link</button>
      </div>
      <button class="auth-skip-btn" id="btn-skip">Skip for now</button>
    </div>
  `;
}

function render(): void {
  const latest = sessions[sessions.length - 1];
  const isDark = getTheme() === "dark";

  // Show login on first open (no session, not tracking, not skipped) OR when overlay triggered
  const showLogin = showLoginOverlay || (!isAuthenticated && sessions.length === 0 && !tracking && !loginSkipped);

  root().innerHTML = `
    <div class="popup">
      <div class="hdr">
        <span class="hdr-logo">drift</span>
        <div class="hdr-right">
          ${tracking ? '<span class="hdr-dot"></span>' : ""}
          ${isAuthenticated ? `<button class="hdr-btn hdr-auth-btn" id="btn-signout" title="Sign out (${esc(userEmail ?? "")})">${icons.user(15)}</button>` : ""}
          <button class="hdr-btn" id="btn-theme">${isDark ? icons.moon(15) : icons.sun(15)}</button>
        </div>
      </div>
      ${showLogin ? renderLoginView() : ""}
      ${!showLogin && latest ? renderSession(latest) : ""}
      ${!showLogin && !latest ? `<div class="empty">${tracking ? "Session active.<br>Browse the web and check back." : "No active session.<br>Start one to begin tracking."}</div>` : ""}
      ${!showLogin ? `
        <div class="popup-actions">
          <button class="new-session-btn ${tracking ? "active" : ""}" id="btn-new-session">${tracking ? "End session" : "New session"}</button>
          ${latest ? '<a class="report-link-small" href="dashboard.html" target="_blank">View report</a>' : ""}
        </div>
      ` : ""}
      ${!isAuthenticated && !showLogin ? '<div class="auth-inline"><button class="auth-inline-btn" id="btn-signin-inline">Sign in to sync</button></div>' : ""}
    </div>
  `;

  // Bind events
  document.getElementById("btn-theme")?.addEventListener("click", toggleTheme);
  document.getElementById("btn-new-session")?.addEventListener("click", toggleSession);
  document.getElementById("btn-signout")?.addEventListener("click", handleSignOut);
  document.getElementById("btn-google")?.addEventListener("click", handleGoogleSignIn);
  document.getElementById("btn-magic")?.addEventListener("click", handleMagicLink);
  document.getElementById("btn-skip")?.addEventListener("click", () => {
    loginSkipped = true;
    showLoginOverlay = false;
    authError = null;
    render();
  });
  document.getElementById("btn-auth-back")?.addEventListener("click", () => {
    magicLinkSent = false;
    authError = null;
    render();
  });
  document.getElementById("btn-signin-inline")?.addEventListener("click", () => {
    showLoginOverlay = true;
    magicLinkSent = false;
    authError = null;
    render();
  });

  // Handle enter key on email input
  document.getElementById("magic-email")?.addEventListener("keydown", (e) => {
    if ((e as KeyboardEvent).key === "Enter") handleMagicLink();
  });
}

function renderSession(session: BrowsingSession): string {
  const { summary } = exportSession(session);
  const total = summary.productiveTimeMs + summary.neutralTimeMs + summary.distractionTimeMs;
  const barTotal = summary.productiveTimeMs + summary.distractionTimeMs;
  const pPct = barTotal ? (summary.productiveTimeMs / barTotal) * 100 : 50;
  const dPct = barTotal ? (summary.distractionTimeMs / barTotal) * 100 : 50;

  // Top domains by time + category
  const domainMap = new Map<string, { ms: number; cat: string }>();
  for (const e of session.events) {
    const prev = domainMap.get(e.domain);
    domainMap.set(e.domain, {
      ms: (prev?.ms ?? 0) + e.durationMs,
      cat: e.category ?? prev?.cat ?? "neutral",
    });
  }
  const topDomains = [...domainMap.entries()]
    .sort((a, b) => b[1].ms - a[1].ms)
    .slice(0, 5);
  const maxDomainMs = topDomains[0]?.[1].ms ?? 1;

  return `
    <div class="session-card">
      <div class="hero">
        <div class="hero-time">${fmtMs(total)}</div>
        <div class="hero-sub">${esc(summary.entryDomain)} \u00b7 ${session.events.length} pages</div>
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
          <div class="metric-num" style="color:${driftColor(summary.driftScore)}">${summary.driftScore}%</div>
          <div class="metric-label">Drift</div>
        </div>
        <div class="metric">
          <div class="metric-num">${session.stats.uniqueDomains}</div>
          <div class="metric-label">Sites</div>
        </div>
      </div>

      ${topDomains.map(([domain, { ms, cat }]) => {
        const barPct = Math.round((ms / maxDomainMs) * 100);
        return `
        <div class="domain-row">
          <div class="domain-dot ${cat}"></div>
          <span class="domain-name">${esc(domain)}</span>
          <div class="domain-bar-wrap">
            <div class="domain-bar-fill ${cat}" style="width:${barPct}%"></div>
          </div>
          <span class="domain-time">${fmtMs(ms)}</span>
        </div>`;
      }).join("")}
    </div>
  `;
}

async function processData(): Promise<void> {
  const events = await loadEvents();
  sessions = events.length > 0 ? processPipeline(events).sessions : [];
  render();
}

document.addEventListener("DOMContentLoaded", async () => {
  initTheme();
  tracking = await loadTrackingState();
  await checkAuth();

  // Listen for auth changes (e.g. magic link verified in another tab)
  onAuthStateChange(async (_event, session) => {
    isAuthenticated = !!session;
    userEmail = session?.user?.email ?? null;
    render();
  });

  processData();
});
