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
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Stay focused — Drift</title>
        <style>
        :root{color-scheme:dark;--canvas:#111016;--cocoa:#241a16;--raised:#30231d;--cream:#fff3df;--muted:#b8a99d;--sand:#e8c7a7;--green:#52a96b;--red:#e66c5c;--line:rgba(255,243,223,.16)}
        *{margin:0;padding:0;box-sizing:border-box}
        body{min-height:100vh;display:grid;place-items:center;padding:32px;background:var(--canvas);font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif;color:var(--cream);overflow:hidden}
        .sky{position:fixed;inset:0;background:linear-gradient(180deg,#070719 0%,#17102c 50%,#48213a 76%,#a74831 100%)}
        .stars{position:absolute;inset:0;opacity:.72;background-image:radial-gradient(circle at 7% 16%,#ffe38f 0 1px,transparent 2px),radial-gradient(circle at 18% 31%,#fff3df 0 1px,transparent 2px),radial-gradient(circle at 31% 11%,#ffe38f 0 2px,transparent 3px),radial-gradient(circle at 46% 25%,#fff3df 0 1px,transparent 2px),radial-gradient(circle at 61% 13%,#ffe38f 0 1px,transparent 2px),radial-gradient(circle at 72% 34%,#fff3df 0 2px,transparent 3px),radial-gradient(circle at 86% 18%,#ffe38f 0 1px,transparent 2px),radial-gradient(circle at 94% 41%,#fff3df 0 1px,transparent 2px)}
        .mesa{position:absolute;right:-5%;bottom:-5%;left:-5%;height:31%;background:#54243a;clip-path:polygon(0 65%,10% 38%,18% 58%,29% 29%,42% 66%,55% 44%,70% 62%,82% 26%,92% 52%,100% 34%,100% 100%,0 100%)}
        .mesa::after{position:absolute;inset:34% 0 0;background:#8e382f;clip-path:polygon(0 57%,14% 34%,25% 62%,39% 42%,55% 70%,69% 36%,84% 61%,100% 28%,100% 100%,0 100%);content:""}
        .brand{position:fixed;top:28px;left:32px;z-index:2;display:flex;align-items:center;gap:11px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;font-weight:800;letter-spacing:.14em;color:var(--cream)}
        .brand-mark{width:31px;height:31px;display:grid;place-items:center;background:var(--sand);border:1px solid rgba(255,243,223,.58);color:var(--cocoa);box-shadow:4px 4px 0 rgba(7,4,13,.42);font-size:14px;letter-spacing:0}
        .focus-state{position:fixed;top:30px;right:32px;z-index:2;display:flex;align-items:center;gap:8px;padding:8px 12px;border:1px solid rgba(82,169,107,.34);background:rgba(17,16,22,.64);font-size:11px;font-weight:700;letter-spacing:.08em;color:var(--cream)}
        .focus-state::before{width:7px;height:7px;background:var(--green);box-shadow:0 0 0 3px rgba(82,169,107,.12);content:""}
        .panel{position:relative;z-index:1;width:min(570px,100%);padding:46px;background:rgba(36,26,22,.94);border:1px solid var(--line);border-radius:18px;box-shadow:9px 9px 0 rgba(7,4,13,.42),0 28px 80px rgba(4,2,10,.32);animation:panel-in 180ms cubic-bezier(.23,1,.32,1) both}
        .header{display:flex;align-items:flex-start;gap:20px}
        .shield{width:68px;height:68px;flex:0 0 auto;display:grid;place-items:center;background:rgba(232,199,167,.11);border:1px solid rgba(232,199,167,.28);box-shadow:5px 5px 0 rgba(7,4,13,.36)}
        .shield svg{width:34px;height:34px;fill:var(--sand)}
        .eyebrow{margin-bottom:9px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:11px;font-weight:800;letter-spacing:.13em;color:var(--red)}
        h1{font-size:34px;line-height:1.1;letter-spacing:-.035em;color:var(--cream)}
        .message{margin:24px 0 26px;color:var(--muted);font-size:15px;line-height:1.65}
        .message strong{color:var(--cream);font-weight:650}
        .site{display:flex;align-items:center;gap:13px;padding:15px 17px;background:rgba(17,16,22,.62);border:1px solid var(--line);border-radius:12px}
        .site-icon{width:30px;height:30px;display:grid;place-items:center;background:rgba(230,108,92,.10);color:var(--red);font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-weight:900}
        .site-copy{min-width:0;flex:1}
        .site-label{margin-bottom:3px;font-size:10px;font-weight:750;letter-spacing:.1em;color:var(--muted)}
        .site-name{overflow:hidden;color:var(--cream);font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:14px;font-weight:700;text-overflow:ellipsis;white-space:nowrap}
        .session{display:flex;align-items:center;gap:9px;margin:16px 0 28px;color:var(--muted);font-size:12px}
        .session-dot{width:6px;height:6px;background:var(--green)}
        .actions{display:flex;align-items:center;gap:18px}
        .button{display:inline-flex;align-items:center;justify-content:center;min-height:46px;padding:0 24px;background:var(--sand);border:1px solid rgba(255,243,223,.62);border-radius:999px;color:var(--cocoa);font-size:14px;font-weight:750;text-decoration:none;box-shadow:0 8px 24px rgba(7,4,13,.24);transition:transform 140ms cubic-bezier(.23,1,.32,1),background-color 140ms ease,box-shadow 140ms cubic-bezier(.23,1,.32,1)}
        .button:hover{background:#f1d8bd;transform:translateY(-1px);box-shadow:0 11px 28px rgba(7,4,13,.30)}
        .button:active{transform:scale(.97)}
        .privacy{color:var(--muted);font-size:11px;line-height:1.45}
        @keyframes panel-in{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
        @media(max-width:640px){body{padding:20px}.brand{top:20px;left:20px}.focus-state{top:22px;right:20px}.panel{padding:32px 26px}.header{gap:16px}.shield{width:58px;height:58px}h1{font-size:28px}.actions{align-items:flex-start;flex-direction:column;gap:13px}}
        @media(prefers-reduced-motion:reduce){.panel{animation:none}.button{transition-duration:0ms}}
        </style>
        </head>
        <body>
        <div class="sky" aria-hidden="true"><div class="stars"></div><div class="mesa"></div></div>
        <div class="brand"><span class="brand-mark">D</span><span>DRIFT</span></div>
        <div class="focus-state">FOCUS ACTIVE</div>
        <main class="panel">
        <div class="header">
        <div class="shield" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M12 2 4 5.5v5.3c0 5.1 3.4 9.8 8 11.2 4.6-1.4 8-6.1 8-11.2V5.5L12 2Zm-1.1 14.3-3.5-3.5 1.3-1.3 2.2 2.2 4.7-4.7 1.3 1.3-6 6Z"/></svg></div>
        <div><p class="eyebrow">DISTRACTION INTERCEPTED</p><h1>Stay in the zone.</h1></div>
        </div>
        <p class="message"><strong>Drift blocked this page while Focus is active.</strong><br>Your session is still moving. Return to the work you chose.</p>
        <div class="site">
        <span class="site-icon" aria-hidden="true">×</span>
        <div class="site-copy"><p class="site-label">BLOCKED WEBSITE</p><p class="site-name">\(escapedSite)</p></div>
        </div>
        <div class="session"><span class="session-dot" aria-hidden="true"></span><span>Focus protection is running on this Mac</span></div>
        <div class="actions">
        <a class="button" href="about:blank">Return to focus&nbsp; →</a>
        <p class="privacy">Private by design.<br>Nothing was uploaded.</p>
        </div>
        </main>
        </body>
        </html>
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
