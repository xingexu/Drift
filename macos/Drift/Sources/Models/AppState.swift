import SwiftUI
import Combine

// MARK: - App State

/// Central observable model for the Drift application.
///
/// Owns authentication state, user preferences, the active tracking session,
/// and session history. All properties are `@Published` so SwiftUI views
/// react to changes automatically.
///
/// Persistence is split between `UserDefaults` (preferences, session history)
/// and the system Keychain (authentication tokens). The singleton is created
/// lazily on first access and restores its last-known state from disk.
@MainActor
class AppState: ObservableObject {

    /// Shared singleton accessed throughout the app.
    static let shared = AppState()

    // MARK: - Auth

    @Published var isLoggedIn: Bool = false
    @Published var user: User?
    @Published var accessToken: String?

    // MARK: - Navigation

    @Published var currentTab: Tab = .home

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

    @Published var theme: AppTheme = .system
    @Published var idleTimeout: Int = 300
    @Published var notificationsEnabled = true
    @Published var launchAtLogin = true

    // MARK: - UI State

    @Published var showSignIn = false
    @Published var hasOnboarded: Bool = false

    /// Possible root screens used during the launch flow.
    enum AppScreen { case welcome, onboarding, auth, main }

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
        static let user              = "drift_user"
        static let theme             = "drift_theme"
        static let blockedSites      = "drift_blocked_sites"
        static let focusBlockAttempts = "drift_focus_block_attempts"
        static let idleTimeout       = "drift_idle_timeout"
        static let notifications     = "drift_notifications"
        static let launchLogin       = "drift_launch_login"
        static let hasOnboarded      = "drift_has_onboarded"
        static let pastSessions      = "drift_past_sessions"
        // Legacy keys used only during the one-time keychain migration.
        static let legacyAccessToken  = "drift_access_token"
        static let legacyRefreshToken = "drift_refresh_token"
    }

    /// Keychain item identifiers for authentication tokens.
    private enum KeychainKey {
        static let accessToken  = "drift_access_token"
        static let refreshToken = "drift_refresh_token"
    }

    // MARK: - Init

    private init() {
        loadFromDefaults()
        loadPastSessions()
        computeStats()
    }

    // MARK: - Persistence

    /// Restores all persisted properties from `UserDefaults` and Keychain.
    func loadFromDefaults() {
        let defaults = UserDefaults.standard

        // One-time migration: move tokens from UserDefaults into Keychain and
        // remove the plaintext copies from the plist.
        migrateTokensToKeychainIfNeeded()

        // Load tokens from Keychain.
        accessToken = KeychainHelper.read(key: KeychainKey.accessToken)
        isLoggedIn = accessToken != nil

        if let userData = defaults.data(forKey: DefaultsKey.user),
           let decoded = try? JSONDecoder().decode(User.self, from: userData) {
            user = decoded
        }

        if let themeRaw = defaults.string(forKey: DefaultsKey.theme),
           let decoded = AppTheme(rawValue: themeRaw) {
            theme = decoded
        }

        if let savedSites = defaults.stringArray(forKey: DefaultsKey.blockedSites) {
            blockedSites = savedSites
        }
        focusBlockAttempts = defaults.integer(forKey: DefaultsKey.focusBlockAttempts)

        let savedTimeout = defaults.integer(forKey: DefaultsKey.idleTimeout)
        idleTimeout = savedTimeout > 0 ? savedTimeout : 300

        notificationsEnabled = defaults.object(forKey: DefaultsKey.notifications) as? Bool ?? true
        launchAtLogin        = defaults.object(forKey: DefaultsKey.launchLogin) as? Bool ?? true
        hasOnboarded         = defaults.bool(forKey: DefaultsKey.hasOnboarded)
    }

    /// Moves any tokens still sitting in `UserDefaults` into the Keychain.
    ///
    /// This runs on every launch but is effectively a no-op once the legacy
    /// keys have been deleted.
    private func migrateTokensToKeychainIfNeeded() {
        let defaults = UserDefaults.standard
        if let access = defaults.string(forKey: DefaultsKey.legacyAccessToken) {
            KeychainHelper.save(key: KeychainKey.accessToken, value: access)
            defaults.removeObject(forKey: DefaultsKey.legacyAccessToken)
        }
        if let refresh = defaults.string(forKey: DefaultsKey.legacyRefreshToken) {
            KeychainHelper.save(key: KeychainKey.refreshToken, value: refresh)
            defaults.removeObject(forKey: DefaultsKey.legacyRefreshToken)
        }
    }

    /// Persists new authentication tokens to the Keychain.
    func saveTokens(access: String, refresh: String) {
        KeychainHelper.save(key: KeychainKey.accessToken, value: access)
        KeychainHelper.save(key: KeychainKey.refreshToken, value: refresh)
        accessToken = access
        isLoggedIn = true
    }

    /// Called by `APIClient` or `AppDelegate` after a successful silent
    /// token refresh to persist the rotated credentials.
    func handleTokenRefresh(accessToken: String, refreshToken: String) {
        saveTokens(access: accessToken, refresh: refreshToken)
    }

    /// Persists the user profile to `UserDefaults`.
    func saveUser(_ user: User) {
        self.user = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.user)
        }
    }

    /// Clears all authentication state and removes persisted credentials
    /// from both the Keychain and `UserDefaults`.
    func logout() {
        KeychainHelper.delete(key: KeychainKey.accessToken)
        KeychainHelper.delete(key: KeychainKey.refreshToken)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.user)
        accessToken = nil
        user = nil
        isLoggedIn = false
    }

    /// Updates and persists the selected appearance theme.
    func setTheme(_ theme: AppTheme) {
        self.theme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: DefaultsKey.theme)
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
            topApps: session.topApps
        )

        pastSessions.insert(past, at: 0)
        if pastSessions.count > Self.maxPastSessions {
            pastSessions = Array(pastSessions.prefix(Self.maxPastSessions))
        }
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
            pastSessions = decoded
        }
    }

    /// Recomputes aggregate statistics from the session history.
    ///
    /// Called after loading or modifying ``pastSessions``.
    private func computeStats() {
        totalTrackedMs = pastSessions.reduce(0) { $0 + $1.totalMs }

        // Calculate streak: consecutive calendar days with at least one session.
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while true {
            let hasSession = pastSessions.contains { session in
                calendar.isDate(session.date, inSameDayAs: checkDate)
            }
            guard hasSession else { break }
            streak += 1
            // Safe date arithmetic -- break instead of force-unwrapping.
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }
        currentStreak = streak
    }
}

// MARK: - User

/// Represents an authenticated Drift user.
struct User: Codable, Identifiable {
    let userId: String
    let email: String
    var name: String?
    var plan: String

    var id: String { userId }

    /// Best-effort display name derived from the user's name or email prefix.
    var displayName: String {
        name ?? email.components(separatedBy: "@").first ?? email
    }

    /// Two-character uppercase initials for avatar placeholders.
    var initials: String {
        let parts = displayName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}

// MARK: - Tab

/// Main sidebar navigation tabs.
enum Tab: String, CaseIterable, Identifiable {
    case home     = "Home"
    case session  = "Session"
    case focus    = "Focus"
    case history  = "History"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home:     return "house"
        case .session:  return "chart.bar.fill"
        case .focus:    return "timer"
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

    /// Resets all fields to their initial values.
    mutating func reset() {
        self = SessionData()
    }
}

// MARK: - AppEvent

/// A single app-usage event recorded during a tracking session.
struct AppEvent: Identifiable {
    let id = UUID()
    let owner: String
    let title: String
    let isBrowser: Bool
    let url: String?
    let category: AppCategory
    let timestamp: Date
    var durationMs: TimeInterval
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

    init(
        date: Date,
        totalMs: TimeInterval,
        productiveMs: TimeInterval,
        neutralMs: TimeInterval,
        distractionMs: TimeInterval,
        focusPercent: Int,
        driftScore: Int,
        appCount: Int,
        topApps: [String] = []
    ) {
        self.id = UUID()
        self.date = date
        self.totalMs = totalMs
        self.productiveMs = productiveMs
        self.neutralMs = neutralMs
        self.distractionMs = distractionMs
        self.focusPercent = focusPercent
        self.driftScore = driftScore
        self.appCount = appCount
        self.topApps = topApps
    }
}

// MARK: - AppCategory

/// Productivity classification for an application or web domain.
enum AppCategory: String, Codable {
    case productive, neutral, distraction

    var color: Color {
        switch self {
        case .productive:  return Color("Green")
        case .neutral:     return Color("TextMuted")
        case .distraction: return Color("Red")
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
