import SwiftUI

// MARK: - Session View

struct SessionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker
    @State private var resetHovered = false
    @State private var actionHovered = false
    @State private var focusHovered = false
    @State private var contentAppeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                sessionHeader
                clockRing
                    .opacity(contentAppeared ? 1 : 0)
                    .scaleEffect(contentAppeared ? 1 : 0.92)
                controlStrip
                metricsPanel
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 12)
                appTimeline
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 16)
                currentAppBar
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 12)
            }
            .padding(28)
        }
        .task {
            guard !contentAppeared else { return }
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var sessionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Session")
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text("Track your focus in real-time")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(
                label: statusLabel,
                color: statusColor,
                pulsing: tracker.isTracking && !tracker.isPaused
            )
            .accessibilityLabel("Session status: \(statusLabel)")
        }
    }

    // MARK: - Clock Ring

    @ViewBuilder
    private var clockRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.separatorColor).opacity(0.4), lineWidth: 8)
                .frame(width: 200, height: 200)

            SessionProgressRing(
                progress: CGFloat(appState.session.focusPercent) / 100.0
            )

            VStack(spacing: 6) {
                Text(formatDuration(appState.session.totalMs))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .tracking(-1.5)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Session duration: \(formatDurationWords(appState.session.totalMs))")

                Text(statusLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus ring at \(appState.session.focusPercent) percent. Duration: \(formatDurationWords(appState.session.totalMs))")
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlStrip: some View {
        HStack(spacing: 12) {
            // Reset
            Button(action: { tracker.resetSession() }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule().stroke(Color.primary.opacity(resetHovered ? 0.08 : 0.04), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(resetHovered ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!tracker.isTracking)
            .opacity(tracker.isTracking ? 1 : 0.4)
            .scaleEffect(resetHovered ? 1.03 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: resetHovered)
            .onHover { h in resetHovered = h }
            .accessibilityLabel("Reset Session")
            .accessibilityHint("Saves and resets the current tracking session")

            // Main action
            Button(action: toggleTracking) {
                HStack(spacing: 8) {
                    Image(systemName: actionButtonIcon)
                        .font(.system(size: 14))
                        .contentTransition(.symbolEffect(.replace))
                    Text(actionButtonLabel)
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(Color.drift)
                        .shadow(color: Color.drift.opacity(actionHovered ? 0.4 : 0.2), radius: actionHovered ? 12 : 6, y: 3)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .scaleEffect(actionHovered ? 1.04 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: actionHovered)
            .onHover { h in actionHovered = h }
            .accessibilityLabel(actionButtonLabel)
            .accessibilityHint(actionAccessibilityHint)

            // Focus Mode
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    appState.focusModeActive.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: appState.focusModeActive ? "shield.fill" : "shield")
                        .font(.system(size: 14, weight: .medium))
                        .contentTransition(.symbolEffect(.replace))
                    if appState.focusModeActive {
                        Text("Focus On")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .padding(.horizontal, appState.focusModeActive ? 16 : 14)
                .padding(.vertical, 9)
                .background(focusModeBackground)
                .foregroundStyle(
                    appState.focusModeActive ? Color.drift : (focusHovered ? .primary : .secondary)
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(focusHovered ? 1.03 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: focusHovered)
            .onHover { h in focusHovered = h }
            .accessibilityLabel(appState.focusModeActive ? "Focus Mode On" : "Focus Mode Off")
            .accessibilityHint("Toggles distraction blocking")
            .accessibilityAddTraits(appState.focusModeActive ? .isSelected : [])
        }
    }

    @ViewBuilder
    private var focusModeBackground: some View {
        if appState.focusModeActive {
            Capsule()
                .fill(Color.drift.opacity(0.12))
                .overlay(
                    Capsule().stroke(Color.drift.opacity(0.2), lineWidth: 1)
                )
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule().stroke(Color.primary.opacity(focusHovered ? 0.08 : 0.04), lineWidth: 1)
                )
        }
    }

    // MARK: - Metrics

    @ViewBuilder
    private var metricsPanel: some View {
        HStack(spacing: 0) {
            MetricItem(
                label: "Focus",
                value: "\(appState.session.focusPercent)%",
                color: Color("Green"),
                icon: "target"
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Focus")
            .accessibilityValue("\(appState.session.focusPercent) percent")

            MetricDivider()

            MetricItem(
                label: "Drift",
                value: "\(appState.session.driftScore)%",
                color: Color("Red"),
                icon: "arrow.triangle.branch"
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Drift")
            .accessibilityValue("\(appState.session.driftScore) percent")

            MetricDivider()

            MetricItem(
                label: "Switches",
                value: "\(appState.session.uniqueApps)",
                color: .primary,
                icon: "square.stack"
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App Switches")
            .accessibilityValue("\(appState.session.uniqueApps)")
        }
        .padding(.vertical, 16)
        .background(CardBackground(cornerRadius: 14))
    }

    // MARK: - App Timeline

    @ViewBuilder
    private var appTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App Timeline")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .accessibilityAddTraits(.isHeader)

            if appState.session.events.isEmpty {
                SessionEmptyTimeline()
            } else {
                SessionTimelineBar(events: appState.session.events)

                HStack(spacing: 16) {
                    LegendDot(label: "Productive", color: Color("Green"))
                    LegendDot(label: "Neutral", color: .secondary)
                    LegendDot(label: "Distraction", color: Color("Red"))
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .background(CardBackground(cornerRadius: 14))
    }

    // MARK: - Current App Bar

    @ViewBuilder
    private var currentAppBar: some View {
        let appName = tracker.activeApp
        let category = appState.session.currentCategory

        HStack(spacing: 10) {
            Circle()
                .fill(category.color)
                .frame(width: 8, height: 8)
                .shadow(color: category.color.opacity(0.5), radius: 3)

            Text(appName.isEmpty ? "Waiting for activity..." : appName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Text(category.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(category.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(category.color.opacity(0.1))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CardBackground(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current app: \(appName.isEmpty ? "None" : appName), \(category.label)")
    }

    // MARK: - Computed Properties

    private var statusLabel: String {
        if tracker.isIdle { return "Idle" }
        if tracker.isPaused { return "Paused" }
        if tracker.isTracking { return "Tracking" }
        return "Stopped"
    }

    private var statusColor: Color {
        if tracker.isIdle { return .orange }
        if tracker.isPaused { return .orange }
        if tracker.isTracking { return Color("Green") }
        return .secondary
    }

    private var actionButtonIcon: String {
        if tracker.isTracking && !tracker.isPaused { return "pause.fill" }
        return "play.fill"
    }

    private var actionButtonLabel: String {
        if !tracker.isTracking { return "Start" }
        if tracker.isPaused { return "Resume" }
        return "Pause"
    }

    private var actionAccessibilityHint: String {
        if !tracker.isTracking { return "Starts a new tracking session" }
        if tracker.isPaused { return "Resumes the paused session" }
        return "Pauses the current session"
    }

    // MARK: - Actions

    private func toggleTracking() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if tracker.isTracking && !tracker.isPaused {
                tracker.pause()
            } else {
                tracker.start()
            }
        }
    }
}

// MARK: - Session Progress Ring

private struct SessionProgressRing: View {
    let progress: CGFloat

    var body: some View {
        Circle()
            .trim(from: 0, to: max(progress, 0))
            .stroke(
                AngularGradient(
                    colors: [Color.drift.opacity(0.6), Color.drift],
                    center: .center,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(270)
                ),
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .frame(width: 200, height: 200)
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut(duration: 0.6), value: progress)
            .shadow(color: Color.drift.opacity(0.3), radius: 6)
    }
}

// MARK: - Metric Divider

private struct MetricDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.separatorColor).opacity(0.3))
            .frame(width: 1, height: 36)
            .accessibilityHidden(true)
    }
}

// MARK: - Session Empty Timeline

private struct SessionEmptyTimeline: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.quaternary)
            Text("Activity will appear here during tracking.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No activity yet. Activity will appear here during tracking.")
    }
}

// MARK: - Session Timeline Bar

private struct SessionTimelineBar: View {
    let events: [AppEvent]

    var body: some View {
        let segments = Array(events.suffix(40))

        GeometryReader { geo in
            HStack(spacing: 2) {
                let segmentCount = max(segments.count, 1)
                let spacing = CGFloat(segmentCount - 1) * 2
                let segmentWidth = max(4, (geo.size.width - spacing) / CGFloat(segmentCount))

                ForEach(segments) { event in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(event.category.color)
                        .frame(width: segmentWidth)
                }
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .animation(.easeInOut(duration: 0.3), value: events.count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("App timeline showing \(events.count) tracked activities")
    }
}

// MARK: - Helper Views

struct MetricItem: View {
    let label: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color.opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LegendDot: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) category")
    }
}
