// ---------------------------------------------------------------------------
// Drift – Service worker entry point
// ---------------------------------------------------------------------------

import { installListeners } from "./tracker";

installListeners();
console.log("[Drift] Background service worker started");
