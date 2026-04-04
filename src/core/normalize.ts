// ---------------------------------------------------------------------------
// URL normalization and helpers
// ---------------------------------------------------------------------------

const NON_TRACKABLE_PROTOCOLS = [
  "chrome:",
  "chrome-extension:",
  "about:",
  "edge:",
  "brave:",
  "devtools:",
  "file:",
  "data:",
  "blob:",
  "view-source:",
];

/**
 * Returns true when the URL represents a page we should track.
 */
export function isTrackableUrl(url: string): boolean {
  if (!url || url.trim() === "") return false;
  const lower = url.toLowerCase();
  for (const proto of NON_TRACKABLE_PROTOCOLS) {
    if (lower.startsWith(proto)) return false;
  }
  // Must have a parseable host
  try {
    const u = new URL(url);
    return u.hostname.length > 0;
  } catch {
    return false;
  }
}

/**
 * Extract domain from a URL (lowercase, no www prefix).
 */
export function getDomain(url: string): string {
  try {
    const u = new URL(url);
    return u.hostname.toLowerCase().replace(/^www\./, "");
  } catch {
    return "";
  }
}

/**
 * Extract path from a URL, stripping query strings and fragments.
 */
export function getPath(url: string): string {
  try {
    const u = new URL(url);
    return u.pathname.replace(/\/+$/, "") || "/";
  } catch {
    return "/";
  }
}

/**
 * Produce a normalised URL suitable for comparison and grouping.
 *
 * - Lowercases hostname
 * - Strips protocol, query strings, fragments, trailing slashes
 * - Removes www prefix
 */
export function normalizeUrl(url: string): string {
  try {
    const u = new URL(url);
    const host = u.hostname.toLowerCase().replace(/^www\./, "");
    const path = u.pathname.replace(/\/+$/, "") || "";
    return `${host}${path}`;
  } catch {
    return url;
  }
}

/**
 * Generate a v4-style random ID (not crypto-grade, fine for local use).
 */
export function generateId(): string {
  return "xxxx-xxxx-xxxx".replace(/x/g, () =>
    Math.floor(Math.random() * 16).toString(16),
  );
}
