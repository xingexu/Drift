import SwiftUI
import Combine
import AppKit
import ApplicationServices

// MARK: - Window Tracker

/// Monitors the frontmost application and its window title, recording
/// time-segmented events into ``AppState/session``.
///
/// Uses a hybrid approach:
/// - **NSWorkspace notifications** detect app-activation changes instantly.
/// - A **1-second poll timer** captures window-title changes within the same
///   app (e.g. switching browser tabs) and drives session-time accounting.
///
/// All mutable state lives on `@MainActor`. Timer callbacks hop to the main
/// actor before touching any property, eliminating data races.
@MainActor
class WindowTracker: ObservableObject {

    // MARK: - Singleton

    static let shared = WindowTracker()

    // MARK: - Published State

    @Published private(set) var isTracking = false
    @Published private(set) var isPaused = false
    @Published private(set) var isIdle = false
    @Published private(set) var activeApp: String = ""
    @Published private(set) var activeTitle: String = ""
    @Published private(set) var activeURL: String = ""
    @Published private(set) var activeCategory: AppCategory = .neutral

    // MARK: - Private State

    private var pollTimer: Timer?
    private var sessionTimer: Timer?
    /// Idle checker runs for the whole tracking lifetime — including while
    /// paused — so a session that auto-paused on idle can auto-resume when the
    /// user returns. (pollTimer/sessionTimer stop on pause; this one does not.)
    private var idleTimer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var lastEventTimestamp = Date()
    private var previousApp: String = ""
    private var previousBundleId: String?

    /// True only when the current pause was triggered automatically by idle
    /// detection (vs. a manual user pause). Manual pauses must NOT auto-resume.
    private var pausedDueToIdle = false
    /// Wall-clock time the current pause began, used to exclude paused spans
    /// from `totalMs` so focus % isn't diluted by time away.
    private var pauseStartedAt: Date?
    /// Cumulative paused milliseconds for the active session.
    private var pausedAccumulatedMs: TimeInterval = 0

    /// Minimum duration (ms) to record an app-switch event.
    /// Prevents micro-events from very rapid Cmd-Tab switching.
    private let minimumEventDurationMs: TimeInterval = 500


    /// Seconds of input inactivity before the session is considered idle.
    private var idleThreshold: TimeInterval {
        TimeInterval(max(AppState.shared.idleTimeout, 30))
    }

    // MARK: - Init

    private init() {}

    // MARK: - Lifecycle

    /// Begins tracking the frontmost application.
    ///
    /// If accessibility permissions have not been granted the tracker still
    /// runs but window titles will be unavailable (app names from
    /// `NSWorkspace` remain accurate).
    func start() {
        guard !isTracking || isPaused else { return }

        if !AXIsProcessTrusted() {
            print("[WindowTracker] Accessibility not granted -- tracking without window titles")
        }

        if !isTracking {
            AppState.shared.session = SessionData()
            AppState.shared.session.isActive = true
            AppState.shared.session.startTime = Date()
            pausedAccumulatedMs = 0
            pauseStartedAt = nil
        } else if let pausedAt = pauseStartedAt {
            // Resuming a paused session — bank the paused span so it's excluded
            // from elapsed time.
            pausedAccumulatedMs += Date().timeIntervalSince(pausedAt) * 1000
            pauseStartedAt = nil
        }

        pausedDueToIdle = false
        isTracking = true
        isPaused = false
        lastEventTimestamp = Date()

        installWorkspaceObserver()
        startTimers()
        startIdleTimer()
        pollActiveWindow()
    }

    /// Pauses tracking without resetting the session. The idle checker keeps
    /// running so an idle-triggered pause can later auto-resume.
    func pause() {
        guard isTracking, !isPaused else { return }
        isPaused = true
        pauseStartedAt = Date()
        stopTimers()
    }

    /// Fully stops tracking and tears down all observers.
    func stop() {
        isTracking = false
        isPaused = false
        pausedDueToIdle = false
        stopTimers()
        stopIdleTimer()
        removeWorkspaceObserver()
    }

    /// Saves the current session to history and resets for a fresh run.
    func resetSession() {
        AppState.shared.saveCurrentSession()
        stop()
        AppState.shared.session.reset()
        pausedAccumulatedMs = 0
        pauseStartedAt = nil
    }

    /// Called by AppDelegate during applicationWillTerminate to persist
    /// any in-progress session data before the process exits.
    func persistBeforeExit() {
        if isTracking {
            AppState.shared.saveCurrentSession()
        }
        stop()
    }

    // MARK: - NSWorkspace Notification

    /// Observes `NSWorkspace.didActivateApplicationNotification` so we react
    /// to app switches without polling.
    private func installWorkspaceObserver() {
        removeWorkspaceObserver()
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self, self.isTracking, !self.isPaused else { return }
                self.handleAppActivation(notification: notification)
            }
        }
    }

    private func removeWorkspaceObserver() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
    }

    /// Processes an app-activation notification.
    private func handleAppActivation(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        let appName = app.localizedName ?? "Unknown"
        let bundleId = app.bundleIdentifier
        let title = windowTitle(for: app) ?? appName
        let isBrowser = Self.isBrowserBundle(bundleId)

        // For browsers, attempt to fetch the real tab URL immediately.
        var resolvedURL: String? = nil
        if isBrowser {
            resolvedURL = getActiveTabURL(for: app)
        }

        let webContextForClassification = resolvedURL
            ?? (isBrowser ? extractURL(from: title, appName: appName) : nil)

        var category = AppClassifier.classify(appName: appName, bundleId: bundleId)
        if isBrowser {
            category = AppClassifier.classifyWebContext(
                urlString: webContextForClassification,
                title: title,
                fallback: category
            )
        }

        recordAppSwitch(
            newApp: appName,
            newBundleId: bundleId,
            newTitle: title,
            newURL: resolvedURL,
            newCategory: category,
            isBrowser: isBrowser
        )
    }

    // MARK: - Timers

    private func startTimers() {
        stopTimers()

        // Poll timer -- captures title changes. (Idle is handled by idleTimer,
        // which must survive pause; this timer stops while paused.)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollActiveWindow()
            }
        }
        if let t = pollTimer { RunLoop.main.add(t, forMode: .common) }

        // Session timer -- updates elapsed time.
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSessionTime()
            }
        }
        if let t = sessionTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func stopTimers() {
        pollTimer?.invalidate()
        pollTimer = nil
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    /// Idle checker — independent of pause so return-from-idle can resume.
    private func startIdleTimer() {
        stopIdleTimer()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdle()
            }
        }
        if let t = idleTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    // MARK: - Polling

    /// Lightweight per-second poll. Detects title changes (tab switches) and
    /// ensures state stays current if the notification was missed (e.g. full-
    /// screen transitions).
    private func pollActiveWindow() {
        guard isTracking, !isPaused else { return }
        guard let info = activeWindowInfo() else { return }

        let appName = info.appName
        let bundleId = info.bundleId
        let title = info.windowTitle
        let isBrowser = info.isBrowser

        // For browsers: try AppleScript first for the real tab URL, fall back to title parsing.
        var resolvedURL: String? = nil
        if isBrowser, let frontApp = NSWorkspace.shared.frontmostApplication {
            if let tabURL = getActiveTabURL(for: frontApp) {
                resolvedURL = tabURL
            }
        }

        let webContextForClassification = resolvedURL
            ?? (isBrowser ? extractURL(from: title, appName: appName) : nil)

        var category = AppClassifier.classify(appName: appName, bundleId: bundleId)
        if isBrowser {
            category = AppClassifier.classifyWebContext(
                urlString: webContextForClassification,
                title: title,
                fallback: category
            )
        }

        // Always update the displayed state.
        activeTitle = title
        activeURL = resolvedURL ?? ""
        activeCategory = category

        // Only record a switch if the app actually changed and the
        // notification path did not already handle it.
        if appName != previousApp {
            recordAppSwitch(
                newApp: appName,
                newBundleId: bundleId,
                newTitle: title,
                newURL: resolvedURL,
                newCategory: category,
                isBrowser: isBrowser
            )
        }
    }

    /// Accounts for time spent in the previous app and transitions to the new one.
    private func recordAppSwitch(
        newApp: String,
        newBundleId: String?,
        newTitle: String,
        newURL: String? = nil,
        newCategory: AppCategory,
        isBrowser: Bool
    ) {
        let now = Date()
        let durationMs = now.timeIntervalSince(lastEventTimestamp) * 1000

        // Record the event for the PREVIOUS app, skipping negligible durations.
        // Note: category time (productiveMs, etc.) is now accumulated in real-time
        // by updateSessionTime(), so we do NOT add durationMs to category counters
        // here — that would double-count.
        if !previousApp.isEmpty, durationMs >= minimumEventDurationMs {
            let prevCategory = AppState.shared.session.currentCategory

            let event = AppEvent(
                owner: previousApp,
                title: activeTitle,
                isBrowser: isBrowser,
                url: activeURL.isEmpty ? nil : activeURL,
                category: prevCategory,
                timestamp: lastEventTimestamp,
                durationMs: durationMs
            )
            AppState.shared.session.events.append(event)

            // Cap event history to prevent unbounded memory growth.
            if AppState.shared.session.events.count > 200 {
                AppState.shared.session.events.removeFirst()
            }
        }

        previousApp = newApp
        previousBundleId = newBundleId
        lastEventTimestamp = now
        activeApp = newApp
        activeTitle = newTitle
        activeURL = newURL ?? ""
        activeCategory = newCategory
        AppState.shared.session.currentApp = newApp
        AppState.shared.session.currentCategory = newCategory
    }

    private func updateSessionTime() {
        guard let start = AppState.shared.session.startTime else { return }
        AppState.shared.session.totalMs = Date().timeIntervalSince(start) * 1000 - pausedAccumulatedMs

        // Attribute time to the current app's category in real-time.
        // Without this, focusPercent/driftScore stay at 0% until the user
        // switches away because category counters only update on app-switch.
        //
        // Strategy: each tick, add 1 second to the current category. This is
        // accurate because the timer fires every 1s and recordAppSwitch()
        // will record the precise duration on transition anyway. Small drift
        // is corrected on each app switch.
        guard isTracking, !isPaused, !previousApp.isEmpty else { return }

        let increment: TimeInterval = 1000  // 1 second in ms
        switch AppState.shared.session.currentCategory {
        case .productive:  AppState.shared.session.productiveMs  += increment
        case .neutral:     AppState.shared.session.neutralMs     += increment
        case .distraction: AppState.shared.session.distractionMs += increment
        }
    }

    // MARK: - Idle Detection

    /// Checks HID event sources for mouse and keyboard activity.
    ///
    /// On transition to idle the tracker pauses automatically. On return
    /// from idle the timestamp is reset so idle seconds are not attributed
    /// to any app.
    private func checkIdle() {
        guard isTracking else { return }

        let mouseIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .mouseMoved)
        let keyIdle   = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
        let clickIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .leftMouseDown)
        let minIdle = min(mouseIdle, min(keyIdle, clickIdle))

        if minIdle >= idleThreshold {
            // User went idle — auto-pause only a session that's actively running.
            // (A manual pause is left untouched so it won't surprise-resume.)
            if !isPaused {
                isIdle = true
                pausedDueToIdle = true
                pause()
            }
        } else {
            // User is active again.
            if isPaused, pausedDueToIdle {
                // Resume the session WE auto-paused. start() banks the paused
                // span, restarts the work timers, and clears pausedDueToIdle.
                isIdle = false
                start()
            } else if isIdle {
                isIdle = false
                // Reset timestamp so the idle period is not charged to any app.
                lastEventTimestamp = Date()
            }
        }
    }

    // MARK: - Active Window (Accessibility API)

    /// Snapshot of the frontmost window at a point in time.
    struct WindowInfo {
        let appName: String
        let windowTitle: String
        let bundleId: String?
        let isBrowser: Bool
    }

    /// Queries `NSWorkspace` and the Accessibility API for the frontmost window.
    ///
    /// Returns `nil` only when no application is active (rare edge case during
    /// fast user switching or when the login window is shown).
    private func activeWindowInfo() -> WindowInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

        let appName  = app.localizedName ?? "Unknown"
        let bundleId = app.bundleIdentifier
        let title    = windowTitle(for: app) ?? appName
        let isBrowser = Self.isBrowserBundle(bundleId)

        return WindowInfo(
            appName: appName,
            windowTitle: title,
            bundleId: bundleId,
            isBrowser: isBrowser
        )
    }

    /// Retrieves the focused-window title via the Accessibility API.
    ///
    /// Returns `nil` when accessibility access has not been granted or the app
    /// has no focused window (e.g. menu-bar-only utilities).
    private func windowTitle(for app: NSRunningApplication) -> String? {
        guard AXIsProcessTrusted() else { return nil }

        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        var windowRef: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedWindowAttribute as CFString,
            &windowRef
        )
        // Safe check -- do NOT force-unwrap the AXUIElement.
        guard windowResult == .success,
              let window = windowRef,
              CFGetTypeID(window) == AXUIElementGetTypeID() else {
            return nil
        }

        var titleRef: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &titleRef
        )
        guard titleResult == .success, let title = titleRef as? String, !title.isEmpty else {
            return nil
        }
        return title
    }

    // MARK: - Browser Detection

    /// Bundle identifiers recognized as web browsers.
    private static let browserBundleIds: Set<String> = [
        "com.google.chrome",
        "com.brave.browser",
        "com.apple.safari",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "company.thebrowser.browser",   // Arc
        "com.operasoftware.opera",
        "com.vivaldi.vivaldi",
        "org.chromium.chromium",
        "com.nickvision.webkit",        // GNOME Web / Epiphany
        "com.nickvision.Application",   // Orion
    ]

    /// Checks whether a bundle identifier belongs to a known browser.
    ///
    /// The comparison is case-insensitive so it tolerates capitalization
    /// differences across OS versions.
    private static func isBrowserBundle(_ bundleId: String?) -> Bool {
        guard let id = bundleId?.lowercased() else { return false }
        return browserBundleIds.contains(id)
    }

    // MARK: - URL Extraction

    /// Attempts to pull a domain from a browser's window title.
    ///
    /// Many browsers format their titles as "Page Title - BrowserName".
    /// If the page-title portion looks like a bare domain (contains a dot,
    /// no spaces) it is returned as-is.
    private func extractURL(from title: String, appName: String) -> String? {
        let separators = [" - ", " \u{2014} ", " \u{2013} "]   // —, –
        for sep in separators {
            if let range = title.range(of: sep, options: .backwards) {
                let pageTitle = String(title[..<range.lowerBound])
                if pageTitle.contains("."), !pageTitle.contains(" ") {
                    return pageTitle
                }
            }
        }
        return nil
    }

    // MARK: - Browser Tab URL (AppleScript)

    /// Retrieves the active tab URL from a supported browser via AppleScript.
    ///
    /// Returns `nil` when the browser is not scriptable, has no windows open,
    /// or the script fails. Runs synchronously — called from the poll timer
    /// only when a browser is frontmost.
    func getActiveTabURL(for app: NSRunningApplication) -> String? {
        let appName = app.localizedName ?? ""
        let script: String

        switch true {
        case appName.contains("Safari") && !appName.contains("Technology Preview"):
            script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    return URL of current tab of front window
                end if
            end tell
            """
        case appName.contains("Chrome"):
            let safe = Self.safeScriptName(appName)
            script = """
            tell application "\(safe)"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """
        case appName.contains("Arc"):
            script = """
            tell application "Arc"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """
        case appName.contains("Brave"):
            script = """
            tell application "Brave Browser"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """
        case appName.contains("Edge"):
            script = """
            tell application "Microsoft Edge"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """
        case appName.contains("Firefox"):
            // Firefox does not support AppleScript URL retrieval
            return nil
        default:
            return nil
        }

        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }

    /// Strips characters unsafe for embedding in AppleScript application names.
    private static func safeScriptName(_ name: String) -> String {
        String(name.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" || $0 == "."
        })
    }

}
