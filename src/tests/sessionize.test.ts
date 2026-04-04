import { sessionizeEvents } from "../core/sessionize";
import { BrowsingEvent } from "../core/types";

function stubEvent(startTime: number, endTime: number): BrowsingEvent {
  return {
    id: `e-${startTime}`,
    tabId: 1,
    windowId: 1,
    rawUrl: "https://example.com",
    normalizedUrl: "example.com",
    domain: "example.com",
    startTime,
    endTime,
    durationMs: endTime - startTime,
  };
}

describe("sessionizeEvents", () => {
  it("groups continuous events into one session", () => {
    const events = [
      stubEvent(0, 5000),
      stubEvent(5500, 10000),
      stubEvent(10500, 15000),
    ];
    const groups = sessionizeEvents(events, 60_000);
    expect(groups).toHaveLength(1);
    expect(groups[0]).toHaveLength(3);
  });

  it("splits sessions at large gaps", () => {
    const events = [
      stubEvent(0, 5000),
      stubEvent(5500, 10000),
      stubEvent(700000, 705000), // 690s gap > 10min
    ];
    const groups = sessionizeEvents(events, 600_000);
    expect(groups).toHaveLength(2);
    expect(groups[0]).toHaveLength(2);
    expect(groups[1]).toHaveLength(1);
  });

  it("returns empty for no events", () => {
    expect(sessionizeEvents([])).toHaveLength(0);
  });

  it("handles a single event", () => {
    const groups = sessionizeEvents([stubEvent(0, 5000)]);
    expect(groups).toHaveLength(1);
    expect(groups[0]).toHaveLength(1);
  });
});
