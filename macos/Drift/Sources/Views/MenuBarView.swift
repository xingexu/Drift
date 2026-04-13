import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image("DriftLogo")
                    .resizable()
                    .interpolation(.high)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(width: 18, height: 18)
                Text("Drift")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                StatusBadge(
                    label: statusLabel,
                    color: statusColor,
                    pulsing: tracker.isTracking && !tracker.isPaused
                )
            }
            .padding(.bottom, 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Drift. Status: \(statusLabel)")

            Divider()
                .padding(.bottom, 12)

            // Timer section (visible when tracking)
            if tracker.isTracking {
                VStack(spacing: 8) {
                    // Large mono timer with subtle pulse
                    Text(formatDuration(appState.session.totalMs))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())
                        .animation(.default, value: appState.session.totalMs)
                        .accessibilityLabel("Session time: \(formatDuration(appState.session.totalMs))")

                    // Current app with category dot
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.session.currentCategory.color)
                            .frame(width: 6, height: 6)
                        Text(tracker.activeApp.isEmpty ? "No active app" : tracker.activeApp)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Current app: \(tracker.activeApp.isEmpty ? "None" : tracker.activeApp)")
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

                // Mini stats row
                HStack(spacing: 0) {
                    MenuBarStat(
                        value: "\(appState.session.focusPercent)%",
                        label: "Focus",
                        color: Color("Green")
                    )

                    Divider()
                        .frame(height: 28)

                    MenuBarStat(
                        value: "\(appState.session.driftScore)%",
                        label: "Drift",
                        color: Color("Red")
                    )

                    Divider()
                        .frame(height: 28)

                    MenuBarStat(
                        value: "\(appState.session.uniqueApps)",
                        label: "Apps",
                        color: .primary
                    )
                }
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 12)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Session statistics")

                Divider()
                    .padding(.bottom, 8)
            }

            // Actions
            VStack(spacing: 2) {
                // Start / Pause / Resume
                MenuBarButton(
                    title: trackingButtonLabel,
                    icon: tracker.isTracking && !tracker.isPaused ? "pause.fill" : "play.fill",
                    color: tracker.isTracking && !tracker.isPaused ? .secondary : Color("Green"),
                    shortcutHint: nil
                ) {
                    toggleTracking()
                }
                .accessibilityLabel(trackingButtonLabel)
                .accessibilityHint("Toggle session tracking")

                // Reset (only when tracking)
                if tracker.isTracking {
                    MenuBarButton(
                        title: "Reset Session",
                        icon: "arrow.counterclockwise",
                        color: .secondary,
                        shortcutHint: nil
                    ) {
                        tracker.resetSession()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityLabel("Reset tracking session")
                }
            }
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.15), value: tracker.isTracking)

            Divider()
                .padding(.bottom, 8)

            // Open Drift + Quit
            VStack(spacing: 2) {
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
        .padding(14)
        .frame(width: 260)
    }

    // MARK: - Computed Properties

    private var statusLabel: String {
        if !tracker.isTracking { return "Stopped" }
        return tracker.isPaused ? "Paused" : "Tracking"
    }

    private var statusColor: Color {
        if tracker.isTracking && !tracker.isPaused { return Color("Green") }
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
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
            Text(label)
                .font(.system(size: 9))
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
                        .font(.system(size: 13))
                } icon: {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .frame(width: 16)
                }
                .foregroundStyle(color)

                Spacer()

                if let hint = shortcutHint {
                    Text(hint)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.primary.opacity(0.04))
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
