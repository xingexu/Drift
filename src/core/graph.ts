// ---------------------------------------------------------------------------
// Graph builder – node/edge representation of a session
// ---------------------------------------------------------------------------

import {
  BrowsingEvent,
  Transition,
  GraphNode,
  GraphEdge,
  SessionGraph,
} from "./types";
import { generateId } from "./normalize";

export function buildSessionGraph(
  sessionId: string,
  events: BrowsingEvent[],
  transitions: Transition[],
): SessionGraph {
  // Build nodes keyed by normalizedUrl
  const nodeMap = new Map<string, GraphNode>();
  for (const e of events) {
    const existing = nodeMap.get(e.normalizedUrl);
    if (existing) {
      existing.visitCount++;
      existing.totalTimeMs += e.durationMs;
    } else {
      nodeMap.set(e.normalizedUrl, {
        id: generateId(),
        normalizedUrl: e.normalizedUrl,
        domain: e.domain,
        visitCount: 1,
        totalTimeMs: e.durationMs,
        category: e.category,
      });
    }
  }

  // Build edges keyed by "srcUrl -> tgtUrl"
  const edgeMap = new Map<string, GraphEdge>();
  for (const t of transitions) {
    const key = `${t.sourceNormalizedUrl}->${t.targetNormalizedUrl}`;
    const srcNode = nodeMap.get(t.sourceNormalizedUrl);
    const tgtNode = nodeMap.get(t.targetNormalizedUrl);
    if (!srcNode || !tgtNode) continue;

    const existing = edgeMap.get(key);
    if (existing) {
      existing.count++;
      existing.avgTimeGapMs =
        (existing.avgTimeGapMs * (existing.count - 1) + t.timeGapMs) /
        existing.count;
    } else {
      edgeMap.set(key, {
        id: generateId(),
        sourceNodeId: srcNode.id,
        targetNodeId: tgtNode.id,
        count: 1,
        avgTimeGapMs: t.timeGapMs,
      });
    }
  }

  return {
    sessionId,
    nodes: [...nodeMap.values()],
    edges: [...edgeMap.values()],
  };
}
