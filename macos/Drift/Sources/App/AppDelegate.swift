import SwiftUI
import AppKit
import os.log
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    private let logger = Logger(subsystem: "net.drift.app", category: "AppDelegate")
    private var accessibilityPollTask: Task<Void, Never>?
    private var networkObservation: NSObjectProtocol?

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
        configureNotifications()
        checkAccessibilityAndStartTracking()
        activateMainWindow()
        observeNetworkReconnection()
    }

    // MARK: - Termination

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityPollTask?.cancel()
        accessibilityPollTask = nil

        if let observer = networkObservation {
            NotificationCenter.default.removeObserver(observer)
        }

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
        logger.info("Received URL: \(url.scheme ?? "none", privacy: .public)://\(url.host ?? "", privacy: .public)\(url.path, privacy: .public)")
        handleDeepLink(url)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "drift" else { return }

        switch url.host {
        case "auth":
            handleAuthCallback(url)
        case "session":
            Self.openMainWindow()
            Task { @MainActor in
                AppState.shared.currentTab = .session
            }
        case "settings":
            Self.openMainWindow()
            Task { @MainActor in
                AppState.shared.currentTab = .settings
            }
        default:
            Self.openMainWindow()
        }
    }

    private func handleAuthCallback(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let params = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )

        if let code = params["code"] {
            Task {
                do {
                    let response = try await APIClient.shared.googleSignIn(code: code)
                    await MainActor.run {
                        let state = AppState.shared
                        state.handleTokenRefresh(
                            accessToken: response.accessToken,
                            refreshToken: response.refreshToken
                        )
                        state.saveUser(User(
                            userId: response.user.userId,
                            email: response.user.email,
                            name: response.user.name,
                            plan: response.user.plan
                        ))
                    }
                } catch {
                    logger.error("OAuth callback failed: \(error.localizedDescription, privacy: .public)")
                }
            }
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

    // MARK: - Network Reconnection

    private func observeNetworkReconnection() {
        // When the app comes online, drain any queued offline requests.
        networkObservation = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NetworkStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task {
                let isOnline = await NetworkMonitor.shared.isConnected
                if isOnline {
                    self.logger.info("Network restored, draining offline queue")
                    await APIClient.shared.drainOfflineQueue()
                }
            }
        }
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
