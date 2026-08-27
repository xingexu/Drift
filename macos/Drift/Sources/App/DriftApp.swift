import SwiftUI
import AppKit

@main
struct DriftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var tracker = WindowTracker.shared
    @StateObject private var focusBlocker = FocusBlocker.shared

    @Environment(\.scenePhase) private var scenePhase

    init() {
        PixelFont.register()
    }

    var body: some Scene {
        WindowGroup("Drift") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(tracker)
                .environmentObject(focusBlocker)
                .frame(minWidth: 860, minHeight: 560)
                .background(Color.driftBackground)
                .font(TypeScale.bodyMd)
                .foregroundStyle(Color.driftText)
                .tint(appState.accentColor)
                .onAppear {
                    configureMainWindow()
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: "main"))
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Go") {
                Button("Today") { AppState.shared.currentTab = .tracking }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Focus") { AppState.shared.currentTab = .focus }
                    .keyboardShortcut("2", modifiers: .command)
                Button("History") { AppState.shared.currentTab = .history }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Settings") { AppState.shared.currentTab = .settings }
                    .keyboardShortcut("4", modifiers: .command)
            }

            CommandMenu("Tracking") {
                Button(tracker.isTracking ? "Pause Tracking" : "Start Tracking") {
                    if tracker.isTracking { tracker.pause() } else { tracker.start() }
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Reset Session") {
                    tracker.resetSession()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(tracker)
                .font(TypeScale.bodyMd)
                .foregroundStyle(Color.driftText)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(tracker)
                .font(TypeScale.bodyMd)
                .foregroundStyle(Color.driftText)
                .background(Color.driftBackground)
        }
    }

    // MARK: - Window Configuration

    private func configureMainWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            if let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
                window.collectionBehavior.insert(.fullScreenPrimary)
                window.isOpaque = true
                window.backgroundColor = NSColor(red: 0.030, green: 0.024, blue: 0.052, alpha: 1)
                window.styleMask.insert(.fullSizeContentView)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.titlebarSeparatorStyle = .none
                window.title = "Drift"
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    // MARK: - Scene Phase

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            break
        case .background:
            // Persist any unsaved session data when entering background
            appState.saveCurrentSession()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    // MARK: - URL Handling

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "drift" else { return }

        switch url.host {
        case "tracking", "session":
            appState.currentTab = .tracking
        case "settings":
            appState.currentTab = .settings
        case "focus":
            appState.currentTab = .focus
        case "history":
            appState.currentTab = .history
        default:
            break
        }
    }
}
