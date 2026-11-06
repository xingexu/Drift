import Foundation
import SQLite3

// MARK: - Labeling Data Types

/// The three-way relevance label a user assigns to a segment, relative to the
/// goal they typed at session start.
enum GoalLabel: String, CaseIterable, Codable {
    case onGoal = "on_goal"
    case supporting = "supporting"
    case offGoal = "off_goal"

    var displayName: String {
        switch self {
        case .onGoal: return "On goal"
        case .supporting: return "Supporting"
        case .offGoal: return "Off goal"
        }
    }

    /// Keyboard shortcut used in the review view (1/2/3).
    var shortcut: Character {
        switch self {
        case .onGoal: return "1"
        case .supporting: return "2"
        case .offGoal: return "3"
        }
    }
}

/// One 60-second slice of activity, represented by its dominant window.
struct LabelingSegment: Identifiable, Equatable {
    let id: Int64
    let sessionId: String
    let timestamp: Date
    let bundleId: String
    let app: String
    let domain: String?
    let title: String
    let dwellSeconds: Double
    var label: GoalLabel?
}

/// A segment that has not been written yet.
struct PendingSegment: Equatable {
    let timestamp: Date
    let bundleId: String
    let app: String
    let domain: String?
    let title: String
    let dwellSeconds: Double
}

enum LabelingStoreError: Error {
    case open(String)
    case statement(String)
}

// MARK: - Labeling Store

/// Opt-in, local-only SQLite store for goal-relevance labeling data.
///
/// Unlike session history, this store keeps raw window titles, because the
/// titles are the input the goal-relevance model is evaluated on. It lives in
/// its own file so "Delete History" and "Reset All Data" can remove it in one
/// step, and nothing is written unless the user turns labeling mode on.
final class LabelingStore {
    static let defaultURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Drift", isDirectory: true)
            .appendingPathComponent("labeling.sqlite")
    }()

    private let url: URL
    private var db: OpaquePointer?

    init(url: URL = LabelingStore.defaultURL) {
        self.url = url
    }

    deinit { close() }

    // MARK: Lifecycle

    private func connection() throws -> OpaquePointer {
        if let db { return db }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw LabelingStoreError.open(message)
        }
        db = handle
        try exec("""
            PRAGMA journal_mode = WAL;
            PRAGMA foreign_keys = ON;
            CREATE TABLE IF NOT EXISTS sessions (
                session_id TEXT PRIMARY KEY,
                user_id    TEXT NOT NULL,
                goal       TEXT NOT NULL DEFAULT '',
                started_at REAL NOT NULL,
                ended_at   REAL
            );
            CREATE TABLE IF NOT EXISTS segments (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
                ts         REAL NOT NULL,
                bundle_id  TEXT NOT NULL,
                app        TEXT NOT NULL,
                domain     TEXT,
                title      TEXT NOT NULL,
                dwell_s    REAL NOT NULL,
                label      TEXT CHECK (label IN ('on_goal', 'supporting', 'off_goal')),
                labeled_at REAL
            );
            CREATE INDEX IF NOT EXISTS segments_session ON segments(session_id, ts);
            """)
        return handle
    }

    func close() {
        if let db { sqlite3_close(db) }
        db = nil
    }

    /// Deletes the database file and its WAL side files.
    func wipe() {
        close()
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    // MARK: Writes

    func beginSession(id: String, userId: String, goal: String, startedAt: Date) throws {
        try run(
            "INSERT OR IGNORE INTO sessions (session_id, user_id, goal, started_at) VALUES (?, ?, ?, ?)",
            [.text(id), .text(userId), .text(goal), .real(startedAt.timeIntervalSince1970)]
        )
    }

    func setGoal(_ goal: String, sessionId: String) throws {
        try run("UPDATE sessions SET goal = ? WHERE session_id = ?", [.text(goal), .text(sessionId)])
    }

    func endSession(id: String, endedAt: Date) throws {
        try run(
            "UPDATE sessions SET ended_at = ? WHERE session_id = ?",
            [.real(endedAt.timeIntervalSince1970), .text(id)]
        )
    }

    func insert(_ segment: PendingSegment, sessionId: String) throws {
        try run(
            """
            INSERT INTO segments (session_id, ts, bundle_id, app, domain, title, dwell_s)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(sessionId),
                .real(segment.timestamp.timeIntervalSince1970),
                .text(segment.bundleId),
                .text(segment.app),
                segment.domain.map(Value.text) ?? .null,
                .text(segment.title),
                .real(segment.dwellSeconds),
            ]
        )
    }

    func setLabel(_ label: GoalLabel?, segmentId: Int64, at date: Date = Date()) throws {
        try run(
            "UPDATE segments SET label = ?, labeled_at = ? WHERE id = ?",
            [
                label.map { .text($0.rawValue) } ?? .null,
                label == nil ? .null : .real(date.timeIntervalSince1970),
                .int(segmentId),
            ]
        )
    }

    // MARK: Reads

    func goal(sessionId: String) throws -> String? {
        try query("SELECT goal FROM sessions WHERE session_id = ?", [.text(sessionId)]) {
            Self.text($0, 0) ?? ""
        }.first
    }

    func segments(sessionId: String) throws -> [LabelingSegment] {
        try query(
            """
            SELECT id, session_id, ts, bundle_id, app, domain, title, dwell_s, label
            FROM segments WHERE session_id = ? ORDER BY ts
            """,
            [.text(sessionId)]
        ) { row in
            LabelingSegment(
                id: sqlite3_column_int64(row, 0),
                sessionId: Self.text(row, 1) ?? "",
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(row, 2)),
                bundleId: Self.text(row, 3) ?? "",
                app: Self.text(row, 4) ?? "",
                domain: Self.text(row, 5),
                title: Self.text(row, 6) ?? "",
                dwellSeconds: sqlite3_column_double(row, 7),
                label: Self.text(row, 8).flatMap(GoalLabel.init(rawValue:))
            )
        }
    }

    /// Most recent session that still has unlabeled segments, if any.
    func latestSessionNeedingReview() throws -> String? {
        try query(
            """
            SELECT s.session_id FROM sessions s
            JOIN segments g ON g.session_id = s.session_id
            WHERE s.ended_at IS NOT NULL AND g.label IS NULL
            GROUP BY s.session_id ORDER BY s.started_at DESC LIMIT 1
            """,
            []
        ) { Self.text($0, 0) }.compactMap { $0 }.first
    }

    func labeledCount() throws -> Int {
        try query("SELECT COUNT(*) FROM segments WHERE label IS NOT NULL", []) {
            Int(sqlite3_column_int64($0, 0))
        }.first ?? 0
    }

    /// CSV in the column layout the offline evaluation harness expects:
    /// `goal,title,app,bundle_id,domain,dwell_s,ts,label,user_id,session_id`.
    /// Only labeled segments from sessions with a goal are exported.
    func exportCSV() throws -> String {
        let header = "goal,title,app,bundle_id,domain,dwell_s,ts,label,user_id,session_id"
        let rows = try query(
            """
            SELECT s.goal, g.title, g.app, g.bundle_id, g.domain, g.dwell_s, g.ts, g.label,
                   s.user_id, s.session_id
            FROM segments g JOIN sessions s ON s.session_id = g.session_id
            WHERE g.label IS NOT NULL AND s.goal <> ''
            ORDER BY g.ts
            """,
            []
        ) { row -> String in
            let iso = ISO8601DateFormatter().string(
                from: Date(timeIntervalSince1970: sqlite3_column_double(row, 6))
            )
            let fields: [String] = [
                Self.text(row, 0) ?? "",
                Self.text(row, 1) ?? "",
                Self.text(row, 2) ?? "",
                Self.text(row, 3) ?? "",
                Self.text(row, 4) ?? "",
                String(format: "%.1f", sqlite3_column_double(row, 5)),
                iso,
                Self.text(row, 7) ?? "",
                Self.text(row, 8) ?? "",
                Self.text(row, 9) ?? "",
            ]
            return fields.map(Self.csvEscape).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    static func csvEscape(_ field: String) -> String {
        // Neutralise spreadsheet formula injection from web-page-controlled
        // titles. "-" is left alone: it is common in real titles and rarely
        // starts a formula on its own.
        var value = field
        if let first = value.first, "=+@\t\r".contains(first) { value = "'" + value }
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: SQLite Plumbing

    private enum Value {
        case text(String), real(Double), int(Int64), null
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private static func text(_ row: OpaquePointer, _ column: Int32) -> String? {
        guard let cString = sqlite3_column_text(row, column) else { return nil }
        return String(cString: cString)
    }

    private func exec(_ sql: String) throws {
        guard let db else { return }
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(error)
            throw LabelingStoreError.statement(message)
        }
    }

    private func prepare(_ sql: String, _ values: [Value]) throws -> OpaquePointer {
        let db = try connection()
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw LabelingStoreError.statement(String(cString: sqlite3_errmsg(db)))
        }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case .text(let string): sqlite3_bind_text(statement, index, string, -1, Self.transient)
            case .real(let number): sqlite3_bind_double(statement, index, number)
            case .int(let number): sqlite3_bind_int64(statement, index, number)
            case .null: sqlite3_bind_null(statement, index)
            }
        }
        return statement
    }

    private func run(_ sql: String, _ values: [Value]) throws {
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw LabelingStoreError.statement(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query<T>(_ sql: String, _ values: [Value], map: (OpaquePointer) -> T) throws -> [T] {
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }
        var results: [T] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_ROW {
                results.append(map(statement))
            } else if status == SQLITE_DONE {
                return results
            } else {
                throw LabelingStoreError.statement(String(cString: sqlite3_errmsg(db)))
            }
        }
    }
}
