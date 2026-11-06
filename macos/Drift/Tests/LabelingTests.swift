import XCTest
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
        try store.beginSession(id: "s1", userId: "u1", goal: "", startedAt: Date())
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
        XCTAssertEqual(lines[0], "goal,title,app,bundle_id,domain,dwell_s,ts,label,user_id,session_id")
        XCTAssertTrue(lines[1].hasPrefix("Finish the Q3 report,No goal yet,Chrome,com.google.Chrome,docs.google.com,42.0,"))
        XCTAssertTrue(lines[1].hasSuffix(",off_goal,u1,s1"))
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
