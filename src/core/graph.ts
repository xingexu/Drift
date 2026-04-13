// ---------------------------------------------------------------------------
// Graph builder -- node/edge representation of a session
// ---------------------------------------------------------------------------

import {
  BrowsingEvent,
  Transition,
  GraphNode,
  GraphEdge,
  SessionGraph,
} from "./types";
import { generateId } from "./normalize";

/**
 * Build a directed graph representation of a browsing session.
 *
 * Nodes represent unique normalised URLs; edges represent transitions
 * between them.  When the same URL is visited multiple times, its node
 * accumulates visit count and total time.  Repeated transitions between
 * the same pair of URLs produce a single edge with an incrementing count
 * and a running average of the time gap.
 *
 * @param sessionId   - The session this graph belongs to.
 * @param events      - The session's events.
 * @param transitions - The session's transitions (from `buildTransitions`).
 * @returns A `SessionGraph` with deduplicated nodes and edges.
 */
export function buildSessionGraph(
  sessionId: string,
  events: BrowsingEvent[],
  transitions: Transition[],
): SessionGraph {
  if (events.length === 0) {
    return { sessionId, nodes: [], edges: [] };
  }

  // Build nodes keyed by normalizedUrl
  const nodeMap = new Map<string, GraphNode>();
  for (const e of events) {
    const existing = nodeMap.get(e.normalizedUrl);
    if (existing) {
      existing.visitCount++;
      existing.totalTimeMs += Math.max(0, e.durationMs);
    } else {
      nodeMap.set(e.normalizedUrl, {
        id: generateId(),
        normalizedUrl: e.normalizedUrl,
        domain: e.domain,
        visitCount: 1,
        totalTimeMs: Math.max(0, e.durationMs),
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
      // Running average: oldAvg * (n-1)/n + newVal/n
      const prevTotal = existing.avgTimeGapMs * existing.count;
      existing.count++;
      existing.avgTimeGapMs = (prevTotal + t.timeGapMs) / existing.count;
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
