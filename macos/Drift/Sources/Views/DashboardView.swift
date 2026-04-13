import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker
    @State private var cardsAppeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.bottom, Space.page)

                statsRow
                    .padding(.bottom, Space.xxl)
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 12)

                if tracker.isTracking {
                    currentSessionSection
                        .padding(.bottom, Space.xxl)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)).animation(Anim.appear),
                            removal: .opacity.animation(Anim.quick)
                        ))
                }

                activityTimeline
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 18)
            }
            .padding(Space.page)
        }
        .task {
            guard !cardsAppeared else { return }
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(Anim.appear) {
                cardsAppeared = true
            }
        }
        .animation(Anim.appear, value: tracker.isTracking)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(greeting)
                    .font(TypeScale.title)
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text(dateString)
                    .font(TypeScale.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if !tracker.isTracking {
                Button(action: { tracker.start() }) {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Start Tracking")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.sm)
                    .background(Color.drift)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .driftButton()
                .accessibilityLabel("Start Tracking")
                .accessibilityHint("Begins a new focus tracking session")
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        case 17..<22: timeGreeting = "Good evening"
        default: timeGreeting = "Good night"
        }
        if let name = appState.user?.displayName {
            return "\(timeGreeting), \(name)"
        }
        return timeGreeting
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    private var dateString: String {
        Self.dateFormatter.string(from: Date())
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Space.lg) {
            HomeStatCard(
                icon: "clock.fill",
                iconColor: Color.drift,
                value: formatDurationWords(appState.totalTrackedMs + appState.session.totalMs),
                label: "Total Tracked",
                gradient: [Color.drift.opacity(0.08), Color.drift.opacity(0.02)]
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total Tracked")
            .accessibilityValue(formatDurationWords(appState.totalTrackedMs + appState.session.totalMs))

            HomeStatCard(
                icon: "target",
                iconColor: .productive,
                value: "\(averageFocus)%",
                label: "Avg Focus",
                gradient: [Color.productive.opacity(0.08), Color.productive.opacity(0.02)]
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Average Focus")
            .accessibilityValue("\(averageFocus) percent")

            HomeStatCard(
                icon: "flame.fill",
                iconColor: .streak,
                value: "\(appState.currentStreak)",
                label: "Day Streak",
                gradient: [Color.streak.opacity(0.08), Color.streak.opacity(0.02)]
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Day Streak")
            .accessibilityValue("\(appState.currentStreak) days")
        }
    }

    private var averageFocus: Int {
        let sessions = appState.pastSessions
        guard !sessions.isEmpty else {
            return appState.session.focusPercent
        }
        let total = sessions.reduce(0) { $0 + $1.focusPercent }
        return total / sessions.count
    }

    // MARK: - Current Session

    private var currentSessionSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sessionHeader

            sessionTimerRow

            FocusProgressBar(
                focusPercent: appState.session.focusPercent,
                driftScore: appState.session.driftScore
            )

            sessionControls
        }
        .driftCard()
        .hoverLift()
    }

    @ViewBuilder
    private var sessionHeader: some View {
        HStack {
            Text("Current Session")
                .sectionLabel()
            Spacer()
            StatusBadge(
                label: sessionStatusLabel,
                color: sessionStatusColor,
                pulsing: tracker.isTracking && !tracker.isPaused
            )
            .accessibilityLabel("Session status: \(sessionStatusLabel)")
        }
    }

    @ViewBuilder
    private var sessionTimerRow: some View {
        HStack(spacing: Space.xxl) {
            Text(formatDuration(appState.session.totalMs))
                .font(TypeScale.mono)
                .tracking(-1)
                .contentTransition(.numericText())
                .accessibilityLabel("Session duration: \(formatDurationWords(appState.session.totalMs))")

            Spacer()

            CurrentAppIndicator(
                appName: appState.session.currentApp,
                categoryColor: appState.session.currentCategory.color
            )
        }
    }

    @ViewBuilder
    private var sessionControls: some View {
        HStack(spacing: 10) {
            DriftActionButton(
                label: tracker.isPaused ? "Resume" : "Pause",
                icon: tracker.isPaused ? "play.fill" : "pause.fill",
                style: .primary
            ) {
                withAnimation(Anim.tap) {
                    if tracker.isPaused { tracker.start() } else { tracker.pause() }
                }
            }
            .accessibilityHint(tracker.isPaused ? "Resumes the current session" : "Pauses the current session")

            DriftActionButton(
                label: "Reset",
                icon: "arrow.counterclockwise",
                style: .secondary
            ) {
                tracker.resetSession()
            }
            .accessibilityHint("Saves and resets the current session")
        }
    }

    private var sessionStatusLabel: String {
        if tracker.isIdle { return "Idle" }
        if tracker.isPaused { return "Paused" }
        return "Tracking"
    }

    private var sessionStatusColor: Color {
        if tracker.isIdle { return .streak }
        if tracker.isPaused { return .streak }
        return .productive
    }

    // MARK: - Activity Timeline

    private var activityTimeline: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Today's Activity")
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)

            if appState.session.events.isEmpty {
                EmptyTimelineView()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(appState.session.events.reversed().prefix(50))) { event in
                        TimelineRow(event: event)
                    }
                }
            }
        }
        .driftCard()
    }
}

// MARK: - Current App Indicator

private struct CurrentAppIndicator: View {
    let appName: String
    let categoryColor: Color

    var body: some View {
        HStack(spacing: Space.sm) {
            Circle()
                .fill(categoryColor)
                .frame(width: 8, height: 8)
                .shadow(color: categoryColor.opacity(0.5), radius: 3)
            Text(appName.isEmpty ? "No app" : appName)
                .font(TypeScale.body)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current app: \(appName.isEmpty ? "None" : appName)")
    }
}

// MARK: - Focus Progress Bar

struct FocusProgressBar: View {
    let focusPercent: Int
    let driftScore: Int
    @State private var animatedFocus: CGFloat = 0
    @State private var animatedDrift: CGFloat = 0

    var body: some View {
        VStack(spacing: Space.sm) {
            GeometryReader { geo in
                HStack(spacing: Space.xxxs) {
                    let focusWidth = geo.size.width * animatedFocus / 100.0
                    let driftWidth = geo.size.width * animatedDrift / 100.0

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.productive, Color.productive.opacity(0.8)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(focusWidth, 0))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.distraction.opacity(0.8), Color.distraction],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(driftWidth, 0))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.sep.opacity(0.5))
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack {
                HStack(spacing: 5) {
                    Circle().fill(Color.productive).frame(width: 5, height: 5)
                    Text("Focused \(focusPercent)%")
                        .foregroundStyle(Color.productive)
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(Color.distraction).frame(width: 5, height: 5)
                    Text("Drifted \(driftScore)%")
                        .foregroundStyle(Color.distraction)
                }
            }
            .font(TypeScale.caption)
            .fontWeight(.medium)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus: \(focusPercent) percent. Drift: \(driftScore) percent.")
        .task(id: focusPercent) {
            withAnimation(Anim.appear) {
                animatedFocus = CGFloat(focusPercent)
            }
        }
        .task(id: driftScore) {
            withAnimation(Anim.appear) {
                animatedDrift = CGFloat(driftScore)
            }
        }
    }
}

// MARK: - Empty Timeline

private struct EmptyTimelineView: View {
    var body: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.quaternary)
            VStack(spacing: Space.xxs) {
                Text("No activity yet")
                    .font(TypeScale.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.tertiary)
                Text("Start tracking to see your app usage")
                    .font(TypeScale.caption)
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No activity yet. Start tracking to see your app usage.")
    }
}

// MARK: - Timeline Row

private struct TimelineRow: View {
    let event: AppEvent
    @State private var isHovered = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            Text(Self.timeFormatter.string(from: event.timestamp))
                .font(TypeScale.monoSm)
                .foregroundStyle(.tertiary)
                .frame(width: 64, alignment: .trailing)

            Circle()
                .fill(event.category.color)
                .frame(width: 7, height: 7)
                .padding(.top, 5)
                .shadow(color: event.category.color.opacity(0.4), radius: 2)

            VStack(alignment: .leading, spacing: Space.xxxs) {
                Text(event.owner)
                    .font(TypeScale.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if !event.title.isEmpty {
                    Text(event.title)
                        .font(TypeScale.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if event.durationMs > 0 {
                Text(formatDurationWords(event.durationMs))
                    .font(TypeScale.monoSm)
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, Space.sm)
        .padding(.horizontal, Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(isHovered ? Color.primary.opacity(0.03) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(Anim.quick) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(timelineAccessibilityLabel)
    }

    private var timelineAccessibilityLabel: String {
        let time = Self.timeFormatter.string(from: event.timestamp)
        let duration = event.durationMs > 0 ? ", \(formatDurationWords(event.durationMs))" : ""
        return "\(event.owner) at \(time)\(duration), \(event.category.label)"
    }
}

// MARK: - Home Stat Card

struct HomeStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let gradient: [Color]
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())

            Text(label)
                .sectionLabel()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(isHovered ? .thinMaterial : .ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(Color.primary.opacity(isHovered ? 0.06 : 0.03), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1)
        .shadow(
            color: isHovered ? iconColor.opacity(0.08) : .clear,
            radius: isHovered ? 12 : 0,
            y: isHovered ? 4 : 0
        )
        .animation(Anim.tap, value: isHovered)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Drift Action Button (Shared)

struct DriftActionButton: View {
    enum Style { case primary, secondary }

    let label: String
    let icon: String
    let style: Style
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(backgroundFill)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .driftButton()
        .scaleEffect(isHovered ? 1.03 : 1)
        .animation(Anim.tap, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var backgroundFill: some View {
        switch style {
        case .primary:
            Capsule().fill(isHovered ? Color.drift.opacity(0.85) : Color.drift)
        case .secondary:
            Capsule().fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.05))
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .secondary
        }
    }
}

// MARK: - Status Badge (Shared)

struct StatusBadge: View {
    let label: String
    let color: Color
    let pulsing: Bool

    var body: some View {
        HStack(spacing: Space.xs) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(pulsing ? 0.6 : 0), radius: pulsing ? 4 : 0)
                .opacity(pulsing ? 1 : 0.6)
                .animation(
                    pulsing
                        ? Anim.breathe
                        : .default,
                    value: pulsing
                )
            Text(label)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stat Card (Compact)

struct StatCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: Space.xxxs) {
            Text(value)
                .font(TypeScale.heading)
                .fontDesign(.monospaced)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(TypeScale.tiny)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}
