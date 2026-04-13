// ---------------------------------------------------------------------------
// Classification engine – rule-based category assignment
// ---------------------------------------------------------------------------

import { BrowsingEvent, Category, Classification } from "./types";

// ---------------------------------------------------------------------------
// Domain lists (configurable)
// ---------------------------------------------------------------------------

const PRODUCTIVE_DOMAINS: Set<string> = new Set([
  "docs.google.com",
  "drive.google.com",
  "sheets.google.com",
  "slides.google.com",
  "notion.so",
  "github.com",
  "gitlab.com",
  "bitbucket.org",
  "stackoverflow.com",
  "stackexchange.com",
  "overleaf.com",
  "classroom.google.com",
  "leetcode.com",
  "dmoj.ca",
  "hackerrank.com",
  "codepen.io",
  "codesandbox.io",
  "figma.com",
  "linear.app",
  "jira.atlassian.com",
  "trello.com",
  "asana.com",
  "slack.com",
  "zoom.us",
  "calendar.google.com",
  "mail.google.com",
  "outlook.live.com",
  "developer.mozilla.org",
]);

const DISTRACTION_DOMAINS: Set<string> = new Set([
  "youtube.com",
  "twitter.com",
  "x.com",
  "instagram.com",
  "tiktok.com",
  "reddit.com",
  "netflix.com",
  "twitch.tv",
  "facebook.com",
  "tumblr.com",
  "9gag.com",
  "buzzfeed.com",
  "dailymail.co.uk",
  "pinterest.com",
  "snapchat.com",
  "discord.com",
]);

// ---------------------------------------------------------------------------
// Matching helpers
// ---------------------------------------------------------------------------

function matchesDomainSet(domain: string, domainSet: Set<string>): boolean {
  if (domainSet.has(domain)) return true;
  // Check if domain is a subdomain of any entry
  for (const d of domainSet) {
    if (domain.endsWith(`.${d}`)) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Classify a single event
// ---------------------------------------------------------------------------

// User overrides (loaded from settings at runtime)
let userOverridesMap = new Map<string, Category>();
let userOverrideSuffixes: [string, Category][] = [];

export function setUserOverrides(overrides: Record<string, Category>): void {
  userOverridesMap = new Map<string, Category>();
  userOverrideSuffixes = [];
  for (const [domain, category] of Object.entries(overrides)) {
    userOverridesMap.set(domain, category);
    userOverrideSuffixes.push([`.${domain}`, category]);
  }
}

export function classifyEvent(event: BrowsingEvent): Classification {
  const domain = event.domain;

  // Check user overrides first - exact match via Map (O(1))
  const exactOverride = userOverridesMap.get(domain);
  if (exactOverride) {
    return {
      category: exactOverride,
      reason: "user-defined domain override",
      source: "user_override",
    };
  }
  // Check subdomain matches
  for (const [suffix, category] of userOverrideSuffixes) {
    if (domain.endsWith(suffix)) {
      return {
        category,
        reason: "user-defined domain override",
        source: "user_override",
      };
    }
  }

  if (matchesDomainSet(domain, PRODUCTIVE_DOMAINS)) {
    return {
      category: "productive",
      reason: "matched known productive domain list",
      source: "rule_engine",
    };
  }

  if (matchesDomainSet(domain, DISTRACTION_DOMAINS)) {
    return {
      category: "distraction",
      reason: "matched known distraction domain list",
      source: "rule_engine",
    };
  }

  return {
    category: "neutral",
    reason: "no matching rule, defaulted to neutral",
    source: "rule_engine",
  };
}

/**
 * Classify all events in-place. Returns the same array for convenience.
 */
export function classifyEvents(events: BrowsingEvent[]): BrowsingEvent[] {
  for (const event of events) {
    const c = classifyEvent(event);
    event.classification = c;
    event.category = c.category;
  }
  return events;
}

// ---------------------------------------------------------------------------
// Configuration helpers (allow runtime customization)
// ---------------------------------------------------------------------------

export function addProductiveDomains(domains: string[]): void {
  domains.forEach((d) => PRODUCTIVE_DOMAINS.add(d));
}

export function addDistractionDomains(domains: string[]): void {
  domains.forEach((d) => DISTRACTION_DOMAINS.add(d));
}

export function getProductiveDomains(): string[] {
  return [...PRODUCTIVE_DOMAINS];
}

export function getDistractionDomains(): string[] {
  return [...DISTRACTION_DOMAINS];
}
