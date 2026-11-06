import Foundation
import Combine

// MARK: - Segment Accumulator

/// Turns 1-second foreground samples into fixed-length segments, each
/// represented by the window that held focus the longest within it.
///
/// Pure value type so the bucketing rules can be unit tested without timers.
struct SegmentAccumulator {
    struct Key: Hashable {
        let bundleId: String
        let app: String
        let domain: String?
        let title: String
    }

    /// Segment length in seconds.
    let length: TimeInterval
    /// Partial segments (on pause/stop) shorter than this are dropped.
    let minimumDominantDwell: TimeInterval
    /// Gaps between samples longer than this (sleep, stalled timer) are not
    /// counted as dwell time.
    let maximumSampleGap: TimeInterval

    private(set) var bucketStart: Date?
    private var lastSample: Date?
    private var dwell: [Key: TimeInterval] = [:]
    private var firstSeen: [Key: Date] = [:]

    init(length: TimeInterval = 60, minimumDominantDwell: TimeInterval = 10, maximumSampleGap: TimeInterval = 5) {
        self.length = length
        self.minimumDominantDwell = minimumDominantDwell
        self.maximumSampleGap = maximumSampleGap
    }

    /// Records that `key` was in the foreground at `now`. Returns a completed
    /// segment when this sample closes the current bucket.
    mutating func sample(_ key: Key, at now: Date) -> PendingSegment? {
        var completed: PendingSegment?
        if let start = bucketStart, now.timeIntervalSince(start) >= length {
            completed = dominant(minimumDwell: 0)
            // Keep the sample clock so the interval spanning the boundary is
            // credited to the new bucket instead of being lost.
            let carried = lastSample
            reset()
            lastSample = carried
        }
        if bucketStart == nil { bucketStart = now }

        if let last = lastSample {
            let delta = now.timeIntervalSince(last)
            if delta > 0, delta <= maximumSampleGap {
                dwell[key, default: 0] += delta
            }
        }
        if firstSeen[key] == nil { firstSeen[key] = now }
        lastSample = now
        return completed
    }

    /// Closes the current (possibly partial) bucket, e.g. on pause or stop.
    mutating func flush() -> PendingSegment? {
        defer { reset() }
        return dominant(minimumDwell: minimumDominantDwell)
    }

    private func dominant(minimumDwell: TimeInterval) -> PendingSegment? {
        guard let start = bucketStart,
              let (key, seconds) = dwell.max(by: { lhs, rhs in
                  lhs.value == rhs.value
                      ? (firstSeen[lhs.key] ?? .distantFuture) > (firstSeen[rhs.key] ?? .distantFuture)
                      : lhs.value < rhs.value
              }),
              seconds > 0, seconds >= minimumDwell
        else { return nil }
        return PendingSegment(
            timestamp: start,
            bundleId: key.bundleId,
            app: key.app,
            domain: key.domain,
            title: key.title,
            dwellSeconds: seconds
        )
    }

    private mutating func reset() {
        bucketStart = nil
        lastSample = nil
        dwell.removeAll()
        firstSeen.removeAll()
    }
}

// MARK: - Labeling Recorder

/// Coordinates opt-in labeling mode: captures goal-tagged segments while a
/// session runs and surfaces the end-of-session review.
@MainActor
final class LabelingRecorder: ObservableObject {
    static let shared = LabelingRecorder()

    private enum Keys {
        static let enabled = "drift_labeling_enabled"
        static let userId = "drift_labeling_user_id"
    }

    /// Opt-in switch. Off by default; nothing is recorded while off.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            if isEnabled, !oldValue, activeSessionId == nil, WindowTracker.shared.isTracking {
                // Turned on mid-session: start labeling now instead of
                // silently dropping samples until the next session.
                sessionDidStart()
            } else if !isEnabled {
                finishSession()
            }
        }
    }
    /// Session that should prompt for a goal (set when a labeled session starts).
    @Published var sessionNeedingGoal: String?
    /// Session whose segments are ready for 1/2/3 review.
    @Published var sessionNeedingReview: String?
    @Published private(set) var activeGoal = ""
    @Published private(set) var lastError: String?

    /// True while the goal prompt or review UI is on screen, so global
    /// single-key shortcuts must step aside.
    var isCapturingKeys: Bool { sessionNeedingGoal != nil || sessionNeedingReview != nil }

    let store: LabelingStore
    private var activeSessionId: String?
    private var accumulator = SegmentAccumulator()

    /// Random, install-local identifier so exported data can be split by
    /// person. It is not derived from any account or hardware identifier.
    var userId: String {
        if let existing = UserDefaults.standard.string(forKey: Keys.userId) { return existing }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: Keys.userId)
        return created
    }

    init(store: LabelingStore = LabelingStore()) {
        self.store = store
        self.isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        // A crash or force-quit leaves the previous session open (ended_at
        // NULL), which hides it from review forever. The recorder is created
        // before any session starts in this process, so every open session
        // here is abandoned.
        perform { try store.closeAbandonedSessions() }
    }

    // MARK: Session Lifecycle (called by WindowTracker)

    func sessionDidStart(at date: Date = Date()) {
        guard isEnabled else { return }
        finishSession()
        let id = UUID().uuidString
        perform { try store.beginSession(id: id, userId: userId, goal: "", startedAt: date) }
        activeSessionId = id
        activeGoal = ""
        sessionNeedingGoal = id
    }

    /// One foreground sample from the 1-second poll.
    func sample(app: String, bundleId: String?, title: String, url: String?, at date: Date = Date()) {
        guard isEnabled, let sessionId = activeSessionId else { return }
        let key = SegmentAccumulator.Key(
            bundleId: bundleId ?? "",
            app: app,
            domain: Self.domain(from: url),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if let segment = accumulator.sample(key, at: date) {
            perform { try store.insert(segment, sessionId: sessionId) }
        }
    }

    /// Closes the in-progress segment (pause, idle).
    func flushSegment() {
        guard let sessionId = activeSessionId, let segment = accumulator.flush() else { return }
        perform { try store.insert(segment, sessionId: sessionId) }
    }

    /// Ends the labeled session and queues it for review if it has segments.
    func finishSession(at date: Date = Date()) {
        guard let sessionId = activeSessionId else { return }
        flushSegment()
        perform { try store.endSession(id: sessionId, endedAt: date) }
        activeSessionId = nil
        if sessionNeedingGoal == sessionId { sessionNeedingGoal = nil }
        let hasSegments = (try? store.segments(sessionId: sessionId).isEmpty == false) ?? false
        if isEnabled, hasSegments { sessionNeedingReview = sessionId }
    }

    // MARK: Labeling Actions (called by views)

    func setGoal(_ goal: String, for sessionId: String) {
        let trimmed = String(goal.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        perform { try store.setGoal(trimmed, sessionId: sessionId) }
        if sessionId == activeSessionId { activeGoal = trimmed }
        if sessionNeedingGoal == sessionId { sessionNeedingGoal = nil }
    }

    func skipGoal() { sessionNeedingGoal = nil }

    func setLabel(_ label: GoalLabel?, segmentId: Int64) {
        perform { try store.setLabel(label, segmentId: segmentId) }
    }

    func closeReview() { sessionNeedingReview = nil }

    /// Opens review for the newest session that still has unlabeled segments.
    func reviewPending() {
        sessionNeedingReview = (try? store.latestSessionNeedingReview()) ?? nil
    }

    /// Removes all labeling data. Called from Delete History / Reset All Data.
    func wipeAll() {
        activeSessionId = nil
        accumulator = SegmentAccumulator()
        sessionNeedingGoal = nil
        sessionNeedingReview = nil
        activeGoal = ""
        store.wipe()
    }

    // MARK: Helpers

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
            lastError = nil
        } catch {
            lastError = String(describing: error)
            print("[Labeling] \(error)")
        }
    }

    static func domain(from value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let candidate = value.contains("://") ? value : "https://\(value)"
        guard let host = URLComponents(string: candidate)?.host?.lowercased(), !host.isEmpty else {
            return nil
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
