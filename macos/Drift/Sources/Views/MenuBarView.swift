import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker

    /// Two-step guard so a stray click can't discard the live session.
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: Space.sm) {
                Image("DriftLogo")
                    .resizable()
                    .interpolation(.none)
                    .clipShape(Rectangle())
                    .frame(width: 18, height: 18)
                Text("Drift")
                    .font(TypeScale.body)
                    .fontWeight(.bold)
                Spacer()
                StatusBadge(
                    label: statusLabel,
                    color: statusColor,
                    pulsing: tracker.isTracking && !tracker.isPaused
                )
            }
            .padding(.bottom, Space.md)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Drift. Status: \(statusLabel)")

            Divider()
                .padding(.bottom, Space.md)

            // Timer section (visible when tracking)
            if tracker.isTracking {
                VStack(spacing: Space.sm) {
                    // Large mono timer with subtle pulse
                    Text(formatDuration(appState.session.totalMs))
                        .font(TypeScale.mono)
                        .contentTransition(.numericText())
                        .animation(Anim.count, value: appState.session.totalMs)
                        .accessibilityLabel("Session time: \(formatDuration(appState.session.totalMs))")

                    // Current app with category dot
                    HStack(spacing: Space.xs) {
                        Rectangle()
                            .fill(appState.session.currentCategory.color)
                            .frame(width: Space.xs, height: Space.xs)
                        Text(tracker.activeApp.isEmpty ? "No active app" : tracker.activeApp)
                            .font(TypeScale.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Current app: \(tracker.activeApp.isEmpty ? "None" : tracker.activeApp)")
                }
                .padding(.bottom, Space.md)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

                // Mini stats row
                HStack(spacing: 0) {
                    MenuBarStat(
                        value: "\(appState.session.focusPercent)%",
                        label: "Focus",
                        color: .productive
                    )

                    Divider()
                        .frame(height: Space.page)

                    MenuBarStat(
                        value: "\(appState.session.driftScore)%",
                        label: "Drift",
                        color: .distraction
                    )

                    Divider()
                        .frame(height: Space.page)

                    MenuBarStat(
                        value: "\(appState.session.uniqueApps)",
                        label: "Apps",
                        color: .primary
                    )
                }
                .padding(.vertical, Space.sm)
                .background(Color.driftPanelInset)
                .overlay(Rectangle().strokeBorder(Color.driftBorder.opacity(0.6), lineWidth: 1))
                .clipShape(Rectangle())
                .padding(.bottom, Space.md)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Session statistics")

                Divider()
                    .padding(.bottom, Space.sm)
            }

            // Actions
            VStack(spacing: Space.xxxs) {
                // Start / Pause / Resume
                MenuBarButton(
                    title: trackingButtonLabel,
                    icon: tracker.isTracking && !tracker.isPaused ? "pause.fill" : "play.fill",
                    color: tracker.isTracking && !tracker.isPaused ? .secondary : .productive,
                    shortcutHint: nil
                ) {
                    toggleTracking()
                }
                .accessibilityLabel(trackingButtonLabel)
                .accessibilityHint("Toggle session tracking")

                // Reset (only when tracking) — two-step confirm to avoid
                // accidentally discarding the active session.
                if tracker.isTracking {
                    MenuBarButton(
                        title: confirmReset ? "Tap again to confirm" : "Reset Session",
                        icon: confirmReset ? "exclamationmark.triangle.fill" : "arrow.counterclockwise",
                        color: confirmReset ? .distraction : .secondary,
                        shortcutHint: nil
                    ) {
                        if confirmReset {
                            tracker.resetSession()
                            confirmReset = false
                        } else {
                            withAnimation(Anim.quick) { confirmReset = true }
                            // Auto-revert if the user doesn't confirm.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation(Anim.quick) { confirmReset = false }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityLabel(confirmReset ? "Confirm reset session" : "Reset tracking session")
                    .accessibilityHint(confirmReset ? "Discards the current session" : "")
                }
            }
            .padding(.bottom, Space.sm)
            .animation(Anim.quick, value: tracker.isTracking)

            Divider()
                .padding(.bottom, Space.sm)

            // Open Drift + Quit
            VStack(spacing: Space.xxxs) {
                MenuBarButton(
                    title: "Open Drift",
                    icon: "macwindow",
                    color: .primary,
                    shortcutHint: nil
                ) {
                    AppDelegate.openMainWindow()
                }
                .accessibilityLabel("Open Drift main window")

                MenuBarButton(
                    title: "Quit Drift",
                    icon: "xmark.circle",
                    color: .secondary,
                    shortcutHint: "Q"
                ) {
                    NSApp.terminate(nil)
                }
                .accessibilityLabel("Quit Drift")
            }
        }
        .padding(Space.lg)
        .frame(width: 260)
    }

    // MARK: - Computed Properties

    private var statusLabel: String {
        if !tracker.isTracking { return "Stopped" }
        return tracker.isPaused ? "Paused" : "Tracking"
    }

    private var statusColor: Color {
        if tracker.isTracking && !tracker.isPaused { return .productive }
        return .secondary
    }

    private var trackingButtonLabel: String {
        if !tracker.isTracking { return "Start Tracking" }
        return tracker.isPaused ? "Resume Tracking" : "Pause Tracking"
    }

    // MARK: - Actions

    private func toggleTracking() {
        if tracker.isTracking && !tracker.isPaused {
            tracker.pause()
        } else {
            tracker.start()
        }
    }
}

// MARK: - Menu Bar Stat

private struct MenuBarStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Space.xxxs) {
            Text(value)
                .font(TypeScale.monoSm)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(Anim.count, value: value)
            Text(label)
                .font(TypeScale.tiny)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Menu Bar Button

private struct MenuBarButton: View {
    let title: String
    let icon: String
    let color: Color
    let shortcutHint: String?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Label {
                    Text(title)
                        .font(TypeScale.body)
                } icon: {
                    Image(systemName: icon)
                        .font(TypeScale.caption)
                        .frame(width: Space.lg)
                }
                .foregroundStyle(color)

                Spacer()

                if let hint = shortcutHint {
                    Text(hint)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .padding(.horizontal, Space.xxs)
                        .padding(.vertical, 1)
                        .background(
                            Rectangle()
                                .fill(Color.primary.opacity(0.04))
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
            )
            .contentShape(Rectangle())
        }
        .driftButton(.ghost)
        .onHover { hovering in
            withAnimation(Anim.quick) {
                isHovered = hovering
            }
        }
    }
}
