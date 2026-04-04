import { classifyEvent } from "../core/classify";
import { BrowsingEvent } from "../core/types";

function stubEvent(domain: string): BrowsingEvent {
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
  };
}

describe("classifyEvent", () => {
  it("classifies github.com as productive", () => {
    expect(classifyEvent(stubEvent("github.com")).category).toBe("productive");
  });

  it("classifies youtube.com as distraction", () => {
    expect(classifyEvent(stubEvent("youtube.com")).category).toBe("distraction");
  });

  it("classifies unknown domains as neutral", () => {
    expect(classifyEvent(stubEvent("randomsite.org")).category).toBe("neutral");
  });

  it("classifies subdomains of productive domains", () => {
    expect(classifyEvent(stubEvent("gist.github.com")).category).toBe("productive");
  });

  it("includes reason and source", () => {
    const c = classifyEvent(stubEvent("reddit.com"));
    expect(c.reason).toContain("distraction");
    expect(c.source).toBe("rule_engine");
  });
});
