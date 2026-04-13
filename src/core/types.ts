// ---------------------------------------------------------------------------
// Drift -- Core Data Models
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Semantic type aliases
// ---------------------------------------------------------------------------

/**
 * Semantic type aliases provide documentation and IDE hints about what
 * a `string` or `number` field represents, without introducing
 * structural incompatibilities that would break plain literal
 * assignments in tests, mocks, and consumer code.
 */

/** A unique identifier for a browsing event. */
export type EventId = string;

/** A unique identifier for a browsing session. */
export type SessionId = string;

/** A unique identifier for a transition between events. */
export type TransitionId = string;

/** A unique identifier for a drift point. */
export type DriftPointId = string;

/** A unique identifier for a graph node. */
export type GraphNodeId = string;

/** A unique identifier for a graph edge. */
export type GraphEdgeId = string;

/** Unix-epoch millisecond timestamp. */
export type Timestamp = number;

/** Non-negative duration in milliseconds. */
export type DurationMs = number;

// ---------------------------------------------------------------------------
// Enums and union types
// ---------------------------------------------------------------------------

/** The classification bucket for an event or domain. */
export type Category = "productive" | "neutral" | "distraction";

/** How the user arrived at a page. */
export type TransitionType =
  | "tab_switch"
  | "navigation"
  | "redirect"
  | "revisit"
  | "unknown";

/** The trigger that caused a drift point to be recorded. */
export type DriftTrigger =
  | "productive_to_distraction"
  | "rapid_switching"
  | "sharp_jump"
  | "distraction_streak"
  | "repeated_bounce";

/** High-level intent label for a session. */
export type IntentLabel =
  | "work"
  | "study"
  | "research"
  | "entertainment"
  | "mixed"
  | "unknown";

/** Where a classification decision came from. */
export type ClassificationSource = "rule_engine" | "user_override" | "ml";

// ---------------------------------------------------------------------------
// Browsing Event
// ---------------------------------------------------------------------------

/** The result of classifying a single browsing event. */
export interface Classification {
  category: Category;
  reason: string;
  source: ClassificationSource;
}

/**
 * A single browsing event representing a page visit with timing data.
 *
 * Events are the fundamental unit of data in Drift.  Each one captures a
 * contiguous span of time the user spent on a particular URL.
 */
export interface BrowsingEvent {
  id: EventId;
  sessionId?: SessionId;
  tabId: number;
  windowId: number;
  rawUrl: string;
  normalizedUrl: string;
  domain: string;
  path?: string;
  title?: string;
  startTime: Timestamp;
  endTime: Timestamp;
  durationMs: DurationMs;
  previousEventId?: EventId;
  transitionType?: TransitionType;
  classification?: Classification;
  category?: Category;
  drift?: boolean;
  driftReasons?: string[];
}

// ---------------------------------------------------------------------------
// Raw tracker event (before normalization)
// ---------------------------------------------------------------------------

/**
 * The minimal event shape emitted by the tracker before the pipeline
 * normalizes and enriches it.
 */
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

/** Aggregate statistics for a single browsing session. */
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
  /** Ratio of productive time to total active time (0-1). */
  focusRatio: number;
  /** Ratio of distraction time to total active time (0-1). */
  distractionRatio: number;
  revisitCount: number;
}

/**
 * A browsing session: a contiguous block of events separated from
 * other sessions by an inactivity gap.
 */
export interface BrowsingSession {
  id: SessionId;
  events: BrowsingEvent[];
  startTime: Timestamp;
  endTime: Timestamp;
  totalDurationMs: DurationMs;
  entryEventId: EventId;
  exitEventId: EventId;
  intent?: SessionIntent;
  /** Percentage of active time spent on distracting pages (0-100). */
  driftScore: number;
  stats: SessionStats;
  transitions: Transition[];
  driftPoints: DriftPoint[];
  summaryLabel: string;
}

// ---------------------------------------------------------------------------
// Transition
// ---------------------------------------------------------------------------

/** A navigation from one event/page to the next within a session. */
export interface Transition {
  id: TransitionId;
  sessionId: SessionId;
  sourceEventId: EventId;
  targetEventId: EventId;
  sourceDomain: string;
  targetDomain: string;
  sourceNormalizedUrl: string;
  targetNormalizedUrl: string;
  /** Gap between the source event's endTime and the target's startTime (ms). Clamped to >= 0. */
  timeGapMs: number;
  isCategoryShift: boolean;
  fromCategory?: Category;
  toCategory?: Category;
}

// ---------------------------------------------------------------------------
// Graph data
// ---------------------------------------------------------------------------

/** A node in the session navigation graph, representing a unique URL. */
export interface GraphNode {
  id: GraphNodeId;
  normalizedUrl: string;
  domain: string;
  visitCount: number;
  totalTimeMs: number;
  category?: Category;
}

/** A directed edge in the session graph, representing one or more transitions between two URLs. */
export interface GraphEdge {
  id: GraphEdgeId;
  sourceNodeId: GraphNodeId;
  targetNodeId: GraphNodeId;
  count: number;
  avgTimeGapMs: number;
}

/** The full graph for a session. */
export interface SessionGraph {
  sessionId: SessionId;
  nodes: GraphNode[];
  edges: GraphEdge[];
}

// ---------------------------------------------------------------------------
// Drift
// ---------------------------------------------------------------------------

/**
 * A single detected moment of attention drift within a session.
 * Drift points reference the event that triggered them and the reason.
 */
export interface DriftPoint {
  id: DriftPointId;
  sessionId: SessionId;
  eventId?: EventId;
  transitionId?: TransitionId;
  timestamp: Timestamp;
  reason: string;
  trigger: DriftTrigger;
}

// ---------------------------------------------------------------------------
// Intent
// ---------------------------------------------------------------------------

/** The inferred intent of a session, based on the opening events. */
export interface SessionIntent {
  label: IntentLabel;
  /** Confidence score (0-1). */
  confidence: number;
  basedOnEventIds: EventId[];
}

// ---------------------------------------------------------------------------
// Replay
// ---------------------------------------------------------------------------

/** A single step in the session replay timeline. */
export interface ReplayStep {
  step: number;
  eventId: EventId;
  timestamp: Timestamp;
  domain: string;
  normalizedUrl: string;
  title?: string;
  durationMs: DurationMs;
  category: Category;
  drift: boolean;
  driftReasons?: string[];
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

/** A human-readable summary of a session. */
export interface SessionSummary {
  sessionId: SessionId;
  startTime: Timestamp;
  endTime: Timestamp;
  entryDomain: string;
  exitDomain: string;
  inferredIntent: string;
  totalActiveTimeMs: number;
  productiveTimeMs: number;
  neutralTimeMs: number;
  distractionTimeMs: number;
  /** Percentage of active time spent on distracting pages (0-100). */
  driftScore: number;
  driftPointCount: number;
  longestDistractionStreakMs: number;
  summaryLabel: string;
  narrative: string;
}

// ---------------------------------------------------------------------------
// Session History (persisted summaries for past sessions)
// ---------------------------------------------------------------------------

/** A compact, serialisable summary of a session for long-term storage. */
export interface SessionHistoryEntry {
  sessionId: SessionId;
  startTime: Timestamp;
  endTime: Timestamp;
  totalActiveTimeMs: number;
  productiveTimeMs: number;
  neutralTimeMs: number;
  distractionTimeMs: number;
  /** Percentage of active time spent on distracting pages (0-100). */
  driftScore: number;
  driftPointCount: number;
  summaryLabel: string;
  entryDomain: string;
  exitDomain: string;
  topDomains: { domain: string; timeMs: number }[];
  eventCount: number;
}

// ---------------------------------------------------------------------------
// Weekly Report (aggregated across sessions)
// ---------------------------------------------------------------------------

/** A summary report covering a 7-day window. */
export interface WeeklyReport {
  periodStart: Timestamp;
  periodEnd: Timestamp;
  sessionCount: number;
  totalTimeMs: number;
  productiveTimeMs: number;
  neutralTimeMs: number;
  distractionTimeMs: number;
  /** Average drift score across sessions (0-100). */
  averageDriftScore: number;
  topDomains: { domain: string; timeMs: number }[];
}

// ---------------------------------------------------------------------------
// Monthly Report (aggregated across sessions, 30 days)
// ---------------------------------------------------------------------------

/** A summary report covering a 30-day window. */
export interface MonthlyReport {
  periodStart: Timestamp;
  periodEnd: Timestamp;
  sessionCount: number;
  totalTimeMs: number;
  productiveTimeMs: number;
  neutralTimeMs: number;
  distractionTimeMs: number;
  /** Average drift score across sessions (0-100). */
  averageDriftScore: number;
  topDomains: { domain: string; timeMs: number }[];
  /** Weekly trend: drift scores per week for sparkline. */
  weeklyTrend: { weekStart: Timestamp; driftScore: number; totalMs: number }[];
  /** Daily average active time (ms). */
  dailyAverageMs: number;
  /** The day with the lowest (best) average drift score. */
  bestDay: { date: Timestamp; driftScore: number } | null;
  /** The day with the highest (worst) average drift score. */
  worstDay: { date: Timestamp; driftScore: number } | null;
}
