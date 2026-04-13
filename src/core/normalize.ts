// ---------------------------------------------------------------------------
// URL normalization and helpers
// ---------------------------------------------------------------------------

/** Protocols that represent internal browser pages we should not track. */
const NON_TRACKABLE_PROTOCOLS: ReadonlyArray<string> = [
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
  "moz-extension:",
  "opera:",
  "safari-web-extension:",
];

/**
 * Returns `true` when the URL represents a page we should track.
 *
 * Pages on internal browser protocols (chrome://, about://, etc.) and
 * invalid/empty URLs are rejected.
 *
 * @param url - The raw URL to check.
 * @returns Whether the URL is trackable.
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
 * Extract the domain from a URL (lowercase, no `www.` prefix).
 *
 * @param url - A fully-qualified URL.
 * @returns The bare domain, or `""` for unparseable URLs.
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
 * Extract the pathname from a URL, stripping trailing slashes.
 *
 * @param url - A fully-qualified URL.
 * @returns The path portion (always starts with `/`).
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
 * - Lowercases the hostname
 * - Strips protocol, query strings, fragments, and trailing slashes
 * - Removes `www.` prefix
 *
 * @param url - A fully-qualified URL.
 * @returns A normalised `host/path` string (no protocol, no query, no hash).
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
 *
 * The returned string has the shape `xxxx-xxxx-xxxx` where each `x` is a
 * random hexadecimal digit.
 *
 * @returns A 14-character hex ID string.
 */
export function generateId(): string {
  return "xxxx-xxxx-xxxx".replace(/x/g, () =>
    Math.floor(Math.random() * 16).toString(16),
  );
}
