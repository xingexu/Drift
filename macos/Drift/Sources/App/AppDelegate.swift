import SwiftUI
import AppKit
import os.log
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    private let logger = Logger(subsystem: "net.drift.app", category: "AppDelegate")
    private var accessibilityPollTask: Task<Void, Never>?

    // MARK: - Launch Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // Register the custom URL scheme handler before the app finishes launching
        // so that incoming URLs during launch are not dropped.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        let isSnapshotRun = ProcessInfo.processInfo.environment["DRIFT_SNAPSHOT_PATH"] != nil
        if !isSnapshotRun {
            configureNotifications()
            checkAccessibilityAndStartTracking()
        }
#else
        configureNotifications()
        checkAccessibilityAndStartTracking()
#endif
        activateMainWindow()
#if DEBUG
        Task { @MainActor [weak self] in
            self?.scheduleDebugSnapshotIfRequested()
        }
#endif
    }

    // MARK: - Termination

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityPollTask?.cancel()
        accessibilityPollTask = nil

        // Give the tracker a chance to persist its current session synchronously.
        WindowTracker.shared.persistBeforeExit()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Reactivation

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Self.openMainWindow()
        }
        return true
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        if let window = findMainWindow() {
            window.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Deep Link Handling

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }
        handleDeepLink(url)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "drift",
              let host = url.host?.lowercased() else { return }

        switch host {
        case "tracking", "session":
            Self.openMainWindow()
            Task { @MainActor in
                AppState.shared.currentTab = .tracking
            }
        case "settings":
            Self.openMainWindow()
            Task { @MainActor in
                AppState.shared.currentTab = .settings
            }
        case "focus":
            Self.openMainWindow()
            Task { @MainActor in
                AppState.shared.currentTab = .focus
            }
        case "history":
            Self.openMainWindow()
            Task { @MainActor in
                AppState.shared.currentTab = .history
            }
        default:
            logger.warning("Ignored unrecognized Drift deep link")
        }
    }

    // MARK: - Accessibility

    private func checkAccessibilityAndStartTracking() {
        let options: [String: Any] = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
        ]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if trusted {
            Task { @MainActor in
                WindowTracker.shared.start()
            }
        } else {
            logger.info("Accessibility not granted yet, polling...")
            pollForAccessibility()
        }
    }

    private func pollForAccessibility() {
        accessibilityPollTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                if AXIsProcessTrusted() {
                    await MainActor.run {
                        WindowTracker.shared.start()
                    }
                    self?.logger.info("Accessibility granted")
                    return
                }
            }
        }
    }

    // MARK: - Notifications

    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error = error {
                self?.logger.error("Notification auth error: \(error.localizedDescription, privacy: .public)")
            }
            if granted {
                self?.logger.info("Notifications authorized")
            }
        }
    }

    // UNUserNotificationCenterDelegate -- show banners even when app is foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = userInfo["deepLink"] as? String, let url = URL(string: deepLink) {
            handleDeepLink(url)
        } else {
            Self.openMainWindow()
        }
        completionHandler()
    }

    // MARK: - Window Management

    private func activateMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.ensureWindowVisible()
        }
    }

    private func ensureWindowVisible() {
        if let window = findMainWindow() {
            window.collectionBehavior.insert(.fullScreenPrimary)
            if !window.isVisible {
                window.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func findMainWindow() -> NSWindow? {
        // Prefer a plain NSWindow that can become main (not a panel, not menu bar)
        return NSApp.windows.first { window in
            window.canBecomeMain
                && !(window is NSPanel)
                && !window.className.contains("StatusBar")
                && !window.className.contains("MenuBarExtra")
        }
    }

#if DEBUG
    @MainActor
    private func scheduleDebugSnapshotIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard let outputPath = environment["DRIFT_SNAPSHOT_PATH"] else { return }

        let state = AppState.shared
        state.hasOnboarded = true
        state.theme = environment["DRIFT_SNAPSHOT_THEME"] == "light" ? .light : .dark
        state.reduceMotion = environment["DRIFT_SNAPSHOT_REDUCE_MOTION"] == "true"
        switch environment["DRIFT_SNAPSHOT_TAB"] {
        case "focus": state.currentTab = .focus
        case "history": state.currentTab = .history
        case "settings": state.currentTab = .settings
        default: state.currentTab = .tracking
        }

        let width = Double(environment["DRIFT_SNAPSHOT_WIDTH"] ?? "1440") ?? 1440
        let height = Double(environment["DRIFT_SNAPSHOT_HEIGHT"] ?? "900") ?? 900

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, let window = self.findMainWindow() else {
                NSApp.terminate(nil)
                return
            }
            window.setContentSize(NSSize(width: width, height: height))
            window.makeKeyAndOrderFront(nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                guard let view = window.contentView else {
                    NSApp.terminate(nil)
                    return
                }
                view.layoutSubtreeIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                    NSApp.terminate(nil)
                    return
                }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                if let data = bitmap.representation(using: .png, properties: [:]) {
                    try? data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
                }
                NSApp.terminate(nil)
            }
        }
    }
#endif

    @objc static func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        let mainWindow = NSApp.windows.first { window in
            window.canBecomeMain
                && !(window is NSPanel)
                && !window.className.contains("StatusBar")
        }

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
