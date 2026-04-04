// ---------------------------------------------------------------------------
// Mock browsing events for testing
// ---------------------------------------------------------------------------

import { BrowsingEvent } from "../core/types";
import { generateId, getDomain, normalizeUrl, getPath } from "../core/normalize";

function mockEvent(
  opts: {
    rawUrl: string;
    startTime: number;
    endTime: number;
    title?: string;
    tabId?: number;
    windowId?: number;
    transitionType?: BrowsingEvent["transitionType"];
  },
): BrowsingEvent {
  const url = opts.rawUrl;
  return {
    id: generateId(),
    tabId: opts.tabId ?? 1,
    windowId: opts.windowId ?? 1,
    rawUrl: url,
    normalizedUrl: normalizeUrl(url),
    domain: getDomain(url),
    path: getPath(url),
    title: opts.title,
    startTime: opts.startTime,
    endTime: opts.endTime,
    durationMs: opts.endTime - opts.startTime,
    transitionType: opts.transitionType ?? "tab_switch",
  };
}

// Timestamps: minutes from epoch base
const BASE = 1700000000000;
const min = (n: number) => n * 60_000;

// ---------------------------------------------------------------------------
// Session 1: Productive session (40 min, mostly GitHub + Docs)
// ---------------------------------------------------------------------------

export const productiveSession: BrowsingEvent[] = [
  mockEvent({
    rawUrl: "https://github.com/myorg/myrepo/pull/42",
    title: "PR #42 - Add auth middleware",
    startTime: BASE,
    endTime: BASE + min(8),
  }),
  mockEvent({
    rawUrl: "https://docs.google.com/document/d/abc123",
    title: "Design Doc - Auth Flow",
    startTime: BASE + min(8) + 2000,
    endTime: BASE + min(20),
  }),
  mockEvent({
    rawUrl: "https://stackoverflow.com/questions/12345/jwt-best-practices",
    title: "JWT best practices - Stack Overflow",
    startTime: BASE + min(20) + 1000,
    endTime: BASE + min(25),
  }),
  mockEvent({
    rawUrl: "https://github.com/myorg/myrepo/blob/main/src/auth.ts",
    title: "auth.ts - myrepo",
    startTime: BASE + min(25) + 500,
    endTime: BASE + min(35),
  }),
  mockEvent({
    rawUrl: "https://notion.so/team/sprint-planning",
    title: "Sprint Planning",
    startTime: BASE + min(35) + 1000,
    endTime: BASE + min(40),
  }),
];

// ---------------------------------------------------------------------------
// Session 2: Mixed session with minor drift (45 min)
// ---------------------------------------------------------------------------

export const mixedSession: BrowsingEvent[] = [
  mockEvent({
    rawUrl: "https://docs.google.com/spreadsheets/d/xyz",
    title: "Q4 Budget",
    startTime: BASE + min(60),
    endTime: BASE + min(72),
  }),
  mockEvent({
    rawUrl: "https://github.com/myorg/api-server/issues",
    title: "Issues - api-server",
    startTime: BASE + min(72) + 1500,
    endTime: BASE + min(80),
  }),
  // Minor drift
  mockEvent({
    rawUrl: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    title: "Quick break video",
    startTime: BASE + min(80) + 1000,
    endTime: BASE + min(84),
  }),
  // Back to work
  mockEvent({
    rawUrl: "https://github.com/myorg/api-server/pull/99",
    title: "PR #99 - Fix rate limiter",
    startTime: BASE + min(84) + 2000,
    endTime: BASE + min(95),
  }),
  mockEvent({
    rawUrl: "https://linear.app/myorg/issue/ENG-201",
    title: "ENG-201 - Rate limiter edge case",
    startTime: BASE + min(95) + 500,
    endTime: BASE + min(100),
  }),
  // Small distraction
  mockEvent({
    rawUrl: "https://reddit.com/r/programming",
    title: "r/programming",
    startTime: BASE + min(100) + 3000,
    endTime: BASE + min(105),
  }),
];

// ---------------------------------------------------------------------------
// Session 3: Heavy distraction session (50 min)
// ---------------------------------------------------------------------------

export const distractionSession: BrowsingEvent[] = [
  mockEvent({
    rawUrl: "https://docs.google.com/document/d/meeting-notes",
    title: "Meeting Notes",
    startTime: BASE + min(180),
    endTime: BASE + min(185),
  }),
  // Quick drift into distraction
  mockEvent({
    rawUrl: "https://youtube.com/watch?v=cats",
    title: "Funny Cat Videos",
    startTime: BASE + min(185) + 500,
    endTime: BASE + min(195),
  }),
  mockEvent({
    rawUrl: "https://reddit.com/r/aww",
    title: "r/aww - Cute animals",
    startTime: BASE + min(195) + 1000,
    endTime: BASE + min(205),
  }),
  mockEvent({
    rawUrl: "https://twitter.com/home",
    title: "Twitter / Home",
    startTime: BASE + min(205) + 500,
    endTime: BASE + min(215),
  }),
  mockEvent({
    rawUrl: "https://instagram.com/explore",
    title: "Explore - Instagram",
    startTime: BASE + min(215) + 200,
    endTime: BASE + min(222),
  }),
  // Brief attempt to return
  mockEvent({
    rawUrl: "https://github.com/myorg/myrepo",
    title: "myrepo",
    startTime: BASE + min(222) + 1000,
    endTime: BASE + min(224),
  }),
  // Back to distraction
  mockEvent({
    rawUrl: "https://youtube.com/shorts",
    title: "YouTube Shorts",
    startTime: BASE + min(224) + 500,
    endTime: BASE + min(230),
  }),
];

// ---------------------------------------------------------------------------
// Session 4: Short noisy session (rapid switching, 3 min)
// ---------------------------------------------------------------------------

export const noisySession: BrowsingEvent[] = [
  mockEvent({
    rawUrl: "https://google.com/search?q=best+coffee+near+me",
    title: "best coffee near me - Google Search",
    startTime: BASE + min(300),
    endTime: BASE + min(300) + 8000,
  }),
  mockEvent({
    rawUrl: "https://yelp.com/search?find_desc=coffee",
    title: "Coffee - Yelp",
    startTime: BASE + min(300) + 9000,
    endTime: BASE + min(300) + 15000,
  }),
  mockEvent({
    rawUrl: "https://maps.google.com/maps?q=coffee",
    title: "Coffee - Google Maps",
    startTime: BASE + min(300) + 16000,
    endTime: BASE + min(300) + 25000,
  }),
  mockEvent({
    rawUrl: "https://yelp.com/biz/best-beans-cafe",
    title: "Best Beans Cafe - Yelp",
    startTime: BASE + min(300) + 26000,
    endTime: BASE + min(303),
  }),
];

// ---------------------------------------------------------------------------
// All mock events combined (with session gaps)
// ---------------------------------------------------------------------------

export const allMockEvents: BrowsingEvent[] = [
  ...productiveSession,
  ...mixedSession,
  ...distractionSession,
  ...noisySession,
];
