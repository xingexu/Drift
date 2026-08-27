import SwiftUI
import Combine
import CryptoKit
@preconcurrency import UserNotifications

// MARK: - Focus Blocker

/// Manages focus-mode sessions that block distracting websites.
///
/// During an active session the blocker monitors the frontmost browser
/// window every second. When a blocked domain is detected the tab is
/// redirected to a local "blocked" page and Drift is brought to front.
///
/// Sessions survive app restarts via `UserDefaults`. The optional focus-lock
/// verifier is kept in the macOS Keychain rather than the preferences plist.
///
/// **Safety invariants**
/// - ``forceStopForEmergency()`` is always available and cannot deadlock.
/// - System apps (Finder, System Settings, etc.) are never blocked.
/// - Timer expiration triggers an automatic stop regardless of state.
@MainActor
class FocusBlocker: ObservableObject {

    // MARK: - Singleton

    static let shared = FocusBlocker()

    // MARK: - Published State

    @Published private(set) var isBlocking = false
    @Published private(set) var endTime: Date?
    @Published private(set) var blockedAttempts: Int = 0
    @Published private(set) var lastBlockedSite: String?
    @Published var blockedSites: [String] = []
    @Published private(set) var disabledSites: Set<String> = []

    // MARK: - Configuration

    /// Hard limits on focus-session duration (minutes).
    private static let minimumDurationMinutes = 1
    private static let maximumDurationMinutes = 480  // 8 hours

    /// Maximum number of blocked-site entries a user may configure.
    private static let maximumBlockedSites = 200

    /// Default list of distraction domains shipped with the app.
    static let defaultBlockedSites: [String] = [
        "twitter.com",
        "x.com",
        "reddit.com",
        "youtube.com",
        "instagram.com",
        "facebook.com",
        "tiktok.com",
        "twitch.tv",
        "discord.com",
        "9gag.com",
        "buzzfeed.com",
        "netflix.com",
    ]

    // MARK: - Internal State

    private var passwordHash: String?
    private var monitorTimer: Timer?
    private var totalSessionDuration: TimeInterval = 0
    private var notificationAuthorizationCached: Bool?

    /// Bundle IDs that must never be blocked, even if their window title
    /// accidentally matches a blocked domain name.
    private static let protectedBundleIds: Set<String> = [
        "com.apple.finder",
        "com.apple.systempreferences",      // macOS < 13
        "com.apple.SystemPreferences",
        "com.apple.systemsettings",          // macOS 13+
        "com.apple.ActivityMonitor",
        "com.apple.Console",
        "com.apple.Terminal",
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
    ]

    /// Browser display names used for window-title matching.
    private static let browserNames: [String] = [
        "safari", "chrome", "brave", "firefox", "edge",
        "arc", "opera", "vivaldi", "chromium", "orion",
    ]

    // MARK: - Computed Properties

    /// Whether the user must supply a password to end the session early.
    var passwordRequired: Bool {
        isBlocking && passwordHash != nil
    }

    /// Remaining seconds in the current focus session (clamped to >= 0).
    var timeRemainingSeconds: Int {
        guard let end = endTime else { return 0 }
        return max(0, Int(end.timeIntervalSinceNow))
    }

    /// Human-readable countdown string (e.g. "1:23:45" or "12:30").
    var timeRemainingFormatted: String {
        let total = timeRemainingSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Progress toward session completion as a value in 0...1.
    var progress: CGFloat {
        guard let end = endTime, totalSessionDuration > 0 else { return 0 }
        let remaining = max(0, end.timeIntervalSinceNow)
        return CGFloat(min(1.0, 1.0 - remaining / totalSessionDuration))
    }

    // MARK: - Init

    private init() {
        loadBlockedSites()
        restoreSession()
    }

    // MARK: - Blocked-Site Management

    /// Loads the user's blocked-site list from `UserDefaults`, falling back
    /// to ``defaultBlockedSites`` on first launch.
    private func loadBlockedSites() {
        if let saved = UserDefaults.standard.stringArray(forKey: "drift_blocked_sites") {
            blockedSites = saved
        } else {
            blockedSites = Self.defaultBlockedSites
            saveBlockedSites()
        }
        disabledSites = Set(UserDefaults.standard.stringArray(forKey: "drift_disabled_blocked_sites") ?? [])
    }

    /// Persists the current blocked-site list.
    func saveBlockedSites() {
        UserDefaults.standard.set(blockedSites, forKey: "drift_blocked_sites")
        UserDefaults.standard.set(Array(disabledSites), forKey: "drift_disabled_blocked_sites")
    }

    /// Adds a new domain to the block list after sanitisation.
    ///
    /// Input is trimmed, lowercased, and stripped of protocol/www prefixes.
    /// Empty strings, duplicates, and attempts to exceed the maximum list
    /// size are silently ignored.
    ///
    /// - Parameter site: A URL or bare domain string.
    func addSite(_ site: String) {
        let cleaned = sanitiseDomain(site)
        guard !cleaned.isEmpty,
              !blockedSites.contains(cleaned),
              blockedSites.count < Self.maximumBlockedSites else { return }
        blockedSites.append(cleaned)
        saveBlockedSites()
    }

    /// Removes a domain from the block list.
    func removeSite(_ site: String) {
        blockedSites.removeAll { $0 == site }
        disabledSites.remove(site)
        saveBlockedSites()
    }

    func isSiteEnabled(_ site: String) -> Bool {
        !disabledSites.contains(site)
    }

    func setSite(_ site: String, enabled: Bool) {
        if enabled {
            disabledSites.remove(site)
        } else {
            disabledSites.insert(site)
        }
        saveBlockedSites()
    }

    /// Resets the block list to the factory defaults.
    func resetToDefaults() {
        blockedSites = Self.defaultBlockedSites
        disabledSites.removeAll()
        saveBlockedSites()
    }

    /// Normalises a raw domain or URL into a canonical form for matching.
    private func sanitiseDomain(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Strip common URL prefixes.
        for prefix in ["https://", "http://", "www."] {
            if s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)) }
        }
        // Strip trailing path.
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        if let colon = s.firstIndex(of: ":") { s = String(s[..<colon]) }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "."))

        guard !s.isEmpty,
              s.count <= 253,
              !s.contains(".."),
              s.unicodeScalars.allSatisfy({
                  CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "."
              }),
              s.split(separator: ".").allSatisfy({ label in
                  !label.isEmpty && label.count <= 63 &&
                  label.first != "-" && label.last != "-"
              }) else {
            return ""
        }
        return s
    }

    // MARK: - Session Persistence (survives app restart)

    private func saveSession() {
        let defaults = UserDefaults.standard
        defaults.set(isBlocking, forKey: "drift_focus_block_active")
        if let end = endTime {
            defaults.set(end.timeIntervalSince1970, forKey: "drift_focus_block_end")
        }
        if let hash = passwordHash {
            LocalCredentialStore.save(hash, for: LocalCredentialStore.focusPasswordHashKey)
        } else {
            LocalCredentialStore.delete(LocalCredentialStore.focusPasswordHashKey)
        }
        defaults.set(totalSessionDuration, forKey: "drift_focus_block_duration")
        defaults.set(blockedAttempts, forKey: "drift_focus_block_attempts")
    }

    private func restoreSession() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "drift_focus_block_active") else { return }

        let endInterval = defaults.double(forKey: "drift_focus_block_end")
        guard endInterval > 0 else { return }

        let restoredEnd = Date(timeIntervalSince1970: endInterval)
        guard restoredEnd > Date() else {
            // Session expired while the app was closed.
            clearSession()
            return
        }

        endTime = restoredEnd
        // One-time migration from the old preferences plist into Keychain.
        if let legacyHash = defaults.string(forKey: "drift_focus_block_pw_hash") {
            LocalCredentialStore.save(legacyHash, for: LocalCredentialStore.focusPasswordHashKey)
            defaults.removeObject(forKey: "drift_focus_block_pw_hash")
        }
        passwordHash = LocalCredentialStore.read(LocalCredentialStore.focusPasswordHashKey)
        totalSessionDuration = defaults.double(forKey: "drift_focus_block_duration")
        blockedAttempts = defaults.integer(forKey: "drift_focus_block_attempts")
        isBlocking = true

        // Ensure the window tracker is running so we can detect active windows.
        if !WindowTracker.shared.isTracking, AXIsProcessTrusted() {
            WindowTracker.shared.start()
        }

        startMonitoring()
    }

    private func clearSession() {
        let defaults = UserDefaults.standard
        for key in [
            "drift_focus_block_active",
            "drift_focus_block_end",
            "drift_focus_block_pw_hash",
            "drift_focus_block_attempts",
            "drift_focus_block_duration",
        ] {
            defaults.removeObject(forKey: key)
        }
        LocalCredentialStore.delete(LocalCredentialStore.focusPasswordHashKey)
    }

    // MARK: - Start / Stop

    /// Starts a new focus-blocking session.
    ///
    /// - Parameters:
    ///   - durationMinutes: Session length in minutes, clamped to 1...480.
    ///   - password: Optional lock password. When set the user must supply
    ///     the same password to end the session early.
    func startBlocking(durationMinutes: Int, password: String?) {
        let clampedMinutes = min(max(durationMinutes, Self.minimumDurationMinutes), Self.maximumDurationMinutes)
        let duration = TimeInterval(clampedMinutes * 60)

        endTime = Date().addingTimeInterval(duration)
        totalSessionDuration = duration
        blockedAttempts = 0
        lastBlockedSite = nil

        if let pw = password, !pw.isEmpty {
            passwordHash = hashPassword(pw)
        } else {
            passwordHash = nil
        }

        isBlocking = true
        saveSession()

        // Ensure WindowTracker is running so we can detect active windows.
        if !WindowTracker.shared.isTracking {
            WindowTracker.shared.start()
        }

        startMonitoring()

        // Sync with AppState.
        AppState.shared.focusModeActive = true
        AppState.shared.focusModeEndTime = endTime

        sendNotification(
            title: "Focus Mode Activated",
            body: "Blocking \(blockedSites.count) sites for \(clampedMinutes) minutes. Stay focused!"
        )
    }

    /// Attempts to stop the session with the given password.
    ///
    /// - Returns: `true` if the session was stopped, `false` if the password
    ///   was incorrect.
    func stopBlocking(password: String?) -> Bool {
        if let hash = passwordHash {
            guard let pw = password, hashPassword(pw) == hash else {
                return false
            }
        }
        performStop()
        return true
    }

    /// Unconditionally ends the session, bypassing the password.
    ///
    /// Exposed as a safety valve so the app delegate, crash handler, or
    /// system-event responder can always release the blocker. This method
    /// must never be guarded by locks, password checks, or throwing code
    /// paths.
    func forceStopForEmergency() {
        performStop()
    }

    /// Internal stop logic shared by normal and emergency paths.
    private func performStop() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isBlocking = false
        endTime = nil
        passwordHash = nil
        lastBlockedSite = nil
        totalSessionDuration = 0
        clearSession()

        AppState.shared.focusModeActive = false
        AppState.shared.focusModeEndTime = nil

        sendNotification(
            title: "Focus Mode Ended",
            body: "You blocked \(blockedAttempts) distraction\(blockedAttempts == 1 ? "" : "s") during this session."
        )
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkActiveWindow()
                self?.checkExpiration()
            }
        }
        // Fire during UI interactions (scrolling, dragging, resizing).
        if let timer = monitorTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func checkExpiration() {
        guard let end = endTime, Date() >= end else { return }
        performStop()
    }

    // MARK: - Active-Window Checking

    private func checkActiveWindow() {
        guard isBlocking else { return }

        let tracker = WindowTracker.shared
        guard tracker.isTracking else {
            if AXIsProcessTrusted() { tracker.start() }
            return
        }

        // Never block protected system apps.
        if let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Self.protectedBundleIds.contains(bundleId) {
            return
        }

        let title = tracker.activeTitle.lowercased()
        let app = tracker.activeApp

        // Only check browser windows.
        let isBrowser = Self.browserNames.contains { app.lowercased().contains($0) }
        guard isBrowser else { return }

        // Try to get the actual URL from the browser tab.
        let detectedURL = getActiveTabURL(browser: app)?.lowercased() ?? ""

        for site in blockedSites where isSiteEnabled(site) {
            let domain = site.lowercased()
            let siteName = domain.components(separatedBy: ".").first ?? domain

            // 1. Match against actual URL (most reliable).
            if !detectedURL.isEmpty, detectedURL.contains(domain) {
                triggerBlock(site: site, browser: app)
                return
            }

            // 2. Match against window title.
            if title.contains(domain) {
                triggerBlock(site: site, browser: app)
                return
            }

            // 3. Match site name in title (skip very short names to reduce false positives).
            guard siteName.count >= 4 else { continue }
            if title.contains(siteName) {
                triggerBlock(site: site, browser: app)
                return
            }
        }
    }

    private func triggerBlock(site: String, browser: String) {
        blockedAttempts += 1
        lastBlockedSite = site
        saveSession()

        // Redirect the tab to a blocked page and bring Drift to front.
        redirectBlockedTab(browser: browser, site: site)

        sendNotification(
            title: "Site Blocked",
            body: "\(site) was blocked during your focus session."
        )
    }

    // MARK: - Browser URL Retrieval

    /// Retrieves the active tab's URL from a supported browser via AppleScript.
    ///
    /// Returns `nil` when the browser is not scriptable, has no windows open,
    /// or the AppleScript execution fails.
    private func getActiveTabURL(browser: String) -> String? {
        let script: String?

        switch true {
        case browser.contains("Safari"):
            script = Self.safariURLScript
        case browser.contains("Chrome"),
             browser.contains("Brave"),
             browser.contains("Edge"),
             browser.contains("Vivaldi"),
             browser.contains("Opera"),
             browser.contains("Chromium"):
            script = Self.chromiumURLScript(appName: Self.sanitiseAppNameForScript(browser))
        case browser.contains("Arc"):
            script = Self.arcURLScript
        default:
            script = nil
        }

        guard let source = script else { return nil }
        return executeAppleScript(source)
    }

    // MARK: - Tab Redirection

    /// Brings Drift to the foreground and redirects matching browser tabs to
    /// a local "blocked" page.
    private func redirectBlockedTab(browser: String, site: String) {
        // ALWAYS bring Drift to front first as the guaranteed block.
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }

        guard let dataURL = Self.blockedPageDataURL(for: site) else { return }
        let safeSite = Self.sanitiseForAppleScript(site)
        let safeDataURL = Self.sanitiseForAppleScript(dataURL)

        let script: String?
        switch true {
        case browser.contains("Safari"):
            script = Self.safariRedirectScript(site: safeSite, dataURL: safeDataURL)
        case browser.contains("Chrome"),
             browser.contains("Brave"),
             browser.contains("Edge"),
             browser.contains("Vivaldi"),
             browser.contains("Opera"),
             browser.contains("Chromium"):
            let appName = Self.sanitiseAppNameForScript(browser)
            script = Self.chromiumRedirectScript(appName: appName, site: safeSite, dataURL: safeDataURL)
        case browser.contains("Arc"):
            script = Self.arcRedirectScript(site: safeSite, dataURL: safeDataURL)
        default:
            // Firefox and others: cannot redirect tabs; Drift is already in front.
            script = nil
        }

        if let source = script {
            _ = executeAppleScript(source)
        }
    }

    // MARK: - AppleScript Templates

    /// Escapes a string for safe embedding in an AppleScript string literal.
    ///
    /// Prevents injection by escaping backslashes and double-quotes.
    private static func sanitiseForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Strips characters that should not appear in an AppleScript `tell application` name.
    private static func sanitiseAppNameForScript(_ name: String) -> String {
        // Keep only alphanumeric characters, spaces, hyphens, and periods.
        String(name.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) ||
            $0 == " " || $0 == "-" || $0 == "."
        })
    }

    private static let safariURLScript = """
    tell application "Safari"
        if (count of windows) > 0 then
            return URL of current tab of front window
        end if
    end tell
    """

    private static func chromiumURLScript(appName: String) -> String {
        """
        tell application "\(appName)"
            if (count of windows) > 0 then
                return URL of active tab of front window
            end if
        end tell
        """
    }

    private static let arcURLScript = """
    tell application "Arc"
        if (count of windows) > 0 then
            return URL of active tab of front window
        end if
    end tell
    """

    private static func safariRedirectScript(site: String, dataURL: String) -> String {
        """
        tell application "Safari"
            set windowList to every window
            repeat with w in windowList
                set tabList to every tab of w
                repeat with t in tabList
                    set tabURL to URL of t
                    if tabURL contains "\(site)" then
                        set URL of t to "\(dataURL)"
                    end if
                end repeat
            end repeat
        end tell
        """
    }

    private static func chromiumRedirectScript(appName: String, site: String, dataURL: String) -> String {
        """
        tell application "\(appName)"
            set windowList to every window
            repeat with w in windowList
                set tabList to every tab of w
                repeat with t in tabList
                    set tabURL to URL of t
                    if tabURL contains "\(site)" then
                        set URL of t to "\(dataURL)"
                    end if
                end repeat
            end repeat
        end tell
        """
    }

    private static func arcRedirectScript(site: String, dataURL: String) -> String {
        """
        tell application "Arc"
            set windowList to every window
            repeat with w in windowList
                set tabList to every tab of w
                repeat with t in tabList
                    set tabURL to URL of t
                    if tabURL contains "\(site)" then
                        set URL of t to "\(dataURL)"
                    end if
                end repeat
            end repeat
        end tell
        """
    }

    // MARK: - AppleScript Execution

    /// Executes an AppleScript source string and returns its string result.
    @discardableResult
    private func executeAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil {
#if DEBUG
            print("[FocusBlocker] AppleScript execution failed")
#endif
            return nil
        }
        return result.stringValue
    }

    // MARK: - Blocked-Page HTML

    /// Generates a `data:` URL containing the blocked-page HTML.
    ///
    /// The site name is HTML-entity-escaped before embedding to prevent
    /// inadvertent script injection via a maliciously crafted domain name.
    private static func blockedPageDataURL(for site: String) -> String? {
        let escapedSite = site
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        let html = """
        <!DOCTYPE html><html><head><meta charset="utf-8"><title>Blocked - Drift Focus Mode</title><style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0a0a12;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display',system-ui,sans-serif;color:#fff;overflow:hidden}
        .bg{position:fixed;inset:0;background:radial-gradient(ellipse at 30% 20%,rgba(99,102,241,.12) 0%,transparent 50%),radial-gradient(ellipse at 70% 80%,rgba(139,92,246,.1) 0%,transparent 50%)}
        .orb{position:fixed;border-radius:50%;filter:blur(80px);opacity:.18;animation:drift 12s ease-in-out infinite}
        .o1{width:500px;height:500px;background:linear-gradient(135deg,#6366f1,#8b5cf6);top:-150px;left:-100px}
        .o2{width:350px;height:350px;background:linear-gradient(135deg,#8b5cf6,#a78bfa);bottom:-100px;right:-80px;animation-delay:6s}
        .o3{width:200px;height:200px;background:#6366f1;top:50%;left:50%;animation-delay:3s}
        @keyframes drift{0%,100%{transform:translate(0,0) scale(1)}33%{transform:translate(30px,-20px) scale(1.05)}66%{transform:translate(-20px,30px) scale(.95)}}
        .card{position:relative;z-index:1;text-align:center;padding:60px 48px;max-width:480px;background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.06);border-radius:24px;backdrop-filter:blur(20px);box-shadow:0 25px 50px rgba(0,0,0,.4)}
        .shield{width:72px;height:72px;margin:0 auto 28px;background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:50%;display:flex;align-items:center;justify-content:center;box-shadow:0 0 40px rgba(99,102,241,.35);animation:pulse 2.5s ease-in-out infinite}
        @keyframes pulse{0%,100%{transform:scale(1);box-shadow:0 0 40px rgba(99,102,241,.35)}50%{transform:scale(1.06);box-shadow:0 0 60px rgba(99,102,241,.5)}}
        .shield svg{width:36px;height:36px;fill:white}
        h1{font-size:36px;font-weight:800;letter-spacing:6px;margin-bottom:6px;background:linear-gradient(135deg,#a5b4fc,#c4b5fd);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
        .site-name{font-size:15px;color:rgba(255,255,255,.35);letter-spacing:1px;margin-bottom:28px;font-weight:500}
        .msg{font-size:15px;color:rgba(255,255,255,.55);line-height:1.7;margin-bottom:36px}
        .msg strong{color:rgba(255,255,255,.8)}
        .btn{display:inline-block;padding:14px 36px;background:linear-gradient(135deg,#6366f1,#8b5cf6);color:#fff;border:none;border-radius:14px;font-size:14px;font-weight:600;cursor:pointer;text-decoration:none;transition:all .3s;letter-spacing:.5px}
        .btn:hover{transform:translateY(-2px);box-shadow:0 12px 30px rgba(99,102,241,.4)}
        .glow-line{position:absolute;bottom:0;left:50%;transform:translateX(-50%);width:60%;height:1px;background:linear-gradient(90deg,transparent,#6366f1,transparent)}
        </style></head><body>
        <div class="bg"></div><div class="orb o1"></div><div class="orb o2"></div><div class="orb o3"></div>
        <div class="card">
        <div class="shield"><svg viewBox="0 0 24 24"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-1 16l-4-4 1.41-1.41L11 14.17l6.59-6.59L19 9l-8 8z"/></svg></div>
        <h1>BLOCKED</h1>
        <p class="site-name">\(escapedSite)</p>
        <p class="msg"><strong>You're in Focus Mode.</strong><br>This site is blocked to help you stay on track.<br>Get back to what matters.</p>
        <a class="btn" href="about:blank">&larr; Return to Safety</a>
        <div class="glow-line"></div>
        </div>
        </body></html>
        """

        guard let data = html.data(using: .utf8) else { return nil }
        return "data:text/html;base64,\(data.base64EncodedString())"
    }

    // MARK: - Password Hashing

    /// Computes a SHA-256 hex digest of the given password.
    private func hashPassword(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Notifications

    /// Requests notification authorization (once) and delivers a local
    /// notification.
    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()

        // Only request authorization once per app session.
        if let cached = notificationAuthorizationCached {
            if cached { deliverNotification(center: center, title: title, body: body) }
            return
        }

        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.notificationAuthorizationCached = granted
                if granted {
                    self?.deliverNotification(center: center, title: title, body: body)
                }
            }
        }
    }

    private func deliverNotification(center: UNUserNotificationCenter, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
