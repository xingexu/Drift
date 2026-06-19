import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Page header ──────────────────────────────────────
                pageHeader
                    .padding(.bottom, Space.xl)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.28), value: appeared)

                // ── Hero grid (layout-switchable) ────────────────────
                heroGridSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
                    .animation(.easeOut(duration: 0.30).delay(0.06), value: appeared)
                    .animation(.easeInOut(duration: 0.35), value: appState.homeLayout)
                    .padding(.bottom, Space.xxl)

                // ── Activity / Timeline ───────────────────────────────
                sectionHeader(title: "Today · Timeline", trailing: {
                    Button {
                        withAnimation(Anim.tap) { appState.currentTab = .history }
                    } label: {
                        HStack(spacing: Space.xxs) {
                            Text(todayShort)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                })
                .padding(.bottom, Space.sm)

                timelineCard
                    .padding(.bottom, Space.xxl)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(.easeOut(duration: 0.28).delay(0.18), value: appeared)

                // ── Top apps today ────────────────────────────────────
                sectionHeader(title: "Top apps today")
                    .padding(.bottom, Space.sm)

                topAppsCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(.easeOut(duration: 0.28).delay(0.24), value: appeared)
            }
            .padding(Space.page)
            .padding(.top, Space.md)
        }
        .onAppear {
            guard !appeared else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                appeared = true
            }
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(greeting)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitleString)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: Space.xs) {
                // Ghost: New session
                Button {
                    withAnimation(Anim.tap) { appState.currentTab = .session }
                } label: {
                    Label("New session", systemImage: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.xs + 1)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                        .strokeBorder(Color.border, lineWidth: 0.75)
                                )
                        )
                }
                .buttonStyle(.plain)

                // Primary: Start/pause tracking
                Button {
                    if tracker.isTracking { tracker.pause() } else { tracker.start() }
                } label: {
                    HStack(spacing: Space.xs) {
                        Image(systemName: tracker.isTracking ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(tracker.isTracking ? "Pause tracking" : "Start tracking")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.05, green: 0.10, blue: 0.18))
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.xs + 1)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(appState.accentColor)
                            .shadow(color: appState.accentColor.opacity(0.32), radius: 6, y: 2)
                    )
                }
                .buttonStyle(.plain)
                .animation(Anim.quick, value: tracker.isTracking)
            }
        }
    }

    // MARK: - Hero Focus Card

    private var heroFocusCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ambient accent radial (matches the ::before pseudo-element in handoff)
            // Label
            HStack(spacing: Space.xs) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text("TODAY'S FOCUS TIME")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, Space.md)

            // Giant focus time number
            heroNumberView
                .padding(.bottom, Space.lg)

            // Progress bar + label
            VStack(alignment: .leading, spacing: Space.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .fill(appState.accentColor)
                            .frame(width: geo.size.width * goalFraction, height: 4)
                            .animation(Anim.count, value: goalFraction)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("\(Int(goalFraction * 100))%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                    + Text(" of daily goal · 8h target")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
            .padding(.bottom, Space.xl)

            // Sparkline
            VStack(alignment: .leading, spacing: Space.xs) {
                SparklineView(data: sparkData, color: appState.accentColor)
                    .frame(height: 44)

                HStack {
                    Text("Last 7 days")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("avg " + avgSessionString)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, Space.sm)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.border.opacity(0.6))
                    .frame(height: 0.5)
            }
        }
        .padding(Space.xl + Space.sm)
        .background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    // Radial glow in top-right corner — matches CSS ::before
                    GeometryReader { geo in
                        RadialGradient(
                            colors: [appState.accentColor.opacity(0.08), .clear],
                            center: UnitPoint(x: 1.1, y: -0.1),
                            startRadius: 0,
                            endRadius: geo.size.width * 0.7
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.border, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        }
    }

    @ViewBuilder
    private var heroNumberView: some View {
        let h = focusHours
        let m = focusMinutes

        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Group {
                if h > 0 {
                    Text("\(h)")
                        .font(.system(size: 82, weight: .bold))
                        .tracking(-4)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(Anim.count, value: h)

                    Text("h")
                        .font(.system(size: 30, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, Space.sm)
                }

                Text("\(m)")
                    .font(.system(size: 82, weight: .bold))
                    .tracking(-4)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(Anim.count, value: m)

                Text("m")
                    .font(.system(size: 30, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Mini Cards (individual)

    private var focusRateMiniCard: some View {
        MiniCard(
            label: "Focus rate",
            trailing: {
                AnyView(
                    MiniRingStat(value: appState.session.focusPercent, color: Color.productive)
                )
            },
            bigValue: "\(appState.session.focusPercent)",
            bigUnit: "%",
            footer: {
                AnyView(
                    HStack(spacing: Space.xxs) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.productive)
                        Text("+4% vs avg")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.productive)
                    }
                    .padding(.horizontal, Space.xs)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.productive.opacity(0.10))
                            .overlay(Capsule().strokeBorder(Color.productive.opacity(0.22), lineWidth: 0.5))
                    )
                )
            }
        )
    }

    private var streakMiniCard: some View {
        MiniCard(
            label: "Streak",
            trailing: {
                AnyView(
                    Image(systemName: "flame.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.streak)
                )
            },
            bigValue: "\(appState.currentStreak)",
            bigUnit: nil,
            bigSuffix: " days",
            footer: {
                AnyView(
                    HStack(spacing: Space.xxs) {
                        ForEach(0..<7) { i in
                            Circle()
                                .fill(i < appState.currentStreak ? Color.streak : Color.primary.opacity(0.10))
                                .frame(width: 7, height: 7)
                                .animation(Anim.count.delay(Double(i) * 0.04), value: appState.currentStreak)
                        }
                    }
                )
            }
        )
    }

    private var distractionsMiniCard: some View {
        MiniCard(
            label: "Distractions",
            trailing: {
                AnyView(
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                )
            },
            bigValue: "\(distractionCount)",
            bigUnit: nil,
            footer: {
                AnyView(
                    HStack(spacing: Space.xxs) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.productive)
                        Text("−6 vs avg")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.productive)
                    }
                    .padding(.horizontal, Space.xs)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.productive.opacity(0.10))
                            .overlay(Capsule().strokeBorder(Color.productive.opacity(0.22), lineWidth: 0.5))
                    )
                )
            }
        )
    }

    // MARK: - Mini Cards Column

    private var miniCardsColumn: some View {
        VStack(spacing: Space.md) {
            focusRateMiniCard
            streakMiniCard
            distractionsMiniCard
        }
    }

    // MARK: - Hero Grid Section (layout-switchable)

    @ViewBuilder private var heroGridSection: some View {
        switch appState.homeLayout {
        case "Bento":
            HStack(alignment: .top, spacing: Space.md) {
                heroFocusCard.frame(maxWidth: .infinity)
                HStack(spacing: Space.md) {
                    focusRateMiniCard.frame(maxWidth: .infinity)
                    streakMiniCard.frame(maxWidth: .infinity)
                }
                .frame(width: 280)
            }
        case "Stack":
            VStack(spacing: Space.md) {
                heroFocusCard.frame(maxWidth: .infinity)
                HStack(spacing: Space.md) {
                    focusRateMiniCard.frame(maxWidth: .infinity)
                    streakMiniCard.frame(maxWidth: .infinity)
                    distractionsMiniCard.frame(maxWidth: .infinity)
                }
            }
        default: // Hero
            HStack(alignment: .top, spacing: Space.md) {
                heroFocusCard.frame(maxWidth: .infinity)
                miniCardsColumn.frame(width: 196)
            }
        }
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            // Axis labels
            HStack {
                ForEach(["6a","9a","12p","3p","6p","9p","12a"], id: \.self) { t in
                    Text(t)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.quaternary)
                    if t != "12a" { Spacer() }
                }
            }

            // Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(Color.border, lineWidth: 0.5)
                        )

                    // Timeline blocks (from session events if tracking, otherwise placeholder)
                    if appState.session.events.isEmpty {
                        // Placeholder blocks when no real data
                        Group {
                            timelineBlock(left: 0.12, width: 0.08, color: Color.productive, geo: geo)
                            timelineBlock(left: 0.22, width: 0.14, color: Color.productive, geo: geo)
                            timelineBlock(left: 0.38, width: 0.06, color: appState.accentColor, geo: geo)
                            timelineBlock(left: 0.46, width: 0.03, color: Color.streak, geo: geo)
                            timelineBlock(left: 0.52, width: 0.22, color: Color.productive, geo: geo)
                            timelineBlock(left: 0.76, width: 0.04, color: appState.accentColor, geo: geo)
                            timelineBlock(left: 0.82, width: 0.02, color: Color.distraction, geo: geo)
                            timelineBlock(left: 0.86, width: 0.10, color: Color.productive, geo: geo)
                        }

                        // "Now" marker
                        nowMarker(at: 0.94, geo: geo)
                    } else {
                        // Real session blocks
                        ForEach(timelineBlocks(geo: geo), id: \.id) { block in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(block.color)
                                .opacity(0.88)
                                .frame(width: max(4, block.width), height: geo.size.height - 16)
                                .offset(x: block.x, y: 8)
                        }
                    }
                }
            }
            .frame(height: 56)

            // Legend
            HStack(spacing: Space.xl) {
                legendDot(color: Color.productive, label: "Productive")
                legendDot(color: appState.accentColor, label: "Creative")
                legendDot(color: Color.streak, label: "Neutral")
                legendDot(color: Color.distraction, label: "Distracting")
                Spacer()
            }
        }
        .padding(Space.xl)
        .background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.border, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        }
    }

    private func timelineBlock(left: CGFloat, width: CGFloat, color: Color, geo: GeometryProxy) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .opacity(0.88)
            .frame(width: geo.size.width * width, height: geo.size.height - 16)
            .offset(x: geo.size.width * left, y: 8)
    }

    private func nowMarker(at pct: CGFloat, geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.primary)
                .frame(width: 2, height: geo.size.height)
        }
        .offset(x: geo.size.width * pct)
        .overlay(alignment: .top) {
            Text("now")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.controlBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.border, lineWidth: 0.5))
                )
                .offset(x: geo.size.width * pct + 6, y: -20)
        }
    }

    private struct TimelineBlock: Identifiable {
        let id = UUID()
        let x: CGFloat
        let width: CGFloat
        let color: Color
    }

    private func timelineBlocks(geo: GeometryProxy) -> [TimelineBlock] {
        let w = geo.size.width
        return appState.session.events.prefix(40).compactMap { event in
            let startFrac = CGFloat(event.timestamp.timeIntervalSinceNow / -86400)
            guard startFrac >= 0, startFrac <= 1 else { return nil }
            let durationFrac = CGFloat(event.durationMs / (86400 * 1000))
            let color: Color
            switch event.category {
            case .productive:  color = Color.productive
            case .distraction: color = Color.distraction
            case .neutral:     color = Color.streak
            }
            return TimelineBlock(x: w * startFrac, width: max(4, w * durationFrac), color: color)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: Space.xs) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Top Apps Card

    private var topAppsCard: some View {
        VStack(spacing: 0) {
            if topApps.isEmpty {
                EmptyStateView(
                    icon: "rectangle.stack",
                    title: "No app data yet",
                    message: "Start tracking to see your top apps here."
                )
                .padding(.vertical, Space.xl)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topApps.enumerated()), id: \.offset) { _, app in
                        AppUsageRow(app: app, maxMs: topApps.first?.ms ?? 1)
                        if app.name != topApps.last?.name {
                            Divider()
                                .padding(.horizontal, Space.lg)
                        }
                    }
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.border, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        }
    }

    // MARK: - Section Header Helper

    @ViewBuilder
    private func sectionHeader<T: View>(title: String, @ViewBuilder trailing: () -> T = { EmptyView() }) -> some View {
        HStack(spacing: Space.sm) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(1.6)

            Rectangle()
                .fill(Color.border.opacity(0.7))
                .frame(height: 0.5)

            trailing()
        }
    }

    // MARK: - Data Helpers

    private var totalMs: TimeInterval {
        let today = appState.pastSessions.filter { Calendar.current.isDateInToday($0.date) }
        return today.reduce(0) { $0 + $1.totalMs } + appState.session.totalMs
    }

    private var focusHours: Int   { Int(totalMs / 3_600_000) }
    private var focusMinutes: Int { Int((totalMs.truncatingRemainder(dividingBy: 3_600_000)) / 60_000) }

    private var goalFraction: CGFloat {
        let goal: TimeInterval = 8 * 3_600_000
        return min(CGFloat(totalMs / goal), 1.0)
    }

    private var distractionCount: Int {
        appState.session.events.filter { $0.category == .distraction }.count
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12:  base = "Good morning"
        case 12..<17: base = "Good afternoon"
        case 17..<22: base = "Good evening"
        default:      base = "Good night"
        }
        if let name = appState.user?.displayName { return "\(base), \(name)" }
        return base
    }

    private var subtitleString: String {
        if tracker.isTracking {
            return "You're on a roll. Keep the momentum going."
        }
        if appState.currentStreak > 1 {
            return "\(appState.currentStreak)-day streak. Don't break the chain."
        }
        return "Track your focus, understand your habits."
    }

    private static let todayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private var todayShort: String { Self.todayFormatter.string(from: Date()) }

    private var avgSessionString: String {
        let sessions = appState.pastSessions
        guard !sessions.isEmpty else { return "—" }
        let avg = sessions.reduce(0.0) { $0 + $1.totalMs } / Double(sessions.count)
        let m = Int(avg / 60_000)
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }

    // Sparkline — real data if available, placeholder otherwise
    private var sparkData: [Double] {
        let sessions = appState.pastSessions
        if sessions.count >= 2 {
            let groups = Dictionary(grouping: sessions.suffix(7)) { s in
                Calendar.current.startOfDay(for: s.date)
            }
            let days = (0..<7).map { i -> Double in
                let date = Calendar.current.date(byAdding: .day, value: -(6 - i), to: Date())!
                let day = Calendar.current.startOfDay(for: date)
                return groups[day]?.reduce(0.0) { $0 + $1.totalMs } ?? 0
            }
            return days
        }
        return [45, 80, 60, 120, 220, 30, 180]
    }

    struct AppUsageStat: Identifiable {
        let id = UUID()
        let name: String
        let ms: TimeInterval
        let productive: Bool
    }

    private var topApps: [AppUsageStat] {
        let events = appState.session.events
        guard !events.isEmpty else { return [] }
        var totals: [String: (ms: TimeInterval, productive: Bool)] = [:]
        for e in events {
            let prev = totals[e.owner, default: (0, e.category == .productive)]
            totals[e.owner] = (prev.ms + e.durationMs, e.category == .productive)
        }
        return totals
            .map { AppUsageStat(name: $0.key, ms: $0.value.ms, productive: $0.value.productive) }
            .sorted { $0.ms > $1.ms }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - Mini Card

private struct MiniCard<Footer: View, Trailing: View>: View {
    let label: String
    @ViewBuilder let trailing: () -> Trailing
    let bigValue: String
    let bigUnit: String?
    var bigSuffix: String? = nil
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            // Header
            HStack {
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Spacer()
                trailing()
            }

            // Big number
            HStack(alignment: .lastTextBaseline, spacing: Space.xxxs) {
                Text(bigValue)
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-1.2)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                if let unit = bigUnit {
                    Text(unit)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                if let suffix = bigSuffix {
                    Text(suffix)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .offset(y: -2)
                }
            }

            // Footer
            HStack {
                footer()
                Spacer()
            }
        }
        .padding(Space.md)
        .background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.border, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        }
    }
}

// MARK: - Mini Ring Stat

private struct MiniRingStat: View {
    let value: Int
    var color: Color = Color.productive
    var size: CGFloat = 42
    var stroke: CGFloat = 4

    @State private var animated = false

    private var fraction: CGFloat { CGFloat(value) / 100 }
    private var circumference: CGFloat { 2 * .pi * ((size - stroke) / 2) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: stroke)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: animated ? fraction : 0)
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(Anim.appear, value: animated)
        }
        .onAppear { animated = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Sparkline

struct SparklineView: View {
    let data: [Double]
    var color: Color = Color.accent

    var body: some View {
        Canvas { ctx, size in
            guard data.count > 1 else { return }
            let maxVal = data.max() ?? 1
            let step = size.width / CGFloat(data.count - 1)
            let pts = data.enumerated().map { i, v in
                CGPoint(
                    x: CGFloat(i) * step,
                    y: size.height - (CGFloat(v) / CGFloat(maxVal)) * (size.height - 4) - 2
                )
            }

            // Area fill
            var area = Path()
            area.move(to: CGPoint(x: 0, y: size.height))
            for p in pts { area.addLine(to: p) }
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.closeSubpath()
            ctx.fill(area, with: .linearGradient(
                Gradient(colors: [color.opacity(0.22), color.opacity(0.0)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            // Line
            var line = Path()
            line.move(to: pts[0])
            for p in pts.dropFirst() { line.addLine(to: p) }
            ctx.stroke(line, with: .color(color),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - App Usage Row

private struct AppUsageRow: View {
    let app: HomeView.AppUsageStat
    let maxMs: TimeInterval

    @State private var isHovered = false

    private var initial: String { String(app.name.prefix(1)).uppercased() }
    private var pct: Int { maxMs > 0 ? Int((app.ms / maxMs) * 100) : 0 }
    private var timeString: String {
        let m = Int(app.ms / 60_000)
        if m < 60 { return "\(m)m" }
        let mm = m % 60
        return mm == 0 ? "\(m / 60)h" : "\(m / 60)h \(mm)m"
    }
    private var badgeColor: Color {
        let hash = abs(app.name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        return Color(hue: Double(hash % 360) / 360.0, saturation: 0.55, brightness: 0.75)
    }

    var body: some View {
        HStack(spacing: Space.md) {
            // Initial badge
            Text(initial)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(badgeColor)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(badgeColor.opacity(0.13))
                )

            // Name + domain placeholder
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(app.name.lowercased() + ".app")
                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Radius.pill)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: Radius.pill)
                        .fill(app.productive ? Color.productive : Color.streak)
                        .frame(width: geo.size.width * (CGFloat(pct) / 100), height: 4)
                        .animation(Anim.count, value: pct)
                }
            }
            .frame(height: 4)

            // Time + pct
            HStack(alignment: .center, spacing: Space.sm) {
                Text(timeString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 48, alignment: .trailing)
                Text("\(pct)%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 36, alignment: .trailing)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .background(isHovered ? Color.primary.opacity(0.03) : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(Anim.hover, value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name), \(timeString), \(pct) percent of session")
    }
}

// MARK: - Reused sub-components (kept for backward compat with other views)

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
                    .font(TypeScale.caption)
                    .fontWeight(.semibold)
                Text(label)
                    .font(TypeScale.bodySm)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.sm + 1)
            .background(buttonBG)
            .foregroundStyle(buttonFG)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .driftButton()
        .scaleEffect(isHovered ? 1.03 : 1)
        .animation(Anim.tap, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityLabel(label)
    }

    @ViewBuilder private var buttonBG: some View {
        switch style {
        case .primary:   Capsule().fill(isHovered ? Color.accent.opacity(0.85) : Color.accent)
        case .secondary: Capsule().fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.05))
        }
    }
    private var buttonFG: Color {
        switch style {
        case .primary:   return .white
        case .secondary: return Color(.secondaryLabelColor)
        }
    }
}

struct StatusBadge: View {
    let label: String
    let color: Color
    let pulsing: Bool

    var body: some View {
        HStack(spacing: Space.xs) {
            ZStack {
                if pulsing {
                    Circle().fill(color.opacity(0.35)).frame(width: 7, height: 7)
                        .modifier(PulsingRing(color: color))
                }
                Circle().fill(color).frame(width: 7, height: 7)
            }
            .frame(width: 14, height: 14)

            Text(label)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Space.sm + 2)
        .padding(.vertical, Space.xxs + 1)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.75))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) status")
    }
}

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
                Text(value).font(TypeScale.monoLg).foregroundStyle(.primary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .contentTransition(.numericText()).animation(Anim.count, value: value)
                Text(label).font(TypeScale.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
        .hoverLift()
    }
}

struct FocusProgressBar: View {
    let focusPercent: Int
    let driftScore: Int
    var body: some View {
        FocusBar(focusFraction: CGFloat(focusPercent) / 100.0, height: 7, showLabels: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Focus: \(focusPercent) percent. Drift: \(driftScore) percent.")
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: Space.xxxs) {
            Text(value).font(TypeScale.heading).fontDesign(.monospaced).foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label).font(TypeScale.tiny).foregroundStyle(.tertiary).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label).accessibilityValue(value)
    }
}
