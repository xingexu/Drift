// ---------------------------------------------------------------------------
// Drift – Service worker entry point
// ---------------------------------------------------------------------------

import { installListeners, resetDriftCount } from "./tracker";
import {
  loadTrackingState,
  setTrackingState,
  loadSettings,
} from "./storage";
import { setUserOverrides } from "../core/classify";

installListeners();
console.log("[Drift] Background service worker started");

// Load user domain overrides on startup
loadSettings().then((settings) => {
  setUserOverrides(settings.domainOverrides);
}).catch(() => {});

// Reload overrides when settings change
if (typeof chrome !== "undefined" && chrome.storage?.onChanged) {
  chrome.storage.onChanged.addListener((changes) => {
    if ("drift_settings" in changes) {
      const newSettings = changes.drift_settings.newValue;
      if (newSettings?.domainOverrides) {
        setUserOverrides(newSettings.domainOverrides);
      }
    }
  });
}

// ---------------------------------------------------------------------------
// Keyboard shortcut: toggle tracking
// ---------------------------------------------------------------------------

if (typeof chrome !== "undefined" && chrome.commands) {
  chrome.commands.onCommand.addListener(async (command) => {
    if (command === "toggle-tracking") {
      const current = await loadTrackingState();
      await setTrackingState(!current);
      if (!current) {
        resetDriftCount();
      }
      // Flash badge to confirm
      chrome.action.setBadgeText({ text: current ? "OFF" : "ON" });
      chrome.action.setBadgeBackgroundColor({ color: current ? "#86868b" : "#1a8a3e" });
      setTimeout(() => chrome.action.setBadgeText({ text: "" }), 1500);
    }
  });
}
