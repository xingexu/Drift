import SwiftUI
import AppKit

// MARK: - Checklist State

/// Pure description of the setup checklist, derived only from its inputs so
/// every combination can be unit tested without macOS permissions.
struct SetupChecklistState: Equatable {
    enum AutomationAction: Equatable {
        /// User turned it off: send them to System Settings.
        case openSettings
        /// Nothing to click: macOS asks on first use, or a browser must be open.
        case none
    }

    let accessibilityDone: Bool
    let automationDone: Bool
    let automationAction: AutomationAction
    let sessionDone: Bool
    /// "Start tracking" is offered only when tracking can actually work.
    let canStartSession: Bool
    /// Accessibility missing although sessions exist: almost always a
    /// rebuild that changed the app's signature.
    let lostAccessibility: Bool
    /// Whether the checklist should be shown at all.
    let isNeeded: Bool

    init(accessibility: PermissionState, automation: PermissionState, sessionCount: Int, isTracking: Bool) {
        accessibilityDone = accessibility == .granted
        automationDone = automation == .granted
        automationAction = automation == .denied ? .openSettings : .none
        sessionDone = sessionCount > 0 || isTracking
        canStartSession = accessibilityDone && !sessionDone
        lostAccessibility = !accessibilityDone && sessionCount > 0
        // Automation that is merely unknown / not asked yet must not keep the
        // checklist up forever: it can only resolve while tracking a browser.
        isNeeded = !accessibilityDone || automation == .denied || !sessionDone
    }

    var headline: String {
        lostAccessibility ? "Drift lost Accessibility access" : "Finish setting up Drift"
    }

    var message: String {
        lostAccessibility
            ? "This usually happens after Drift is rebuilt or updated. Remove Drift from Accessibility in System Settings, add it again, then come back."
            : "Drift can't classify what you're doing until these are done."
    }

    static func automationDetail(_ state: PermissionState) -> String {
        switch state {
        case .granted: return "Drift can read the active tab's website."
        case .denied: return "Turned off for your browser. Without it, browser time can't be split by website."
        case .notDetermined: return "macOS will ask the first time Drift reads a tab. Choose OK."
        case .unknown: return "Open Chrome, Safari or Arc to check. macOS asks the first time Drift reads a tab."
        }
    }
}

// MARK: - Checklist View

/// Shown at the top of Today until Drift can actually track: without
/// Accessibility, sessions record app names only and look like they work.
struct SetupChecklistView: View {
    let state: SetupChecklistState
    let automation: PermissionState
    let onAllowAccessibility: () -> Void
    let onStartTracking: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.headline)
                    .font(TypeScale.h2)
                Text(state.message)
                    .font(TypeScale.bodySm)
                    .foregroundStyle(Color.driftMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            step(
                number: 1,
                title: "Allow Accessibility",
                detail: "Lets Drift read the active app and window title.",
                done: state.accessibilityDone,
                actionTitle: "Allow",
                action: onAllowAccessibility
            )
            step(
                number: 2,
                title: "Allow Browser Automation",
                detail: SetupChecklistState.automationDetail(automation),
                done: state.automationDone,
                actionTitle: state.automationAction == .openSettings ? "Open Settings" : nil,
                action: { Self.openPrivacyPane("Privacy_Automation") }
            )
            step(
                number: 3,
                title: "Start your first session",
                detail: "Track for a few minutes to see your first timeline.",
                done: state.sessionDone,
                actionTitle: state.canStartSession ? "Start tracking" : nil,
                action: onStartTracking
            )
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftContentSurface(cornerRadius: DriftSurfaceRadius.major)
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

    static func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}
