import { classifyEvent } from "../core/classify";
import { BrowsingEvent } from "../core/types";

function stubEvent(domain: string, overrides: Partial<BrowsingEvent> = {}): BrowsingEvent {
  return {
    id: "test",
    tabId: 1,
    windowId: 1,
    rawUrl: `https://${domain}`,
    normalizedUrl: domain,
    domain,
    startTime: 0,
    endTime: 1000,
    durationMs: 1000,
    ...overrides,
  };
}

describe("classifyEvent", () => {
  it("classifies github.com as productive", () => {
    expect(classifyEvent(stubEvent("github.com")).category).toBe("productive");
  });

  it("keeps ambiguous YouTube pages neutral instead of blanket-distracting", () => {
    expect(classifyEvent(stubEvent("youtube.com")).category).toBe("neutral");
  });

  it("classifies educational YouTube videos as productive", () => {
    const event = stubEvent("youtube.com", {
      rawUrl: "https://www.youtube.com/watch?v=swiftui-layout",
      normalizedUrl: "youtube.com/watch",
      path: "/watch",
      title: "SwiftUI layout tutorial for beginners",
    });

    expect(classifyEvent(event).category).toBe("productive");
  });

  it("classifies YouTube Shorts as distraction", () => {
    const event = stubEvent("youtube.com", {
      rawUrl: "https://www.youtube.com/shorts/abc123",
      normalizedUrl: "youtube.com/shorts",
      path: "/shorts/abc123",
      title: "funny coding meme",
    });

    expect(classifyEvent(event).category).toBe("distraction");
  });

  it("classifies LinkedIn jobs as productive and feed as distraction", () => {
    expect(
      classifyEvent(stubEvent("linkedin.com", {
        rawUrl: "https://www.linkedin.com/jobs/search",
        normalizedUrl: "linkedin.com/jobs/search",
        path: "/jobs/search",
        title: "Software engineering jobs",
      })).category,
    ).toBe("productive");

    expect(
      classifyEvent(stubEvent("linkedin.com", {
        rawUrl: "https://www.linkedin.com/feed/",
        normalizedUrl: "linkedin.com/feed",
        path: "/feed/",
        title: "LinkedIn Feed",
      })).category,
    ).toBe("distraction");
  });

  it("classifies unknown domains as neutral", () => {
    expect(classifyEvent(stubEvent("randomsite.org")).category).toBe("neutral");
  });

  it("classifies subdomains of productive domains", () => {
    expect(classifyEvent(stubEvent("gist.github.com")).category).toBe("productive");
  });

  it("includes reason and source", () => {
    const c = classifyEvent(stubEvent("reddit.com"));
    expect(c.reason).toContain("context-sensitive");
    expect(c.source).toBe("rule_engine");
  });
});
