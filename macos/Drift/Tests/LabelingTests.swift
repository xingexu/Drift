import XCTest
import SQLite3
@testable import Drift

final class SegmentAccumulatorTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let xcode = SegmentAccumulator.Key(bundleId: "com.apple.dt.Xcode", app: "Xcode", domain: nil, title: "Drift — WindowTracker.swift")
    private let reddit = SegmentAccumulator.Key(bundleId: "com.google.Chrome", app: "Chrome", domain: "reddit.com", title: "r/swift")

    func testEmitsDominantWindowWhenBucketCloses() {
        var acc = SegmentAccumulator(length: 60)
        // 40 s in Xcode, then 20 s on Reddit.
        for s in 0..<40 { XCTAssertNil(acc.sample(xcode, at: t0 + Double(s))) }
        for s in 40..<60 { XCTAssertNil(acc.sample(reddit, at: t0 + Double(s))) }

        let segment = acc.sample(reddit, at: t0 + 60)
        XCTAssertEqual(segment?.title, xcode.title)
        XCTAssertEqual(segment?.timestamp, t0)
        XCTAssertEqual(segment?.dwellSeconds ?? 0, 39, accuracy: 0.001)
        XCTAssertEqual(acc.bucketStart, t0 + 60)
    }

    func testBoundaryIntervalIsCreditedToNextBucket() {
        var acc = SegmentAccumulator(length: 60)
        for s in 0...60 { _ = acc.sample(reddit, at: t0 + Double(s)) }
        for s in 61..<120 { _ = acc.sample(reddit, at: t0 + Double(s)) }
        // Second bucket: samples at 60…120 → 60 s of dwell, nothing lost at the boundary.
        let second = acc.sample(reddit, at: t0 + 120)
        XCTAssertEqual(second?.dwellSeconds ?? 0, 60, accuracy: 0.001)
    }

    func testGapsLongerThanMaximumAreNotCountedAsDwell() {
        var acc = SegmentAccumulator(length: 600, minimumDominantDwell: 0, maximumSampleGap: 5)
        _ = acc.sample(xcode, at: t0)
        _ = acc.sample(xcode, at: t0 + 1)
        _ = acc.sample(xcode, at: t0 + 300) // Mac slept.
        XCTAssertEqual(acc.flush()?.dwellSeconds ?? 0, 1, accuracy: 0.001)
    }

    func testFlushDropsShortPartialSegments() {
        var acc = SegmentAccumulator(length: 60, minimumDominantDwell: 10)
        for s in 0..<5 { _ = acc.sample(xcode, at: t0 + Double(s)) }
        XCTAssertNil(acc.flush())

        for s in 0...12 { _ = acc.sample(xcode, at: t0 + 100 + Double(s)) }
        XCTAssertEqual(acc.flush()?.dwellSeconds ?? 0, 12, accuracy: 0.001)
        XCTAssertNil(acc.bucketStart)
    }
}

final class LabelingStoreTests: XCTestCase {
    private var url: URL!
    private var store: LabelingStore!

    override func setUp() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("drift-labeling-\(UUID().uuidString).sqlite")
        store = LabelingStore(url: url)
    }

    override func tearDown() {
        store.wipe()
    }

    private func segment(_ title: String, at offset: TimeInterval) -> PendingSegment {
        PendingSegment(
            timestamp: Date(timeIntervalSince1970: 1_800_000_000 + offset),
            bundleId: "com.google.Chrome", app: "Chrome", domain: "docs.google.com",
            title: title, dwellSeconds: 42
        )
    }

    func testRoundTripLabelsAndReviewQueue() throws {
        try store.beginSession(id: "s1", userId: "u1", goal: "Finish the Q3 report", startedAt: Date())
        try store.insert(segment("Q3 report", at: 0), sessionId: "s1")
        try store.insert(segment("Inbox", at: 60), sessionId: "s1")
        XCTAssertNil(try store.latestSessionNeedingReview(), "open sessions are not reviewed yet")

        try store.endSession(id: "s1", endedAt: Date())
        XCTAssertEqual(try store.latestSessionNeedingReview(), "s1")

        let rows = try store.segments(sessionId: "s1")
        XCTAssertEqual(rows.map(\.title), ["Q3 report", "Inbox"])
        try store.setLabel(.onGoal, segmentId: rows[0].id)
        try store.setLabel(.supporting, segmentId: rows[1].id)

        XCTAssertEqual(try store.segments(sessionId: "s1").map(\.label), [.onGoal, .supporting])
        XCTAssertNil(try store.latestSessionNeedingReview())
        XCTAssertEqual(try store.labeledCount(), 2)

        try store.setLabel(nil, segmentId: rows[1].id)
        XCTAssertEqual(try store.labeledCount(), 1)
    }

    func testExportOnlyIncludesLabeledRowsWithGoal() throws {
        try store.beginSession(id: "s1", userId: "u1", goal: "", startedAt: Date())
        try store.insert(segment("No goal yet", at: 0), sessionId: "s1")
        let first = try store.segments(sessionId: "s1")[0]
        try store.setLabel(.offGoal, segmentId: first.id)
        XCTAssertEqual(try store.exportCSV().split(separator: "\n").count, 1, "header only without a goal")

        try store.setGoal("Finish the Q3 report", sessionId: "s1")
        try store.insert(segment("Unlabeled, \"quoted\"", at: 60), sessionId: "s1")
        let lines = try store.exportCSV().split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], "goal,title,app,bundle_id,domain,dwell_s,ts,label,user_id,session_id,segment_id")
        XCTAssertTrue(lines[1].hasPrefix("Finish the Q3 report,No goal yet,Chrome,com.google.Chrome,docs.google.com,42.0,"))
        XCTAssertTrue(lines[1].contains(",2027-01-15T08:00:00Z,"), "ts is UTC so files from different time zones merge")
        XCTAssertNotNil(lines[1].range(of: #",off_goal,u1,s1,[0-9a-f-]{36}$"#, options: .regularExpression))
    }

    // MARK: Merging exports from many people

    private func exportedRows(_ store: LabelingStore, user: String, session: String) throws -> [[Substring]] {
        try store.beginSession(id: session, userId: user, goal: "Write the essay", startedAt: Date())
        for offset in [0.0, 60, 120] {
            try store.insert(segment("Essay draft", at: offset), sessionId: session)
        }
        for row in try store.segments(sessionId: session) { try store.setLabel(.onGoal, segmentId: row.id) }
        return try store.exportCSV().split(separator: "\n").dropFirst().map { $0.split(separator: ",") }
    }

    func testExportsFromDifferentInstallsMergeWithoutCollisions() throws {
        let otherURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("drift-labeling-\(UUID().uuidString).sqlite")
        let other = LabelingStore(url: otherURL)
        defer { other.wipe() }

        // Both installs number their rows 1, 2, 3 locally; the exported IDs must still differ.
        let mine = try exportedRows(store, user: "u1", session: "s1")
        let theirs = try exportedRows(other, user: "u2", session: "s2")
        XCTAssertEqual(try store.segments(sessionId: "s1").map(\.id), try other.segments(sessionId: "s2").map(\.id))

        let merged = mine + theirs
        XCTAssertEqual(Set(merged.map { $0.last! }).count, merged.count, "segment_id is unique across installs")
        XCTAssertEqual(Set(merged.map { $0[8] }), ["u1", "u2"])
    }

    func testReexportKeepsSegmentIDsSoDuplicatesCanBeDropped() throws {
        let first = try exportedRows(store, user: "u1", session: "s1")
        let second = try store.exportCSV().split(separator: "\n").dropFirst().map { $0.split(separator: ",") }
        XCTAssertEqual(first.map { $0.last! }, second.map { $0.last! })
    }

    func testMigrationBackfillsSegmentIDsInExistingDatabase() throws {
        // A database written before segment IDs existed (user_version 0, no uid column).
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        sqlite3_exec(db, """
            CREATE TABLE sessions (session_id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
                goal TEXT NOT NULL DEFAULT '', started_at REAL NOT NULL, ended_at REAL);
            CREATE TABLE segments (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT NOT NULL,
                ts REAL NOT NULL, bundle_id TEXT NOT NULL, app TEXT NOT NULL, domain TEXT,
                title TEXT NOT NULL, dwell_s REAL NOT NULL, label TEXT, labeled_at REAL);
            INSERT INTO sessions VALUES ('old', 'u1', 'g', 0, 1);
            INSERT INTO segments (session_id, ts, bundle_id, app, title, dwell_s, label)
                VALUES ('old', 0, 'b', 'A', 'T1', 30, 'on_goal'), ('old', 60, 'b', 'A', 'T2', 30, 'off_goal');
            """, nil, nil, nil)
        sqlite3_close(db)

        let rows = try store.exportCSV().split(separator: "\n").dropFirst().map { $0.split(separator: ",") }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows.map { $0.last! }).count, 2)
        XCTAssertTrue(rows.allSatisfy { $0.last!.count == 32 })
    }

    func testAbandonedSessionBecomesReviewable() throws {
        try store.beginSession(id: "crashed", userId: "u1", goal: "g", startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        try store.insert(segment("Draft", at: 0), sessionId: "crashed")
        XCTAssertNil(try store.latestSessionNeedingReview())

        try store.closeAbandonedSessions()
        XCTAssertEqual(try store.latestSessionNeedingReview(), "crashed")
    }

    func testClosingAbandonedSessionsDoesNotCreateFile() throws {
        try store.closeAbandonedSessions()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testGoallessLabeledSessionStaysReviewableAndIsCounted() throws {
        try store.beginSession(id: "s1", userId: "u1", goal: "", startedAt: Date())
        try store.insert(segment("Draft", at: 0), sessionId: "s1")
        try store.endSession(id: "s1", endedAt: Date())
        try store.setLabel(.onGoal, segmentId: try store.segments(sessionId: "s1")[0].id)

        // Fully labeled but goal-less: still surfaced for review, and counted as skipped.
        XCTAssertEqual(try store.latestSessionNeedingReview(), "s1")
        XCTAssertEqual(try store.goallessLabeledCount(), 1)

        try store.setGoal("Write the essay", sessionId: "s1")
        XCTAssertNil(try store.latestSessionNeedingReview())
        XCTAssertEqual(try store.goallessLabeledCount(), 0)
        XCTAssertEqual(try store.exportCSV().split(separator: "\n").count, 2)
    }

    func testWipeRemovesDatabase() throws {
        try store.beginSession(id: "s1", userId: "u1", goal: "g", startedAt: Date())
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        store.wipe()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try store.labeledCount(), 0, "store reopens empty after wipe")
    }

    func testCSVEscaping() {
        XCTAssertEqual(LabelingStore.csvEscape("plain"), "plain")
        XCTAssertEqual(LabelingStore.csvEscape("a,b"), "\"a,b\"")
        XCTAssertEqual(LabelingStore.csvEscape("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(LabelingStore.csvEscape("=HYPERLINK(\"x\")"), "\"'=HYPERLINK(\"\"x\"\")\"")
        XCTAssertEqual(LabelingStore.csvEscape("- notes"), "- notes")
    }
}
