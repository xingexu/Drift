import SwiftUI
import Combine

// MARK: - App State

/// Central observable model for the Drift application.
///
/// Owns user preferences, the active tracking session, and local session
/// history. All properties are `@Published` so SwiftUI views react to changes
/// automatically.
///
/// Drift has no account or cloud-sync state. Preferences and privacy-scrubbed
/// history are stored only in this macOS user's `UserDefaults` domain.
@MainActor
class AppState: ObservableObject {

    /// Shared singleton accessed throughout the app.
    static let shared = AppState()

    // MARK: - Navigation

    @Published var currentTab: Tab = .tracking

    // MARK: - Session

    @Published var session = SessionData()

    // MARK: - Focus Mode

    @Published var focusModeActive = false
    @Published var focusModeEndTime: Date?

    // MARK: - Focus Blocking (mirrored from FocusBlocker for UI binding)

    @Published var blockedSites: [String] = []
    @Published var focusBlockPassword: String?
    @Published var focusBlockEndTime: Date?
    @Published var focusBlockAttempts: Int = 0

    // MARK: - Preferences

    @Published var theme: AppTheme = .light
    /// Name of the active accent color preset. Persisted to UserDefaults key "accentColorName".
    @Published var accentColorName: String = "indigo"
    /// When `true`, views should suppress or minimise decorative animations.
    @Published var reduceMotion: Bool = false
    @Published var idleTimeout: Int = 300
    @Published var notificationsEnabled = true
    @Published var launchAtLogin = true
    @Published var density: String = "Spacious"      // "Compact", "Comfortable", "Spacious"
    @Published var classificationOverrides: [String: AppCategory] = [:]

    // MARK: - UI State

    @Published var hasOnboarded: Bool = false

    /// Possible root screens used during the launch flow.
    enum AppScreen { case welcome, onboarding, main }

    // MARK: - Stats

    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var totalTrackedMs: TimeInterval = 0

    // MARK: - Session History (local)

    @Published var pastSessions: [PastSession] = []

    /// Maximum number of past sessions retained on disk.
    private static let maxPastSessions = 200

    // MARK: - UserDefaults Keys

    /// Centralised string constants for every `UserDefaults` key the app
    /// touches. Prevents typo-induced bugs and makes auditing easy.
    private enum DefaultsKey {
        static let theme             = "drift_theme"
        static let accentColorName   = "accentColorName"
        static let reduceMotion      = "drift_reduce_motion"
        static let blockedSites      = "drift_blocked_sites"
        static let focusBlockAttempts = "drift_focus_block_attempts"
        static let idleTimeout       = "drift_idle_timeout"
        static let notifications     = "drift_notifications"
        static let launchLogin       = "drift_launch_login"
        static let hasOnboarded      = "drift_has_onboarded"
        static let pastSessions      = "drift_past_sessions"
        static let density           = "drift_density"
        static let classificationOverrides = "drift_classification_overrides"
        // Retired account/sync keys, removed during upgrade cleanup.
        static let retiredUser         = "drift_user"
        static let retiredAccessToken  = "drift_access_token"
        static let retiredRefreshToken = "drift_refresh_token"
    }

    // MARK: - Init

    private init() {
        purgeRetiredCloudState()
        loadFromDefaults()
        loadPastSessions()
        computeStats()
    }

    // MARK: - Persistence

    /// Restores local preferences from `UserDefaults`.
    func loadFromDefaults() {
        let defaults = UserDefaults.standard

        if let themeRaw = defaults.string(forKey: DefaultsKey.theme),
           let decoded = AppTheme(rawValue: themeRaw) {
            theme = decoded
        }

        if let savedAccent = defaults.string(forKey: DefaultsKey.accentColorName),
           DriftDesign.accents.contains(where: { $0.name == savedAccent }) {
            accentColorName = savedAccent
        }

        reduceMotion = defaults.object(forKey: DefaultsKey.reduceMotion) as? Bool ?? false

        if let savedSites = defaults.stringArray(forKey: DefaultsKey.blockedSites) {
            blockedSites = savedSites
        }
        focusBlockAttempts = defaults.integer(forKey: DefaultsKey.focusBlockAttempts)

        let savedTimeout = defaults.integer(forKey: DefaultsKey.idleTimeout)
        idleTimeout = savedTimeout > 0 ? savedTimeout : 300

        notificationsEnabled = defaults.object(forKey: DefaultsKey.notifications) as? Bool ?? true
        launchAtLogin        = defaults.object(forKey: DefaultsKey.launchLogin) as? Bool ?? true
        hasOnboarded         = defaults.bool(forKey: DefaultsKey.hasOnboarded)

        if let saved = defaults.string(forKey: DefaultsKey.density) { density = saved }

        if let data = defaults.data(forKey: DefaultsKey.classificationOverrides),
           let savedOverrides = try? JSONDecoder().decode([String: AppCategory].self, from: data) {
            classificationOverrides = savedOverrides
        }
    }

    /// Removes credentials and queued network payloads left by account-enabled
    /// builds. This is intentionally idempotent so retired secrets cannot
    /// reappear after a preferences restore.
    func purgeRetiredCloudState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DefaultsKey.retiredUser)
        defaults.removeObject(forKey: DefaultsKey.retiredAccessToken)
        defaults.removeObject(forKey: DefaultsKey.retiredRefreshToken)
        LocalCredentialStore.purgeRetiredCloudCredentials()

        let queueURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("net.drift.app", isDirectory: true)
            .appendingPathComponent("offline_queue.json")
        if let queueURL {
            try? FileManager.default.removeItem(at: queueURL)
        }
    }

    /// Updates and persists the selected appearance theme.
    func setTheme(_ theme: AppTheme) {
        self.theme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: DefaultsKey.theme)
    }

    /// Updates and persists the selected accent color name.
    func setAccentColor(_ name: String) {
        accentColorName = name
        UserDefaults.standard.set(name, forKey: DefaultsKey.accentColorName)
    }

    /// Updates and persists the reduce-motion preference.
    func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        UserDefaults.standard.set(enabled, forKey: DefaultsKey.reduceMotion)
    }

    /// Updates and persists the layout density preference.
    func setDensity(_ value: String) {
        density = value
        UserDefaults.standard.set(value, forKey: DefaultsKey.density)
    }

    func classificationOverride(for key: String) -> AppCategory? {
        classificationOverrides[key.lowercased()]
    }

    func setClassificationOverride(_ category: AppCategory, for key: String) {
        classificationOverrides[key.lowercased()] = category
        if let data = try? JSONEncoder().encode(classificationOverrides) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.classificationOverrides)
        }
    }

    func removeClassificationOverride(for key: String) {
        classificationOverrides.removeValue(forKey: key.lowercased())
        if let data = try? JSONEncoder().encode(classificationOverrides) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.classificationOverrides)
        }
    }

    /// Resolved `Color` for the currently selected accent preset.
    var accentColor: Color {
        DriftDesign.accents.first { $0.name == accentColorName }?.color ?? Color.accent
    }

    /// Marks onboarding as completed.
    func completeOnboarding() {
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: DefaultsKey.hasOnboarded)
    }

    // MARK: - Session History

    /// Archives the active session into ``pastSessions`` if it exceeds the
    /// minimum duration threshold (5 seconds).
    func saveCurrentSession() {
        guard session.totalMs > 5000 else { return }

        let past = PastSession(
            date: session.startTime ?? Date(),
            totalMs: session.totalMs,
            productiveMs: session.productiveMs,
            neutralMs: session.neutralMs,
            distractionMs: session.distractionMs,
            focusPercent: session.focusPercent,
            driftScore: session.driftScore,
            appCount: session.uniqueApps,
            topApps: session.topApps,
            events: session.events.map { $0.privacySanitized() }
        )

        pastSessions.insert(past, at: 0)
        if pastSessions.count > Self.maxPastSessions {
            pastSessions = Array(pastSessions.prefix(Self.maxPastSessions))
        }
        savePastSessions()
        computeStats()
    }

    func deleteHistory() {
        pastSessions.removeAll()
        session.reset()
        savePastSessions()
        computeStats()
    }

    private func savePastSessions() {
        if let data = try? JSONEncoder().encode(pastSessions) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.pastSessions)
        }
    }

    private func loadPastSessions() {
        if let data = UserDefaults.standard.data(forKey: DefaultsKey.pastSessions),
           let decoded = try? JSONDecoder().decode([PastSession].self, from: data) {
            pastSessions = decoded.map { $0.privacySanitized() }

            // Rewrite older history once so full URLs and window titles from
            // retired builds are no longer retained on disk.
            if let sanitizedData = try? JSONEncoder().encode(pastSessions),
               sanitizedData != data {
                UserDefaults.standard.set(sanitizedData, forKey: DefaultsKey.pastSessions)
            }
        }
    }

    /// Recomputes aggregate statistics from the session history.
    ///
    /// Called after loading or modifying ``pastSessions``.
    private func computeStats() {
        totalTrackedMs = pastSessions.reduce(0) { $0 + $1.totalMs }

        // Build a set of day-start dates for O(n) streak calculation.
        let calendar = Calendar.current
        let sessionDays = Set(pastSessions.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while sessionDays.contains(checkDate) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }
        currentStreak = streak
    }
}

// MARK: - Tab

/// Main sidebar navigation tabs.
enum Tab: String, CaseIterable, Identifiable {
    case tracking = "Today"
    case focus    = "Focus"
    case history  = "History"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .tracking: return "sun.max"
        case .focus:    return "scope"
        case .history:  return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - AppTheme

/// User-selectable appearance mode.
enum AppTheme: String, CaseIterable {
    case light, dark, system

    var label: String {
        switch self {
        case .light:  return "Light"
        case .dark:   return "Dark"
        case .system: return "System"
        }
    }

    var icon: String {
        switch self {
        case .light:  return "sun.max"
        case .dark:   return "moon"
        case .system: return "desktopcomputer"
        }
    }
}

// MARK: - Session Data

/// Mutable value type that accumulates metrics for the active tracking session.
struct SessionData {
    var isActive = false
    var startTime: Date?
    var totalMs: TimeInterval = 0
    var productiveMs: TimeInterval = 0
    var neutralMs: TimeInterval = 0
    var distractionMs: TimeInterval = 0
    var events: [AppEvent] = []
    var currentApp: String = ""
    var currentCategory: AppCategory = .neutral

    /// Drift score: percentage of classified time spent on distractions (0--100).
    var driftScore: Int {
        let classified = productiveMs + distractionMs
        guard classified > 0 else { return 0 }
        return Int((distractionMs / classified) * 100)
    }

    /// Focus percentage: productive time as a share of total time (0--100).
    var focusPercent: Int {
        guard totalMs > 0 else { return 0 }
        return Int((productiveMs / totalMs) * 100)
    }

    /// Number of distinct applications observed in this session.
    var uniqueApps: Int {
        Set(events.map(\.owner)).count
    }

    /// Up to five most-used applications, ordered by event frequency.
    var topApps: [String] {
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.owner, default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key)
    }

    var contextSwitchCount: Int {
        max(events.count - 1, 0)
    }

    var longestProductiveStreakMs: TimeInterval {
        var longest: TimeInterval = 0
        var current: TimeInterval = 0

        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            if event.category == .productive {
                current += event.durationMs
                longest = max(longest, current)
            } else {
                current = 0
            }
        }

        return longest
    }

    var efficiencyScore: Int {
        guard totalMs > 0 else { return 0 }

        let productiveShare = min(max(productiveMs / totalMs, 0), 1)
        let distractionShare = min(max(distractionMs / totalMs, 0), 1)
        let sessionHours = max(totalMs / 3_600_000, 1.0 / 60.0)
        let switchesPerHour = Double(contextSwitchCount) / sessionHours
        let continuity = max(0, 1 - min(switchesPerHour / 40, 1))
        let deepWork = min(longestProductiveStreakMs / 2_700_000, 1)
        let score = productiveShare * 0.45
            + (1 - distractionShare) * 0.25
            + continuity * 0.20
            + deepWork * 0.10

        return Int((score * 100).rounded())
    }

    /// Resets all fields to their initial values.
    mutating func reset() {
        self = SessionData()
    }
}

// MARK: - AppEvent

/// A single app-usage event recorded during a tracking session.
struct AppEvent: Identifiable, Codable {
    let id: UUID
    let owner: String
    let title: String
    let isBrowser: Bool
    let url: String?
    let category: AppCategory
    let timestamp: Date
    var durationMs: TimeInterval

    init(
        id: UUID = UUID(),
        owner: String,
        title: String,
        isBrowser: Bool,
        url: String?,
        category: AppCategory,
        timestamp: Date,
        durationMs: TimeInterval
    ) {
        self.id = id
        self.owner = owner
        self.isBrowser = isBrowser
        let safeDomain = Self.domainOnly(from: url)
        self.title = isBrowser ? (safeDomain ?? owner) : owner
        self.url = safeDomain
        self.category = category
        self.timestamp = timestamp
        self.durationMs = durationMs
    }

    /// Returns an event safe for local persistence and export. Window titles,
    /// URL paths, query strings, fragments, usernames, and ports are discarded.
    func privacySanitized() -> AppEvent {
        AppEvent(
            id: id,
            owner: owner,
            title: title,
            isBrowser: isBrowser,
            url: url,
            category: category,
            timestamp: timestamp,
            durationMs: durationMs
        )
    }

    private static func domainOnly(from value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let candidate = value.contains("://") ? value : "https://\(value)"
        guard let host = URLComponents(string: candidate)?.host?.lowercased(),
              !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

// MARK: - PastSession

/// An archived tracking session stored in the user's local history.
struct PastSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let totalMs: TimeInterval
    let productiveMs: TimeInterval
    let neutralMs: TimeInterval
    let distractionMs: TimeInterval
    let focusPercent: Int
    let driftScore: Int
    let appCount: Int
    let topApps: [String]
    let events: [AppEvent]?

    init(
        id: UUID = UUID(),
        date: Date,
        totalMs: TimeInterval,
        productiveMs: TimeInterval,
        neutralMs: TimeInterval,
        distractionMs: TimeInterval,
        focusPercent: Int,
        driftScore: Int,
        appCount: Int,
        topApps: [String] = [],
        events: [AppEvent]? = nil
    ) {
        self.id = id
        self.date = date
        self.totalMs = totalMs
        self.productiveMs = productiveMs
        self.neutralMs = neutralMs
        self.distractionMs = distractionMs
        self.focusPercent = focusPercent
        self.driftScore = driftScore
        self.appCount = appCount
        self.topApps = topApps
        self.events = events
    }

    func privacySanitized() -> PastSession {
        PastSession(
            id: id,
            date: date,
            totalMs: totalMs,
            productiveMs: productiveMs,
            neutralMs: neutralMs,
            distractionMs: distractionMs,
            focusPercent: focusPercent,
            driftScore: driftScore,
            appCount: appCount,
            topApps: topApps,
            events: events?.map { $0.privacySanitized() }
        )
    }

    var efficiencyScore: Int {
        guard totalMs > 0 else { return 0 }
        let productiveShare = min(max(productiveMs / totalMs, 0), 1)
        let distractionShare = min(max(distractionMs / totalMs, 0), 1)
        return Int(((productiveShare * 0.65 + (1 - distractionShare) * 0.35) * 100).rounded())
    }
}

// MARK: - AppCategory

/// Productivity classification for an application or web domain.
enum AppCategory: String, Codable, CaseIterable {
    case productive, neutral, distraction

    var color: Color {
        switch self {
        case .productive:  return .productive
        case .neutral:     return .driftMuted
        case .distraction: return .distraction
        }
    }

    var label: String {
        switch self {
        case .productive:  return "Productive"
        case .neutral:     return "Neutral"
        case .distraction: return "Distraction"
        }
    }
}

// MARK: - Brand Color

extension Color {
    /// Drift brand blue #9DC3FD -- use instead of `.accentColor` for SPM builds.
    static let drift = Color(red: 157.0 / 255.0, green: 195.0 / 255.0, blue: 253.0 / 255.0)
}

// MARK: - Shared Formatters

/// Formats a millisecond duration as "H:MM:SS" or "M:SS".
func formatDuration(_ ms: TimeInterval) -> String {
    let sec = Int(ms / 1000)
    let h = sec / 3600
    let m = (sec % 3600) / 60
    let s = sec % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

/// Formats a millisecond duration as a human-readable string (e.g. "2h 15m").
func formatDurationWords(_ ms: TimeInterval) -> String {
    let sec = Int(ms / 1000)
    let h = sec / 3600
    let m = (sec % 3600) / 60
    if h > 0 && m > 0 { return "\(h)h \(m)m" }
    if h > 0 { return "\(h)h" }
    if m > 0 { return "\(m)m" }
    return "\(sec)s"
}
