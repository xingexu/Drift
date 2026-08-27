// ---------------------------------------------------------------------------
// Classification engine -- rule-based category assignment
// ---------------------------------------------------------------------------

import { BrowsingEvent, Category, Classification } from "./types";

// ---------------------------------------------------------------------------
// Domain lists (configurable)
// ---------------------------------------------------------------------------

const PRODUCTIVE_DOMAINS: Set<string> = new Set([
  // --- Docs & productivity suites ---
  "docs.google.com",
  "drive.google.com",
  "sheets.google.com",
  "slides.google.com",
  "sites.google.com",
  "forms.google.com",
  "classroom.google.com",
  "calendar.google.com",
  "mail.google.com",
  "outlook.live.com",
  "outlook.office.com",
  "outlook.office365.com",
  "onedrive.live.com",
  "office.com",
  "notion.so",
  "coda.io",
  "airtable.com",
  "clickup.com",
  "monday.com",
  "basecamp.com",
  "roamresearch.com",
  "obsidian.md",
  "dropbox.com",
  "box.com",
  "evernote.com",
  "onenote.com",
  "quip.com",

  // --- Code & development ---
  "github.com",
  "gitlab.com",
  "bitbucket.org",
  "dev.azure.com",
  "sourceforge.net",
  "codeberg.org",
  "stackoverflow.com",
  "stackexchange.com",
  "developer.mozilla.org",
  "developer.apple.com",
  "developer.android.com",
  "learn.microsoft.com",
  "docs.rs",
  "pkg.go.dev",
  "pypi.org",
  "npmjs.com",
  "crates.io",
  "rubygems.org",
  "packagist.org",
  "hex.pm",
  "pub.dev",
  "mvnrepository.com",
  "overleaf.com",
  "replit.com",
  "codepen.io",
  "codesandbox.io",
  "stackblitz.com",
  "glitch.com",
  "jsfiddle.net",
  "leetcode.com",
  "hackerrank.com",
  "codewars.com",
  "exercism.org",
  "dmoj.ca",
  "codeforces.com",
  "atcoder.jp",

  // --- Design tools ---
  "figma.com",
  "canva.com",
  "sketch.com",
  "miro.com",
  "whimsical.com",
  "lucidchart.com",
  "draw.io",
  "app.diagrams.net",
  "zeplin.io",
  "invisionapp.com",
  "framer.com",
  "penpot.app",
  "excalidraw.com",

  // --- Project management ---
  "linear.app",
  "jira.atlassian.com",
  "trello.com",
  "asana.com",
  "shortcut.com",
  "height.app",
  "todoist.com",
  "ticktick.com",
  "pivotaltracker.com",
  "youtrack.jetbrains.com",
  "plan.io",
  "wrike.com",
  "smartsheet.com",

  // --- Communication (work) ---
  "slack.com",
  "app.slack.com",
  "teams.microsoft.com",
  "zoom.us",
  "meet.google.com",
  "whereby.com",
  "gather.town",
  "loom.com",
  "around.co",

  // --- Research & learning ---
  "scholar.google.com",
  "arxiv.org",
  "researchgate.net",
  "semanticscholar.org",
  "jstor.org",
  "pubmed.ncbi.nlm.nih.gov",
  "coursera.org",
  "edx.org",
  "udemy.com",
  "khanacademy.org",
  "brilliant.org",
  "udacity.com",
  "pluralsight.com",
  "skillshare.com",
  "freecodecamp.org",
  "w3schools.com",
  "geeksforgeeks.org",
  "tutorialspoint.com",
  "medium.com",
  "dev.to",
  "hashnode.com",
  "substack.com",

  // --- Cloud & infra ---
  "console.aws.amazon.com",
  "portal.azure.com",
  "console.cloud.google.com",
  "vercel.com",
  "netlify.com",
  "heroku.com",
  "railway.app",
  "fly.io",
  "render.com",
  "supabase.com",
  "firebase.google.com",
  "app.terraform.io",
  "grafana.com",
  "sentry.io",
  "datadog.com",
  "newrelic.com",
  "pagerduty.com",

  // --- CI / CD ---
  "app.circleci.com",
  "travis-ci.com",
  "app.codecov.io",

  // --- Analytics ---
  "analytics.google.com",
  "mixpanel.com",
  "amplitude.com",
  "app.posthog.com",
  "plausible.io",

  // --- CRM & business ---
  "salesforce.com",
  "hubspot.com",
  "intercom.com",
  "zendesk.com",
  "freshdesk.com",
  "stripe.com",
  "dashboard.stripe.com",

  // --- Writing & AI ---
  "grammarly.com",
  "chat.openai.com",
  "chatgpt.com",
  "claude.ai",
  "bard.google.com",
  "copilot.microsoft.com",
  "perplexity.ai",
  "wolfram.com",
  "wolframalpha.com",
]);

const DISTRACTION_DOMAINS: Set<string> = new Set([
  // --- Social media ---
  "twitter.com",
  "x.com",
  "instagram.com",
  "tiktok.com",
  "reddit.com",
  "facebook.com",
  "threads.net",
  "tumblr.com",
  "snapchat.com",
  "pinterest.com",
  "linkedin.com/feed",

  // --- Streaming & entertainment ---
  "netflix.com",
  "twitch.tv",
  "hulu.com",
  "disneyplus.com",
  "hbomax.com",
  "max.com",
  "primevideo.com",
  "peacocktv.com",
  "crunchyroll.com",
  "funimation.com",
  "spotify.com",
  "music.youtube.com",
  "soundcloud.com",
  "pandora.com",
  "deezer.com",

  // --- Gaming ---
  "store.steampowered.com",
  "steamcommunity.com",
  "twitch.tv",
  "itch.io",
  "miniclip.com",
  "poki.com",
  "coolmathgames.com",
  "kongregate.com",
  "chess.com",
  "lichess.org",

  // --- News & click-bait ---
  "9gag.com",
  "buzzfeed.com",
  "dailymail.co.uk",
  "boredpanda.com",
  "digg.com",
  "ifunny.co",
  "imgur.com",
  "knowyourmeme.com",
  "thechive.com",
  "funnyjunk.com",

  // --- Messaging (personal) ---
  "discord.com",
  "web.whatsapp.com",
  "messenger.com",
  "telegram.org",
  "web.telegram.org",

  // --- Shopping (non-work browsing) ---
  "amazon.com",
  "ebay.com",
  "etsy.com",
  "aliexpress.com",
  "wish.com",
  "shein.com",
  "temu.com",

  // --- Dating ---
  "tinder.com",
  "bumble.com",
  "hinge.co",

  // --- Sports / gossip ---
  "espn.com",
  "bleacherreport.com",
  "tmz.com",
]);

const CONTEXT_DEPENDENT_DOMAINS: Set<string> = new Set([
  "youtube.com",
  "youtu.be",
  "linkedin.com",
  "reddit.com",
]);

const PRODUCTIVE_SIGNALS: Array<[string, number]> = [
  ["tutorial", 3],
  ["lecture", 3],
  ["lesson", 3],
  ["course", 3],
  ["study", 2],
  ["learn", 2],
  ["explained", 2],
  ["walkthrough", 2],
  ["research", 3],
  ["case study", 2],
  ["khan academy", 4],
  ["crash course", 3],
  ["freecodecamp", 4],
  ["programming", 3],
  ["coding", 3],
  ["software engineering", 3],
  ["swift", 2],
  ["python", 2],
  ["javascript", 2],
  ["typescript", 2],
  ["react", 2],
  ["math", 2],
  ["calculus", 2],
  ["engineering", 3],
  ["interview prep", 3],
  ["portfolio", 2],
  ["resume", 3],
  ["job", 2],
  ["jobs", 2],
  ["career", 2],
  ["hiring", 2],
  ["recruiter", 2],
  ["certification", 3],
];

const DISTRACTION_SIGNALS: Array<[string, number]> = [
  ["shorts", 5],
  ["meme", 3],
  ["memes", 3],
  ["prank", 3],
  ["reaction", 2],
  ["drama", 3],
  ["gossip", 4],
  ["celebrity", 3],
  ["vlog", 3],
  ["haul", 3],
  ["challenge", 2],
  ["compilation", 2],
  ["fails", 3],
  ["music video", 4],
  ["trailer", 3],
  ["highlights", 2],
  ["gameplay", 3],
  ["stream", 2],
  ["fortnite", 4],
  ["minecraft", 3],
  ["valorant", 4],
  ["league of legends", 4],
  ["tiktok", 4],
  ["funny", 3],
  ["comedy", 3],
  ["viral", 3],
  ["feed", 2],
  ["notifications", 2],
];

const PRODUCTIVE_SUBREDDIT_SIGNALS = [
  "learnprogramming",
  "programming",
  "swift",
  "iosprogramming",
  "webdev",
  "javascript",
  "typescript",
  "machinelearning",
  "science",
  "askscience",
  "askacademia",
  "productivity",
  "cscareerquestions",
  "design",
  "userexperience",
];

// ---------------------------------------------------------------------------
// Pre-built suffix list for O(1) exact + O(k) suffix matching
// ---------------------------------------------------------------------------

/**
 * Build a plain-array snapshot of a Set's values for suffix iteration.
 * We keep this as a module-level cache and rebuild when domains are added.
 */
let productiveSuffixList: string[] = [...PRODUCTIVE_DOMAINS];
let distractionSuffixList: string[] = [...DISTRACTION_DOMAINS];

function rebuildSuffixLists(): void {
  productiveSuffixList = [...PRODUCTIVE_DOMAINS];
  distractionSuffixList = [...DISTRACTION_DOMAINS];
}

// ---------------------------------------------------------------------------
// Matching helpers
// ---------------------------------------------------------------------------

/**
 * Check whether `domain` matches any entry in `domainSet`, either as an
 * exact match or as a subdomain of an entry (e.g. `gist.github.com`
 * matches `github.com`).
 *
 * @param domain      - The domain to test.
 * @param domainSet   - The Set of known domains (exact match, O(1)).
 * @param suffixList  - The array form for subdomain suffix checks.
 * @returns `true` if the domain matches.
 */
function matchesDomainSet(
  domain: string,
  domainSet: Set<string>,
  suffixList: ReadonlyArray<string>,
): boolean {
  if (domainSet.has(domain)) return true;
  // Check if domain is a subdomain of any entry
  for (const d of suffixList) {
    if (domain.endsWith(`.${d}`)) return true;
  }
  return false;
}

function normalizeText(value: string | undefined): string {
  if (!value) return "";
  try {
    value = decodeURIComponent(value);
  } catch {
    // Keep the original text if it contains malformed escape sequences.
  }
  return value.toLowerCase().replace(/[+_-]/g, " ");
}

function signalScore(text: string, signals: ReadonlyArray<[string, number]>): number {
  return signals.reduce((total, [phrase, weight]) => {
    return text.includes(phrase) ? total + weight : total;
  }, 0);
}

function parseEventUrl(event: BrowsingEvent): URL | null {
  const candidates = [event.rawUrl, event.normalizedUrl].filter(Boolean);
  for (const candidate of candidates) {
    try {
      return new URL(candidate);
    } catch {
      try {
        return new URL(`https://${candidate}`);
      } catch {
        // Try the next representation.
      }
    }
  }
  return null;
}

function pathStarts(path: string, prefix: string): boolean {
  return path === prefix || path.startsWith(`${prefix}/`);
}

function classifyContextDependentEvent(event: BrowsingEvent): Category | null {
  const domain = event.domain.toLowerCase().replace(/^www\./, "");
  const isContextDependent =
    CONTEXT_DEPENDENT_DOMAINS.has(domain) ||
    [...CONTEXT_DEPENDENT_DOMAINS].some((d) => domain.endsWith(`.${d}`));

  if (!isContextDependent) return null;

  const url = parseEventUrl(event);
  const path = normalizeText(event.path ?? url?.pathname ?? "");
  const query = normalizeText(url?.search ?? "");
  const text = [event.title, event.rawUrl, path, query].map(normalizeText).join(" ");
  const productive = signalScore(text, PRODUCTIVE_SIGNALS);
  const distraction = signalScore(text, DISTRACTION_SIGNALS);

  if (domain === "music.youtube.com") {
    return productive >= 4 && productive > distraction ? "productive" : "distraction";
  }

  if (domain === "youtube.com" || domain.endsWith(".youtube.com") || domain === "youtu.be") {
    if (
      pathStarts(path, "/shorts") ||
      pathStarts(path, "/feed/trending") ||
      pathStarts(path, "/gaming") ||
      pathStarts(path, "/music")
    ) {
      return productive >= 4 && productive > distraction ? "productive" : "distraction";
    }

    if (pathStarts(path, "/watch") || domain === "youtu.be") {
      if (productive >= Math.max(3, distraction + 1)) return "productive";
      if (distraction >= Math.max(3, productive + 1)) return "distraction";
      return "neutral";
    }

    if (pathStarts(path, "/results")) {
      if (productive >= 3 && productive > distraction) return "productive";
      if (distraction >= 3 && distraction > productive) return "distraction";
      return "neutral";
    }

    return "neutral";
  }

  if (domain === "linkedin.com" || domain.endsWith(".linkedin.com")) {
    if (
      pathStarts(path, "/learning") ||
      pathStarts(path, "/jobs") ||
      pathStarts(path, "/in") ||
      pathStarts(path, "/company") ||
      pathStarts(path, "/school") ||
      pathStarts(path, "/sales")
    ) {
      return "productive";
    }

    if (pathStarts(path, "/feed") || pathStarts(path, "/notifications") || pathStarts(path, "/games")) {
      return productive >= 4 && productive > distraction ? "productive" : "distraction";
    }

    if (productive >= 3 && productive > distraction) return "productive";
    if (distraction >= 3 && distraction > productive) return "distraction";
    return "neutral";
  }

  if (domain === "reddit.com" || domain.endsWith(".reddit.com")) {
    if (pathStarts(path, "/r/all") || pathStarts(path, "/r/popular")) return "distraction";
    if (PRODUCTIVE_SUBREDDIT_SIGNALS.some((subreddit) => path.includes(`/r/${subreddit}`))) {
      return distraction >= productive + 2 ? "neutral" : "productive";
    }
    if (productive >= 3 && productive > distraction) return "productive";
    if (distraction >= 3 && distraction > productive) return "distraction";
    return "neutral";
  }

  return "neutral";
}

// ---------------------------------------------------------------------------
// User overrides
// ---------------------------------------------------------------------------

/** User-defined domain-to-category overrides loaded from settings. */
let userOverrides: ReadonlyMap<string, Category> = new Map();

/**
 * Set user overrides for domain classification.
 *
 * Overrides take the highest priority: if a domain matches an override
 * (either as an exact match or as a subdomain), the override category
 * is used regardless of the built-in lists.
 *
 * @param overrides - A record mapping domain strings to categories.
 */
export function setUserOverrides(overrides: Record<string, Category>): void {
  userOverrides = new Map(Object.entries(overrides));
}

// ---------------------------------------------------------------------------
// Classify a single event
// ---------------------------------------------------------------------------

/**
 * Classify a single browsing event based on its domain.
 *
 * Priority order:
 * 1. User overrides
 * 2. Built-in productive domain list
 * 3. Built-in distraction domain list
 * 4. Default to neutral
 *
 * @param event - The browsing event to classify.
 * @returns A classification result with category, reason, and source.
 */
export function classifyEvent(event: BrowsingEvent): Classification {
  const domain = event.domain;

  // Check user overrides first (Map lookup is O(1) for exact, O(k) for suffix)
  for (const [overrideDomain, category] of userOverrides) {
    if (domain === overrideDomain || domain.endsWith(`.${overrideDomain}`)) {
      return {
        category,
        reason: "user-defined domain override",
        source: "user_override",
      };
    }
  }

  const contextualCategory = classifyContextDependentEvent(event);
  if (contextualCategory) {
    return {
      category: contextualCategory,
      reason: "matched context-sensitive URL and title rules",
      source: "rule_engine",
    };
  }

  if (matchesDomainSet(domain, PRODUCTIVE_DOMAINS, productiveSuffixList)) {
    return {
      category: "productive",
      reason: "matched known productive domain list",
      source: "rule_engine",
    };
  }

  if (matchesDomainSet(domain, DISTRACTION_DOMAINS, distractionSuffixList)) {
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
 * Classify all events in-place.  Each event receives a `classification`
 * and a top-level `category` field.
 *
 * @param events - The array of browsing events to classify (mutated in-place).
 * @returns The same array for convenience chaining.
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

/**
 * Add domains to the productive list at runtime.
 *
 * @param domains - An array of domain strings to add.
 */
export function addProductiveDomains(domains: string[]): void {
  for (const d of domains) PRODUCTIVE_DOMAINS.add(d);
  rebuildSuffixLists();
}

/**
 * Add domains to the distraction list at runtime.
 *
 * @param domains - An array of domain strings to add.
 */
export function addDistractionDomains(domains: string[]): void {
  for (const d of domains) DISTRACTION_DOMAINS.add(d);
  rebuildSuffixLists();
}

/**
 * Return a snapshot of the current productive domain list.
 *
 * @returns An array of domain strings.
 */
export function getProductiveDomains(): string[] {
  return [...PRODUCTIVE_DOMAINS];
}

/**
 * Return a snapshot of the current distraction domain list.
 *
 * @returns An array of domain strings.
 */
export function getDistractionDomains(): string[] {
  return [...DISTRACTION_DOMAINS];
}
