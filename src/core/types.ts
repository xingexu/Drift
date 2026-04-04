// ---------------------------------------------------------------------------
// Drift – Core Data Models
// ---------------------------------------------------------------------------

export type Category = "productive" | "neutral" | "distraction";

export type TransitionType =
  | "tab_switch"
  | "navigation"
  | "redirect"
  | "revisit"
  | "unknown";

export type DriftTrigger =
  | "productive_to_distraction"
  | "rapid_switching"
  | "sharp_jump"
  | "distraction_streak"
  | "repeated_bounce";

export type IntentLabel =
  | "work"
  | "study"
  | "research"
  | "entertainment"
  | "mixed"
  | "unknown";

// ---------------------------------------------------------------------------
// Browsing Event
// ---------------------------------------------------------------------------

export interface Classification {
  category: Category;
  reason: string;
  source: "rule_engine" | "user_override" | "ml";
}

export interface BrowsingEvent {
  id: string;
  sessionId?: string;
  tabId: number;
  windowId: number;
  rawUrl: string;
  normalizedUrl: string;
  domain: string;
  path?: string;
  title?: string;
  startTime: number;
  endTime: number;
  durationMs: number;
  previousEventId?: string;
  transitionType?: TransitionType;
  classification?: Classification;
  category?: Category;
  drift?: boolean;
  driftReasons?: string[];
}

// ---------------------------------------------------------------------------
// Raw tracker event (before normalization)
// ---------------------------------------------------------------------------

export interface RawTrackerEvent {
  tabId: number;
  windowId: number;
  url: string;
  title?: string;
  startTime: number;
  endTime?: number;
  transitionType?: TransitionType;
}

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

export interface SessionStats {
  eventCount: number;
  uniqueDomains: number;
  transitionCount: number;
  driftPointCount: number;
  categorySwitchCount: number;
  productiveTimeMs: number;
  neutralTimeMs: number;
  distractionTimeMs: number;
  longestProductiveStreakMs: number;
  longestDistractionStreakMs: number;
  mostVisitedDomain: string;
  longestSinglePageMs: number;
  focusRatio: number;
  distractionRatio: number;
  revisitCount: number;
}

export interface BrowsingSession {
  id: string;
  events: BrowsingEvent[];
  startTime: number;
  endTime: number;
  totalDurationMs: number;
  entryEventId: string;
  exitEventId: string;
  intent?: SessionIntent;
  driftScore: number;
  stats: SessionStats;
  transitions: Transition[];
  driftPoints: DriftPoint[];
  summaryLabel: string;
}

// ---------------------------------------------------------------------------
// Transition
// ---------------------------------------------------------------------------

export interface Transition {
  id: string;
  sessionId: string;
  sourceEventId: string;
  targetEventId: string;
  sourceDomain: string;
  targetDomain: string;
  sourceNormalizedUrl: string;
  targetNormalizedUrl: string;
  timeGapMs: number;
  isCategoryShift: boolean;
  fromCategory?: Category;
  toCategory?: Category;
}

// ---------------------------------------------------------------------------
// Graph data
// ---------------------------------------------------------------------------

export interface GraphNode {
  id: string;
  normalizedUrl: string;
  domain: string;
  visitCount: number;
  totalTimeMs: number;
  category?: Category;
}

export interface GraphEdge {
  id: string;
  sourceNodeId: string;
  targetNodeId: string;
  count: number;
  avgTimeGapMs: number;
}

export interface SessionGraph {
  sessionId: string;
  nodes: GraphNode[];
  edges: GraphEdge[];
}

// ---------------------------------------------------------------------------
// Drift
// ---------------------------------------------------------------------------

export interface DriftPoint {
  id: string;
  sessionId: string;
  eventId?: string;
  transitionId?: string;
  timestamp: number;
  reason: string;
  trigger: DriftTrigger;
}

// ---------------------------------------------------------------------------
// Intent
// ---------------------------------------------------------------------------

export interface SessionIntent {
  label: IntentLabel;
  confidence: number;
  basedOnEventIds: string[];
}

// ---------------------------------------------------------------------------
// Replay
// ---------------------------------------------------------------------------

export interface ReplayStep {
  step: number;
  eventId: string;
  timestamp: number;
  domain: string;
  normalizedUrl: string;
  title?: string;
  durationMs: number;
  category: Category;
  drift: boolean;
  driftReasons?: string[];
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

export interface SessionSummary {
  sessionId: string;
  startTime: number;
  endTime: number;
  entryDomain: string;
  exitDomain: string;
  inferredIntent: string;
  totalActiveTimeMs: number;
  productiveTimeMs: number;
  neutralTimeMs: number;
  distractionTimeMs: number;
  driftScore: number;
  driftPointCount: number;
  longestDistractionStreakMs: number;
  summaryLabel: string;
  narrative: string;
}
