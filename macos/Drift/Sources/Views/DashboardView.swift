import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker
    @State private var cardsAppeared = false

    // MARK: Layout

    private let statColumns = [
        GridItem(.flexible(), spacing: Space.lg),
        GridItem(.flexible(), spacing: Space.lg),
        GridItem(.flexible(), spacing: Space.lg),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Ambient radial gradient when tracking
            if tracker.isTracking {
                RadialGradient(
                    colors: [Color.productive.opacity(0.04), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 480
                )
                .ignoresSafeArea()
                .transition(.opacity.animation(Anim.appear))
                .allowsHitTesting(false)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                        .padding(.bottom, Space.section)

                    // Bento stat grid — 3 columns
                    LazyVGrid(columns: statColumns, spacing: Space.lg) {
                        HomeStatCard(
                            icon: "clock.fill",
                            iconColor: Color.accent,
                            value: formatDurationWords(appState.totalTrackedMs + appState.session.totalMs),
                            label: "Total Tracked"
                        )
                        .staggerAppear(index: 0, appeared: cardsAppeared)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Total Tracked: \(formatDurationWords(appState.totalTrackedMs + appState.session.totalMs))")

                        HomeStatCard(
                            icon: "target",
                            iconColor: Color.productive,
                            value: "\(averageFocus)%",
                            label: "Avg Focus",
                            trend: averageFocusTrend,
                            trendPositive: averageFocus >= 60
                        )
                        .staggerAppear(index: 1, appeared: cardsAppeared)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Average Focus: \(averageFocus) percent")

                        HomeStatCard(
                            icon: "flame.fill",
                            iconColor: Color.streak,
                            value: "\(appState.currentStreak)",
                            label: "Day Streak",
                            trend: appState.currentStreak > 0 ? "\(appState.currentStreak)d" : nil,
                            trendPositive: true
                        )
                        .staggerAppear(index: 2, appeared: cardsAppeared)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Day Streak: \(appState.currentStreak) days")
                    }
                    .padding(.bottom, Space.xxl)

                    // Current session card (glass) — only shown while tracking
                    if tracker.isTracking {
                        currentSessionCard
                            .padding(.bottom, Space.xxl)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top))
                                    .animation(Anim.appear),
                                removal: .opacity.animation(Anim.quick)
                            ))
                    }

                    // Activity timeline
                    activitySection
                        .staggerAppear(index: 3, appeared: cardsAppeared, yOffset: 18, baseDelay: 0.04)
                }
                .padding(Space.page)
            }
        }
        .animation(Anim.appear, value: tracker.isTracking)
        .task {
            guard !cardsAppeared else { return }
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(Anim.appear) {
                cardsAppeared = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(greeting)
                    .font(TypeScale.h2)
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text(dateString)
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if tracker.isTracking {
                StatusBadge(
                    label: sessionStatusLabel,
                    color: sessionStatusColor,
                    pulsing: !tracker.isPaused
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Button(action: { tracker.start() }) {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Start Tracking")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.sm)
                    .background(Color.accent)
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

    // MARK: Greeting / date helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12:  timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        case 17..<22: timeGreeting = "Good evening"
        default:      timeGreeting = "Good night"
        }
        if let name = appState.user?.displayName {
            return "\(timeGreeting), \(name)"
        }
        return timeGreeting
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    private var dateString: String {
        Self.dateFormatter.string(from: Date())
    }

    // MARK: - Stat helpers

    private var averageFocus: Int {
        let sessions = appState.pastSessions
        guard !sessions.isEmpty else {
            return appState.session.focusPercent
        }
        let total = sessions.reduce(0) { $0 + $1.focusPercent }
        return total / sessions.count
    }

    private var averageFocusTrend: String? {
        guard averageFocus > 0 else { return nil }
        return averageFocus >= 60 ? "+\(averageFocus - 50)%" : "\(averageFocus - 50)%"
    }

    // MARK: - Current Session card (glass treatment)

    private var currentSessionCard: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            sessionCardHeader
            sessionTimerRow
            FocusBar(
                focusFraction: CGFloat(appState.session.focusPercent) / 100.0,
                height: 7,
                showLabels: true
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Focus \(appState.session.focusPercent) percent, Drift \(appState.session.driftScore) percent")
            sessionControls
        }
        .padding(Space.xl)
        .background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
                .shadow(color: Color.productive.opacity(0.12), radius: 20, y: 8)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .hoverLift()
    }

    @ViewBuilder
    private var sessionCardHeader: some View {
        HStack(spacing: Space.sm) {
            StatusDot(status: tracker.isPaused ? .paused : .tracking)
            Text("Current Session")
                .font(TypeScale.heading)
                .foregroundStyle(.primary)
            Spacer()
            if !appState.session.currentApp.isEmpty {
                CurrentAppIndicator(
                    appName: appState.session.currentApp,
                    categoryColor: appState.session.currentCategory.color
                )
            }
        }
    }

    @ViewBuilder
    private var sessionTimerRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: Space.xl) {
            Text(formatDuration(appState.session.totalMs))
                .font(TypeScale.display)
                .tracking(-1)
                .contentTransition(.numericText())
                .animation(Anim.count, value: appState.session.totalMs)
                .accessibilityLabel("Session duration: \(formatDurationWords(appState.session.totalMs))")

            Spacer()

            VStack(alignment: .trailing, spacing: Space.xxs) {
                MetricPair(
                    value: "\(appState.session.focusPercent)%",
                    label: "focus",
                    valueFont: TypeScale.monoMd,
                    color: Color.productive,
                    alignment: .trailing
                )
            }
        }
    }

    @ViewBuilder
    private var sessionControls: some View {
        HStack(spacing: Space.sm) {
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

    // MARK: Session status helpers

    private var sessionStatusLabel: String {
        if tracker.isIdle { return "Idle" }
        if tracker.isPaused { return "Paused" }
        return "Tracking"
    }

    private var sessionStatusColor: Color {
        if tracker.isIdle { return Color.streak }
        if tracker.isPaused { return Color.streak }
        return Color.productive
    }

    // MARK: - Activity Timeline

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Today's Activity")
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)

            if appState.session.events.isEmpty {
                EmptyStateView(
                    icon: "text.line.first.and.arrowtriangle.forward",
                    title: "No activity yet",
                    message: "Start tracking to see your app usage timeline here."
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No activity yet. Start tracking to see your app usage.")
            } else {
                timelineContent
            }
        }
        .driftCard()
    }

    private var timelineContent: some View {
        let events = Array(appState.session.events.reversed().prefix(60))
        let grouped = groupedByPeriod(events)

        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(grouped, id: \.period) { group in
                // Period header (Morning / Afternoon / Evening)
                HStack(spacing: Space.sm) {
                    Text(group.period)
                        .font(TypeScale.tiny)
                        .foregroundStyle(.quaternary)
                        .textCase(.uppercase)
                        .tracking(1.0)
                    Rectangle()
                        .fill(Color.border)
                        .frame(height: 0.5)
                }
                .padding(.top, Space.md)
                .padding(.bottom, Space.xxs)

                ForEach(group.events) { event in
                    TimelineRow(event: event)
                }
            }
        }
    }

    // MARK: Timeline grouping

    private struct EventGroup {
        let period: String
        let events: [AppEvent]
    }

    private func groupedByPeriod(_ events: [AppEvent]) -> [EventGroup] {
        var morning: [AppEvent] = []
        var afternoon: [AppEvent] = []
        var evening: [AppEvent] = []

        for event in events {
            let hour = Calendar.current.component(.hour, from: event.timestamp)
            switch hour {
            case 0..<12:  morning.append(event)
            case 12..<17: afternoon.append(event)
            default:      evening.append(event)
            }
        }

        var groups: [EventGroup] = []
        // Show most-recent period first
        if !evening.isEmpty   { groups.append(EventGroup(period: "Evening",   events: evening)) }
        if !afternoon.isEmpty { groups.append(EventGroup(period: "Afternoon", events: afternoon)) }
        if !morning.isEmpty   { groups.append(EventGroup(period: "Morning",   events: morning)) }
        return groups
    }
}

// MARK: - Current App Indicator

private struct CurrentAppIndicator: View {
    let appName: String
    let categoryColor: Color

    var body: some View {
        HStack(spacing: Space.xs) {
            Circle()
                .fill(categoryColor)
                .frame(width: 7, height: 7)
                .shadow(color: categoryColor.opacity(0.5), radius: 3)
            Text(appName.isEmpty ? "No app" : appName)
                .font(TypeScale.bodySm)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xxs)
        .background {
            Capsule()
                .fill(Color.primary.opacity(0.05))
                .overlay(Capsule().strokeBorder(Color.border, lineWidth: 0.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current app: \(appName.isEmpty ? "None" : appName)")
    }
}

// MARK: - Home Stat Card (bento-grid cell)

struct HomeStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    var trend: String? = nil
    var trendPositive: Bool = true

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .top) {
                IconBadge(systemName: icon, color: iconColor, size: 32)
                Spacer()
                if let trend = trend {
                    DriftTag(text: trend, color: trendPositive ? Color.productive : Color.distraction)
                }
            }

            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(value)
                    .font(TypeScale.monoLg)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                    .animation(Anim.count, value: value)
                Text(label)
                    .font(TypeScale.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
        .hoverLift()
    }
}

// MARK: - Timeline Row

private struct TimelineRow: View {
    let event: AppEvent
    @State private var isHovered = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    var body: some View {
        HStack(spacing: Space.md) {
            // Time — fixed width, right-aligned, monospaced
            Text(Self.timeFormatter.string(from: event.timestamp))
                .font(TypeScale.monoXs)
                .foregroundStyle(.quaternary)
                .frame(width: 44, alignment: .trailing)

            // Category dot
            Circle()
                .fill(event.category.color)
                .frame(width: 7, height: 7)
                .shadow(color: event.category.color.opacity(0.45), radius: 2)

            // App name + window title
            VStack(alignment: .leading, spacing: 2) {
                Text(event.owner)
                    .font(TypeScale.bodyMd)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !event.title.isEmpty {
                    Text(event.title)
                        .font(TypeScale.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Duration
            if event.durationMs > 0 {
                Text(formatDurationCompact(Int(event.durationMs)))
                    .font(TypeScale.monoXs)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, Space.xs)
        .padding(.horizontal, Space.sm)
        .background {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.03) : .clear)
        }
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
        let dur = event.durationMs > 0 ? ", \(formatDurationWords(event.durationMs))" : ""
        return "\(event.owner) at \(time)\(dur), \(event.category.label)"
    }

    // Compact duration: "2h 4m" or "45m" or "30s"
    private func formatDurationCompact(_ ms: Int) -> String {
        let totalSec = ms / 1000
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        let s = totalSec % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }
}

// MARK: - Focus Progress Bar (kept for backward compat — use FocusBar from DriftDesign)

struct FocusProgressBar: View {
    let focusPercent: Int
    let driftScore: Int

    var body: some View {
        FocusBar(
            focusFraction: CGFloat(focusPercent) / 100.0,
            height: 7,
            showLabels: true
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus: \(focusPercent) percent. Drift: \(driftScore) percent.")
    }
}

// MARK: - Drift Action Button (shared component)

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
            .background(buttonBackground)
            .foregroundStyle(buttonForeground)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .driftButton()
        .scaleEffect(isHovered ? 1.03 : 1)
        .animation(Anim.tap, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .primary:
            Capsule().fill(isHovered ? Color.accent.opacity(0.85) : Color.accent)
        case .secondary:
            Capsule().fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.05))
        }
    }

    private var buttonForeground: Color {
        switch style {
        case .primary:   return .white
        case .secondary: return Color(.secondaryLabelColor)
        }
    }
}

// MARK: - Status Badge (shared component)

struct StatusBadge: View {
    let label: String
    let color: Color
    let pulsing: Bool

    var body: some View {
        HStack(spacing: Space.xs) {
            ZStack {
                if pulsing {
                    Circle()
                        .fill(color.opacity(0.35))
                        .frame(width: 7, height: 7)
                        .modifier(PulsingRing(color: color))
                }
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
            }
            .frame(width: 14, height: 14)

            Text(label)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.75))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) status")
    }
}

// Helper modifier for pulsing ring animation
private struct PulsingRing: ViewModifier {
    let color: Color
    @State private var animating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(animating ? 2.4 : 1.0)
            .opacity(animating ? 0 : 0.6)
            .animation(Anim.breathe, value: animating)
            .onAppear { animating = true }
    }
}

// MARK: - Stat Card (compact — kept for backward compat)

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
