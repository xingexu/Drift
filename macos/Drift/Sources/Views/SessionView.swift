import SwiftUI

// MARK: - Session View

struct SessionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker
    @State private var contentAppeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Space.xxl) {
                sessionHeader
                currentAppBar
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 10)
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
            }
            .padding(Space.page)
        }
        .task {
            guard !contentAppeared else { return }
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(Anim.appear) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var sessionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("Session")
                    .font(TypeScale.title)
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text("Track your focus in real-time")
                    .font(TypeScale.body)
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

    // MARK: - Current App Bar

    @ViewBuilder
    private var currentAppBar: some View {
        let appName = tracker.activeApp
        let category = appState.session.currentCategory
        let isFocused = category.label == "Productive"

        HStack(spacing: Space.md) {
            // Category glow dot
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.25))
                    .frame(width: 20, height: 20)
                    .blur(radius: 4)
                Circle()
                    .fill(category.color)
                    .frame(width: 7, height: 7)
            }
            .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: Space.xxxs) {
                Text("Currently tracking")
                    .font(TypeScale.caption)
                    .foregroundStyle(.tertiary)
                Text(appName.isEmpty ? "Waiting for activity..." : appName)
                    .font(TypeScale.bodyMd)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            DriftTag(text: category.label, color: category.color)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(
                            isFocused
                                ? Color.productive.opacity(0.35)
                                : Color.border,
                            lineWidth: isFocused ? 1 : 0.5
                        )
                }
                .shadow(
                    color: isFocused ? Color.productive.opacity(0.12) : .clear,
                    radius: 10,
                    y: 2
                )
        }
        .hoverLift()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current app: \(appName.isEmpty ? "None" : appName), \(category.label)")
    }

    // MARK: - Clock Ring

    @ViewBuilder
    private var clockRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.sep.opacity(0.12), lineWidth: 8)
                .frame(width: 240, height: 240)

            // Glow layer behind progress
            SessionProgressRing(
                progress: CGFloat(appState.session.focusPercent) / 100.0,
                ringSize: 240,
                strokeWidth: 8
            )

            // Center content
            VStack(spacing: Space.xs) {
                Text(formatDuration(appState.session.totalMs))
                    .font(TypeScale.monoLg)
                    .tracking(-1)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Session duration: \(formatDurationWords(appState.session.totalMs))")

                Text(statusLabel)
                    .font(TypeScale.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
        }
        .padding(.vertical, Space.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus ring at \(appState.session.focusPercent) percent. Duration: \(formatDurationWords(appState.session.totalMs))")
    }

    // MARK: - Control Strip

    @ViewBuilder
    private var controlStrip: some View {
        HStack(spacing: Space.md) {
            // Reset
            SecondaryButton("Reset", icon: "arrow.counterclockwise") {
                tracker.resetSession()
            }
            .disabled(!tracker.isTracking)
            .opacity(tracker.isTracking ? 1 : 0.4)
            .accessibilityLabel("Reset Session")
            .accessibilityHint("Saves and resets the current tracking session")

            // Main action — custom button to support contentTransition on icon
            SessionActionButton(
                icon: actionButtonIcon,
                label: actionButtonLabel,
                accessibilityHint: actionAccessibilityHint,
                action: toggleTracking
            )

            // Focus Mode
            SessionFocusButton(
                isActive: appState.focusModeActive,
                action: {
                    withAnimation(Anim.page) {
                        appState.focusModeActive.toggle()
                    }
                }
            )
        }
    }

    // MARK: - Metrics Panel

    @ViewBuilder
    private var metricsPanel: some View {
        HStack(spacing: Space.sm) {
            MetricPair(
                value: "\(appState.session.focusPercent)%",
                label: "Focus",
                valueFont: TypeScale.monoMd,
                color: Color.productive,
                alignment: .center
            )
            .frame(maxWidth: .infinity)
            .insetCard(padding: Space.md, radius: Radius.md)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Focus \(appState.session.focusPercent) percent")

            MetricPair(
                value: "\(appState.session.driftScore)%",
                label: "Drift",
                valueFont: TypeScale.monoMd,
                color: Color.distraction,
                alignment: .center
            )
            .frame(maxWidth: .infinity)
            .insetCard(padding: Space.md, radius: Radius.md)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Drift \(appState.session.driftScore) percent")

            MetricPair(
                value: "\(appState.session.uniqueApps)",
                label: "Switches",
                valueFont: TypeScale.monoMd,
                color: Color.streak,
                alignment: .center
            )
            .frame(maxWidth: .infinity)
            .insetCard(padding: Space.md, radius: Radius.md)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App switches \(appState.session.uniqueApps)")
        }
        .hoverLift()
    }

    // MARK: - App Timeline

    @ViewBuilder
    private var appTimeline: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("App Timeline")
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)

            if appState.session.events.isEmpty {
                SessionEmptyTimeline()
            } else {
                SessionTimelineBar(events: appState.session.events)

                HStack(spacing: Space.lg) {
                    LegendDot(label: "Productive", color: Color.productive)
                    LegendDot(label: "Neutral", color: .secondary)
                    LegendDot(label: "Distraction", color: Color.distraction)
                }
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .driftCard()
    }

    // MARK: - Computed Properties

    private var statusLabel: String {
        if tracker.isIdle { return "Idle" }
        if tracker.isPaused { return "Paused" }
        if tracker.isTracking { return "Tracking" }
        return "Stopped"
    }

    private var statusColor: Color {
        if tracker.isIdle { return Color.streak }
        if tracker.isPaused { return Color.streak }
        if tracker.isTracking { return Color.productive }
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
        withAnimation(Anim.tap) {
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
    var ringSize: CGFloat = 240
    var strokeWidth: CGFloat = 8

    var body: some View {
        ZStack {
            // Soft glow shadow ring underneath
            Circle()
                .trim(from: 0, to: max(progress, 0))
                .stroke(
                    Color.accent.opacity(0.3),
                    style: StrokeStyle(lineWidth: strokeWidth + 6, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .blur(radius: 6)
                .animation(Anim.appear, value: progress)

            // Main progress arc
            Circle()
                .trim(from: 0, to: max(progress, 0))
                .stroke(
                    AngularGradient(
                        colors: [Color.accent.opacity(0.7), Color.accent],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.accent.opacity(0.3), radius: 10)
                .animation(Anim.appear, value: progress)
        }
    }
}

// MARK: - Session Action Button (Start / Pause / Resume)

private struct SessionActionButton: View {
    let icon: String
    let label: String
    let accessibilityHint: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(label)
                    .font(TypeScale.heading)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm + 1)
            .background {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(isHovered ? Color.accent.opacity(0.88) : Color.accent)
                    .elevate(isHovered ? .sm : .xs)
            }
            .foregroundStyle(.white)
            .animation(Anim.hover, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(label)
        .accessibilityHint(accessibilityHint)
    }
}

// MARK: - Session Focus Mode Button

private struct SessionFocusButton: View {
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                Image(systemName: isActive ? "shield.fill" : "shield")
                    .font(.system(size: 13, weight: .medium))
                    .contentTransition(.symbolEffect(.replace))
                if isActive {
                    Text("Focus On")
                        .font(TypeScale.bodyMd)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs + 1)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.accent.opacity(0.12))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(Color.accent.opacity(0.25), lineWidth: 0.75)
                        }
                } else {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(isHovered ? Color(.controlColor) : Color(.controlBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(Color.border, lineWidth: 0.75)
                        }
                }
            }
            .foregroundStyle(
                isActive
                    ? Color.accent
                    : (isHovered ? Color.accent : Color(.labelColor))
            )
            .animation(Anim.hover, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(isActive ? "Focus Mode On" : "Focus Mode Off")
        .accessibilityHint("Toggles distraction blocking")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Session Empty Timeline

private struct SessionEmptyTimeline: View {
    var body: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: "waveform.path")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.quaternary)
            Text("Activity will appear here during tracking.")
                .font(TypeScale.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, Space.xl)
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
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(event.category.color)
                        .frame(width: segmentWidth)
                }
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .animation(Anim.quick, value: events.count)
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
        VStack(spacing: Space.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color.opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .sectionLabel()
        }
        .frame(maxWidth: .infinity)
    }
}

struct LegendDot: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: Space.xxs) {
            Circle()
                .fill(color)
                .frame(width: Space.xs, height: Space.xs)
            Text(label)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) category")
    }
}
