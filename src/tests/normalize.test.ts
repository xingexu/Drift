import {
  normalizeUrl,
  getDomain,
  getPath,
  isTrackableUrl,
  generateId,
} from "../core/normalize";

describe("normalizeUrl", () => {
  it("strips protocol, www, query, fragment, trailing slash", () => {
    expect(
      normalizeUrl("https://www.YouTube.com/watch?v=abc123&utm_source=test#section"),
    ).toBe("youtube.com/watch");
  });

  it("lowercases hostname", () => {
    expect(normalizeUrl("https://GitHub.COM/org/repo")).toBe(
      "github.com/org/repo",
    );
  });

  it("removes trailing slashes", () => {
    expect(normalizeUrl("https://example.com/path/")).toBe(
      "example.com/path",
    );
  });

  it("handles root paths", () => {
    expect(normalizeUrl("https://example.com/")).toBe("example.com");
  });

  it("returns original string for invalid URLs", () => {
    expect(normalizeUrl("not-a-url")).toBe("not-a-url");
  });
});

describe("getDomain", () => {
  it("extracts domain without www", () => {
    expect(getDomain("https://www.reddit.com/r/programming")).toBe(
      "reddit.com",
    );
  });

  it("returns empty string for invalid URLs", () => {
    expect(getDomain("garbage")).toBe("");
  });
});

describe("getPath", () => {
  it("extracts path without trailing slash", () => {
    expect(getPath("https://example.com/foo/bar/")).toBe("/foo/bar");
  });

  it("returns / for root", () => {
    expect(getPath("https://example.com")).toBe("/");
  });
});

describe("isTrackableUrl", () => {
  it("accepts http urls", () => {
    expect(isTrackableUrl("https://example.com")).toBe(true);
  });

  it("rejects chrome:// urls", () => {
    expect(isTrackableUrl("chrome://settings")).toBe(false);
  });

  it("rejects chrome-extension:// urls", () => {
    expect(isTrackableUrl("chrome-extension://abc/popup.html")).toBe(false);
  });

  it("rejects about: urls", () => {
    expect(isTrackableUrl("about:blank")).toBe(false);
  });

  it("rejects empty strings", () => {
    expect(isTrackableUrl("")).toBe(false);
  });

  it("rejects data: urls", () => {
    expect(isTrackableUrl("data:text/html,<h1>hi</h1>")).toBe(false);
  });
});

describe("generateId", () => {
  it("returns a string of hex characters and dashes", () => {
    const id = generateId();
    expect(id).toMatch(/^[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}$/);
  });

  it("generates unique ids", () => {
    const ids = new Set(Array.from({ length: 100 }, () => generateId()));
    expect(ids.size).toBe(100);
  });
});
