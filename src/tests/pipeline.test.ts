import { processPipeline, exportSession } from "../core/pipeline";
import {
  productiveSession,
  mixedSession,
  distractionSession,
  noisySession,
  allMockEvents,
} from "../mocks/sessions";
import { BrowsingEvent } from "../core/types";

function cloneEvents(events: BrowsingEvent[]): BrowsingEvent[] {
  return JSON.parse(JSON.stringify(events));
}

describe("processPipeline", () => {
  it("splits all mock events into 4 sessions", () => {
    const { sessions } = processPipeline(cloneEvents(allMockEvents));
    expect(sessions).toHaveLength(4);
  });

  it("classifies every event", () => {
    const { sessions } = processPipeline(cloneEvents(allMockEvents));
    for (const s of sessions) {
      for (const e of s.events) {
        expect(e.category).toBeDefined();
        expect(["productive", "neutral", "distraction"]).toContain(e.category);
      }
    }
  });

  it("marks the productive session as primarily productive", () => {
    const { sessions } = processPipeline(cloneEvents(productiveSession));
    expect(sessions).toHaveLength(1);
    expect(sessions[0].summaryLabel).toBe("Primarily productive");
  });

  it("detects drift in the distraction session", () => {
    const { sessions } = processPipeline(cloneEvents(distractionSession));
    expect(sessions).toHaveLength(1);
    expect(sessions[0].driftPoints.length).toBeGreaterThan(0);
    expect(sessions[0].driftScore).toBeGreaterThan(50);
  });

  it("detects some drift in the mixed session", () => {
    const { sessions } = processPipeline(cloneEvents(mixedSession));
    expect(sessions).toHaveLength(1);
    expect(sessions[0].driftPoints.length).toBeGreaterThan(0);
  });

  it("builds transitions for each session", () => {
    const { sessions } = processPipeline(cloneEvents(allMockEvents));
    for (const s of sessions) {
      expect(s.transitions).toHaveLength(s.events.length - 1);
    }
  });

  it("computes non-negative metrics", () => {
    const { sessions } = processPipeline(cloneEvents(allMockEvents));
    for (const s of sessions) {
      expect(s.stats.productiveTimeMs).toBeGreaterThanOrEqual(0);
      expect(s.stats.distractionTimeMs).toBeGreaterThanOrEqual(0);
      expect(s.stats.focusRatio).toBeGreaterThanOrEqual(0);
      expect(s.stats.focusRatio).toBeLessThanOrEqual(1);
    }
  });
});

describe("exportSession", () => {
  it("produces all expected export shapes", () => {
    const { sessions } = processPipeline(cloneEvents(productiveSession));
    const exported = exportSession(sessions[0]);

    expect(exported.session).toBeDefined();
    expect(exported.events.length).toBeGreaterThan(0);
    expect(exported.transitions.length).toBeGreaterThan(0);
    expect(exported.graph.nodes.length).toBeGreaterThan(0);
    expect(exported.replay.length).toBeGreaterThan(0);
    expect(exported.summary.sessionId).toBe(sessions[0].id);
    expect(exported.summary.narrative.length).toBeGreaterThan(0);
  });

  it("replay steps are in chronological order", () => {
    const { sessions } = processPipeline(cloneEvents(mixedSession));
    const { replay } = exportSession(sessions[0]);
    for (let i = 1; i < replay.length; i++) {
      expect(replay[i].timestamp).toBeGreaterThanOrEqual(
        replay[i - 1].timestamp,
      );
    }
  });

  it("graph nodes cover all visited URLs", () => {
    const { sessions } = processPipeline(cloneEvents(distractionSession));
    const { graph } = exportSession(sessions[0]);
    const uniqueUrls = new Set(sessions[0].events.map((e) => e.normalizedUrl));
    expect(graph.nodes.length).toBe(uniqueUrls.size);
  });

  it("summary narrative is non-empty", () => {
    const { sessions } = processPipeline(cloneEvents(distractionSession));
    const { summary } = exportSession(sessions[0]);
    expect(summary.narrative.length).toBeGreaterThan(20);
  });
});
