import AppKit
import ApplicationServices
import Combine

/// State of a macOS privacy permission Drift depends on.
enum PermissionState: Equatable {
    case granted
    case denied
    /// macOS hasn't asked yet (Automation only).
    case notDetermined
    /// Can't be checked right now (Automation needs a supported browser running).
    case unknown
}

/// Live view of the two permissions tracking needs. Checks never show a
/// system prompt; they only read the current state.
@MainActor
final class PermissionMonitor: ObservableObject {
    static let shared = PermissionMonitor()

    @Published private(set) var accessibility: PermissionState = .unknown
    @Published private(set) var browserAutomation: PermissionState = .unknown

    /// True when tracking can read window titles; the minimum to be useful.
    var isTrackingReady: Bool { accessibility == .granted }

    private var activationObserver: NSObjectProtocol?

    /// Scriptable browsers Drift reads tab URLs from, in check order.
    private static let browserBundleIds = [
        "com.google.Chrome", "com.apple.Safari", "company.thebrowser.Browser",
        "com.brave.Browser", "com.microsoft.edgemac", "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
    ]

    private init() {
        refresh()
        // Permissions are usually changed in System Settings, so re-check
        // whenever the user comes back to Drift.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        accessibility = AXIsProcessTrusted() ? .granted : .denied
        browserAutomation = Self.automationState()
    }

    /// Checks Apple Events permission against the first running supported
    /// browser without prompting. Any granted browser counts as granted.
    private static func automationState() -> PermissionState {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        var result: PermissionState = .unknown
        for bundleId in browserBundleIds where running.contains(bundleId) {
            switch status(for: bundleId) {
            case .granted: return .granted
            case .denied: result = .denied
            case .notDetermined where result != .denied: result = .notDetermined
            default: break
            }
        }
        return result
    }

    private static func status(for bundleId: String) -> PermissionState {
        var target = AEAddressDesc()
        let created = bundleId.withCString { pointer in
            AECreateDesc(DescType(typeApplicationBundleID), pointer, strlen(pointer), &target)
        }
        guard created == noErr else { return .unknown }
        defer { AEDisposeDesc(&target) }

        let status = AEDeterminePermissionToAutomateTarget(
            &target, AEEventClass(typeWildCard), AEEventID(typeWildCard), false
        )
        switch status {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(errAEEventWouldRequireUserConsent): return .notDetermined
        default: return .unknown // e.g. procNotFound: browser quit meanwhile
        }
    }
}
