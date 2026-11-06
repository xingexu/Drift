import SwiftUI
import AppKit

/// Shown at the top of Today until Drift can actually track: without
/// Accessibility, sessions record app names only and look like they work.
struct SetupChecklistView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var tracker: WindowTracker
    @ObservedObject var permissions: PermissionMonitor

    /// Whether the checklist has anything left to do.
    static func isNeeded(permissions: PermissionMonitor, hasSession: Bool) -> Bool {
        permissions.accessibility != .granted
            || permissions.browserAutomation == .denied
            || !hasSession
    }

    private var hasSession: Bool { !appState.pastSessions.isEmpty || tracker.isTracking }
    /// Accessibility missing after sessions exist usually means a rebuild
    /// changed the app's signature and macOS dropped the old grant.
    private var lostAccessibility: Bool { permissions.accessibility != .granted && !appState.pastSessions.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lostAccessibility ? "Drift lost Accessibility access" : "Finish setting up Drift")
                    .font(TypeScale.h2)
                Text(lostAccessibility
                     ? "This usually happens after Drift is rebuilt or updated. Remove Drift from Accessibility in System Settings, add it again, then come back."
                     : "Drift can't classify what you're doing until these are done.")
                    .font(TypeScale.bodySm)
                    .foregroundStyle(Color.driftMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            step(
                number: 1,
                title: "Allow Accessibility",
                detail: "Lets Drift read the active app and window title.",
                done: permissions.accessibility == .granted,
                actionTitle: "Allow",
                action: requestAccessibility
            )
            step(
                number: 2,
                title: "Allow Browser Automation",
                detail: automationDetail,
                done: permissions.browserAutomation == .granted,
                actionTitle: permissions.browserAutomation == .denied ? "Open Settings" : nil,
                action: { openPrivacyPane("Privacy_Automation") }
            )
            step(
                number: 3,
                title: "Start your first session",
                detail: "Track for a few minutes to see your first timeline.",
                done: hasSession,
                actionTitle: permissions.accessibility == .granted ? "Start tracking" : nil,
                action: { tracker.start() }
            )
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftContentSurface(cornerRadius: DriftSurfaceRadius.major)
        .onAppear { permissions.refresh() }
    }

    private var automationDetail: String {
        switch permissions.browserAutomation {
        case .granted: return "Drift can read the active tab's website."
        case .denied: return "Turned off for your browser. Without it, browser time can't be split by website."
        case .notDetermined: return "macOS will ask the first time Drift reads a tab. Choose OK."
        case .unknown: return "Open Chrome, Safari or Arc to check. macOS asks the first time Drift reads a tab."
        }
    }

    private func step(
        number: Int,
        title: String,
        detail: String,
        done: Bool,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(done ? Color.productive.opacity(0.18) : Color.cream.opacity(0.08))
                Image(systemName: done ? "checkmark" : "\(number).circle")
                    .font(.system(size: done ? 13 : 18, weight: .semibold))
                    .foregroundStyle(done ? Color.productive : Color.cream)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TypeScale.heading)
                    .strikethrough(done, color: Color.driftMuted)
                    .foregroundStyle(done ? Color.driftMuted : Color.cream)
                Text(detail)
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.driftMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: Space.md)

            if !done, let actionTitle {
                SecondaryPillButton(title: actionTitle, icon: "arrow.right", action: action)
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title)")
        .accessibilityValue(done ? "Done" : "Not done")
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            openPrivacyPane("Privacy_Accessibility")
        }
        permissions.refresh()
    }

    private func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}
