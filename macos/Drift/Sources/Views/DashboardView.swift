import SwiftUI
import AppKit

struct TrackingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var tracker: WindowTracker
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                massiveTrackingBar

                if hasVisibleActivity {
                    dashboardSummary
                    attentionMap

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: Space.lg) {
                            recentActivity
                                .frame(maxWidth: .infinity)
                            applicationSummary
                                .frame(width: 340)
                        }

                        VStack(alignment: .leading, spacing: Space.lg) {
                            recentActivity
                            applicationSummary
                        }
                    }
                } else {
                    emptyOverview
                }
            }
            .frame(maxWidth: 1320, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
        }
        .onAppear {
            withAnimation(Anim.appear) { appeared = true }
        }
    }

    private var massiveTrackingBar: some View {
        HStack(alignment: .center, spacing: 28) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: Space.md) {
                    PixelHeaderIcon(color: appState.accentColor)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting.uppercased())
                            .font(TypeScale.h1)
                            .foregroundStyle(Color.driftText)
                        Text("Live activity, context, and classification.")
                            .font(TypeScale.bodyMd)
                            .foregroundStyle(Color.driftMuted)
                    }
                }

                HStack(spacing: Space.lg) {
                    ZStack {
                        Rectangle()
                            .fill(tracker.activeCategory.color.opacity(0.18))
                            .frame(width: 56, height: 50)
                            .overlay(Rectangle().strokeBorder(tracker.activeCategory.color.opacity(0.36), lineWidth: 1))
                        PixelCurrentActivityIcon()
                            .frame(width: 42, height: 38)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(tracker.isTracking ? "CURRENT SIGNAL" : "READY TO CAPTURE")
                            .sectionLabel()
                        Text(tracker.activeApp.isEmpty ? "No active app" : tracker.activeApp)
                            .font(TypeScale.h2)
                            .lineLimit(1)
                        Text(currentContextSubtitle)
                            .font(TypeScale.caption)
                            .foregroundStyle(Color.driftMuted)
                            .lineLimit(1)
                    }

                    Text(tracker.activeCategory.label.uppercased())
                        .glassTag(color: tracker.activeCategory.color)
                }
            }

            Spacer(minLength: 24)

            VStack(alignment: .trailing, spacing: 16) {
                HStack(spacing: Space.sm) {
                    if tracker.isTracking {
                        StatusBadge(label: "Tracking", color: .productive, pulsing: true)
                    } else {
                        PrimaryButton("Start Tracking", icon: "play.fill", color: appState.accentColor) {
                            tracker.start()
                        }
                    }

                    MiniSignalStrip(category: tracker.activeCategory, active: tracker.isTracking)
                        .frame(width: 126)
                }

                HStack(spacing: 10) {
                    HeroMetricTile(label: "Active", value: formatDurationWords(todayTotal), color: appState.accentColor)
                    HeroMetricTile(label: "Focus", value: formatDurationWords(todayProductive), color: .productive)
                    HeroMetricTile(label: "Switches", value: "\(contextSwitches)", color: .streak)
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 26)
        .frame(minHeight: 178)
        .glassSurface(tint: appState.accentColor)
    }

    private var dashboardSummary: some View {
        HStack(spacing: 0) {
            efficiencyPanel
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.border.opacity(0.55))
                .frame(width: 1)

            metricRail
                .frame(width: 390)
        }
        .frame(height: 220)
        .glassSurface(tint: qualityColor)
    }

    private var efficiencyPanel: some View {
        HStack(spacing: 0) {
            EfficiencyGauge(score: efficiencyScore, accent: appState.accentColor)
                .frame(width: 222)

            VStack(alignment: .leading, spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(scoreHeadline)
                        .font(TypeScale.h2)
                    Text(scoreComparison)
                        .font(TypeScale.bodyMd)
                        .foregroundStyle(baselineDelta == nil ? .secondary : comparisonColor)
                }

                Divider()

                HStack(spacing: 42) {
                    signal(icon: "clock", value: formatDurationWords(longestProductiveStreak), label: "Longest focus")
                    signal(icon: "arrow.triangle.2.circlepath", value: "\(contextSwitches)", label: "Context switches")
                    signal(icon: "scope", value: formatDurationWords(todayDistraction), label: "Distracted")
                }

                HStack(spacing: 5) {
                    ForEach(0..<12, id: \.self) { index in
                        Rectangle()
                            .fill(index < max(1, efficiencyScore / 9) ? qualityColor.opacity(0.95) : Color.driftMuted.opacity(0.16))
                            .frame(width: 18, height: 7)
                    }
                }
                .padding(.top, Space.xs)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            CardDesertScene()
                .frame(maxWidth: 240)
                .opacity(0.74)
        }
    }

    private var metricRail: some View {
        VStack(spacing: 0) {
            MetricCell(icon: "timer", label: "ACTIVE TIME", value: formatDurationWords(todayTotal), detail: "Today", color: appState.accentColor)
            metricDivider
            MetricCell(icon: "target", label: "FOCUS TIME", value: formatDurationWords(todayProductive), detail: percent(todayProductive, of: todayTotal), color: .productive)
            metricDivider
            MetricCell(icon: "arrow.triangle.2.circlepath", label: "CONTEXT SWITCHES", value: "\(contextSwitches)", detail: switchesPerHourLabel, color: .streak)
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(height: 0.5)
            .padding(.leading, 78)
    }

    private var attentionMap: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ATTENTION MAP")
                        .sectionLabel()
                    Text("Your day as recorded by Drift")
                        .font(TypeScale.caption)
                        .foregroundStyle(Color.driftMuted)
                }
                Spacer()
                mapLegend(color: .productive, label: "Productive")
                mapLegend(color: Color(.tertiaryLabelColor), label: "Neutral")
                mapLegend(color: .distraction, label: "Distracting")
            }

            HStack(spacing: 3) {
                ForEach(Array(attentionCellCategories.enumerated()), id: \.offset) { index, category in
                    Rectangle()
                        .fill(attentionColor(category).opacity(visibleEvents.isEmpty ? placeholderOpacity(for: index) : 0.92))
                        .frame(maxWidth: .infinity)
                        .frame(height: index.isMultiple(of: 12) ? 31 : 25)
                        .overlay(alignment: .bottom) {
                            if index.isMultiple(of: 18) {
                                Rectangle()
                                    .fill(Color.streak.opacity(0.32))
                                    .frame(height: 2)
                            }
                        }
                        .help(category.label)
                }
            }
            .padding(6)
            .background {
                Rectangle()
                    .fill(Color.driftPanelInset.opacity(0.72))
                    .overlay {
                        Rectangle().strokeBorder(Color.border.opacity(0.42), lineWidth: 1)
                    }
            }
        }
        .padding(Space.lg)
        .frame(height: 128)
        .glassSurface(tint: appState.accentColor)
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader(title: "RECENT ACTIVITY")

            if recentEvents.isEmpty {
                compactEmpty(
                    icon: "point.3.connected.trianglepath.dotted",
                    title: tracker.isTracking ? "Reading current activity" : "No detailed activity yet",
                    message: tracker.isTracking ? "Your current app or site will appear here in a moment." : "Start tracking to build a timeline of apps and websites."
                )
            } else {
                ForEach(recentEvents) { event in
                    ActivityRow(event: event, isLive: event.id == Self.liveEventID)
                    if event.id != recentEvents.last?.id {
                        Divider()
                    }
                }
            }
        }
        .glassSurface(tint: .productive)
    }

    private var applicationSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader(title: "APPLICATIONS")

            if appStats.isEmpty {
                compactEmpty(
                    icon: "square.stack.3d.up",
                    title: "No application data",
                    message: tracker.isTracking ? "The active app will appear after Drift reads the frontmost window." : "Application usage appears once activity has been recorded."
                )
            } else {
                ForEach(Array(appStats.prefix(5))) { app in
                    ApplicationStatRow(app: app)
                    if app.id != appStats.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .glassSurface(tint: .streak)
    }

    private var emptyOverview: some View {
        HStack(spacing: 30) {
            EmptyDesertMarker(accent: appState.accentColor)
                .frame(width: 180, height: 150)

            VStack(alignment: .leading, spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("READY TO MAP YOUR DAY")
                        .font(TypeScale.h2)
                    Text("Start tracking to see apps, websites, page titles, duration, and context in one timeline.")
                        .font(TypeScale.bodyMd)
                        .foregroundStyle(Color.driftMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 520, alignment: .leading)
                }

                HStack(spacing: Space.sm) {
                    DriftTag(text: "APPS", color: .productive)
                    DriftTag(text: "SITES", color: appState.accentColor)
                    DriftTag(text: "CONTEXT", color: .streak)
                }

                HStack(spacing: Space.md) {
                    PrimaryButton("Start Tracking", icon: "play.fill", color: appState.accentColor) {
                        tracker.start()
                    }

                    Text("Never keystrokes or screen contents.")
                        .font(TypeScale.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 34)
        .padding(.vertical, 36)
        .frame(height: 264)
        .glassSurface(tint: appState.accentColor)
    }

    private func signal(icon: String, value: String, label: String) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.streak)
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(TypeScale.monoMd)
                    .monospacedDigit()
                Text(label)
                    .font(TypeScale.tiny)
                    .foregroundStyle(Color.driftMuted)
            }
        }
    }

    private func mapLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(TypeScale.tiny)
                .foregroundStyle(.tertiary)
        }
    }

    private func panelHeader(title: String) -> some View {
        HStack {
            Text(title)
                .sectionLabel()
            Spacer()
        }
        .padding(.horizontal, Space.lg)
        .frame(height: 42)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.border).frame(height: 0.5)
        }
    }

    private func compactEmpty(icon: String, title: String, message: String) -> some View {
        HStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.tertiary)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(TypeScale.bodySm).fontWeight(.semibold)
                Text(message).font(TypeScale.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(Space.lg)
    }

    private func percent(_ value: TimeInterval, of total: TimeInterval) -> String {
        guard total > 0 else { return "—" }
        return "\(Int((value / total * 100).rounded()))%"
    }

    private var greeting: String {
        "Tracking"
    }

    private var currentContextSubtitle: String {
        if !tracker.activeTitle.isEmpty { return tracker.activeTitle }
        if !tracker.activeURL.isEmpty { return tracker.activeURL }
        return "Start tracking to classify activity"
    }

    private var todaySessions: [PastSession] {
        appState.pastSessions.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayEvents: [AppEvent] {
        (todaySessions.flatMap { $0.events ?? [] } + appState.session.events)
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var todayTotal: TimeInterval {
        todaySessions.reduce(appState.session.totalMs) { $0 + $1.totalMs }
    }

    private var todayProductive: TimeInterval {
        todaySessions.reduce(appState.session.productiveMs) { $0 + $1.productiveMs }
    }

    private var todayDistraction: TimeInterval {
        todaySessions.reduce(appState.session.distractionMs) { $0 + $1.distractionMs }
    }

    private var hasActivity: Bool { todayTotal >= 60_000 }
    private var hasVisibleActivity: Bool {
        hasActivity || !visibleEvents.isEmpty
    }
    private var visibleEvents: [AppEvent] {
        var events = todayEvents
        if let liveEvent {
            events.append(liveEvent)
        }
        return events.sorted { $0.timestamp < $1.timestamp }
    }
    private var recentEvents: [AppEvent] {
        Array(visibleEvents.suffix(7).reversed())
    }
    private var liveEvent: AppEvent? {
        guard tracker.isTracking, !tracker.activeApp.isEmpty else { return nil }
        let elapsed = max(1_000, appState.session.totalMs - eventTotalMs)
        return AppEvent(
            id: Self.liveEventID,
            owner: tracker.activeApp,
            title: tracker.activeTitle,
            isBrowser: !tracker.activeURL.isEmpty,
            url: tracker.activeURL.isEmpty ? nil : tracker.activeURL,
            category: tracker.activeCategory,
            timestamp: Date(),
            durationMs: elapsed
        )
    }
    private var eventTotalMs: TimeInterval { todayEvents.reduce(0) { $0 + $1.durationMs } }
    private var visibleEventTotalMs: TimeInterval { visibleEvents.reduce(0) { $0 + $1.durationMs } }
    private var contextSwitches: Int { max(todayEvents.count - 1, 0) }
    private var longestProductiveStreak: TimeInterval {
        var longest: TimeInterval = 0
        var current: TimeInterval = 0
        for event in todayEvents {
            if event.category == .productive {
                current += event.durationMs
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return max(longest, appState.session.longestProductiveStreakMs)
    }

    private var efficiencyScore: Int {
        guard todayTotal > 0 else { return 0 }
        if todaySessions.isEmpty { return appState.session.efficiencyScore }
        let sessionScores = todaySessions.map(\.efficiencyScore)
        let weightedPast = zip(sessionScores, todaySessions).reduce(0.0) {
            $0 + Double($1.0) * $1.1.totalMs
        }
        let numerator = weightedPast + Double(appState.session.efficiencyScore) * appState.session.totalMs
        return Int((numerator / todayTotal).rounded())
    }

    private var baselineScore: Int? {
        let sessions = Array(appState.pastSessions.prefix(30))
        guard sessions.count >= 5 else { return nil }
        return Int((Double(sessions.reduce(0) { $0 + $1.efficiencyScore }) / Double(sessions.count)).rounded())
    }

    private var baselineDelta: Int? {
        baselineScore.map { efficiencyScore - $0 }
    }

    private var scoreHeadline: String {
        if todayTotal < 15 * 60_000 {
            return "Early tracking signal"
        }
        switch efficiencyScore {
        case 85...: return "A highly efficient day"
        case 70..<85: return "Strong, focused progress"
        case 50..<70: return "A mixed attention day"
        default: return "Attention was fragmented"
        }
    }

    private var scoreComparison: String {
        if todayTotal < 15 * 60_000 {
            return "Drift is still collecting enough context for a confident read."
        }
        guard let delta = baselineDelta else {
            return "Complete \(max(0, 5 - appState.pastSessions.count)) more sessions to establish your baseline."
        }
        if delta == 0 { return "In line with your 30-session baseline." }
        return "\(delta > 0 ? "+" : "")\(delta) points versus your personal baseline."
    }

    private var comparisonColor: Color {
        if todayTotal < 15 * 60_000 { return Color.driftMuted }
        return (baselineDelta ?? 0) >= 0 ? Color.productive : Color.distraction
    }

    private var qualityColor: Color {
        switch efficiencyScore {
        case 70...: return .productive
        case 40..<70: return .streak
        default: return .distraction
        }
    }

    private var attentionCellCategories: [AppCategory] {
        let target = 72
        guard !visibleEvents.isEmpty else {
            return (0..<target).map { index in
                if index.isMultiple(of: 13) { return .productive }
                if index.isMultiple(of: 29) { return .distraction }
                return .neutral
            }
        }

        var cells: [AppCategory] = []
        let total = max(visibleEventTotalMs, 1)
        for event in visibleEvents.suffix(56) {
            let count = max(1, Int((event.durationMs / total * Double(target)).rounded()))
            cells.append(contentsOf: Array(repeating: event.category, count: count))
        }
        if cells.count < target {
            cells.insert(contentsOf: Array(repeating: .neutral, count: target - cells.count), at: 0)
        }
        return Array(cells.suffix(target))
    }

    private func attentionColor(_ category: AppCategory) -> Color {
        switch category {
        case .productive: return .productive
        case .neutral: return Color.driftMuted
        case .distraction: return .distraction
        }
    }

    private func placeholderOpacity(for index: Int) -> Double {
        if index.isMultiple(of: 13) { return 0.34 }
        if index.isMultiple(of: 29) { return 0.28 }
        return index.isMultiple(of: 3) ? 0.18 : 0.12
    }

    private var switchesPerHourLabel: String {
        guard todayTotal > 0 else { return "—" }
        return String(format: "%.1f per hour", Double(contextSwitches) / (todayTotal / 3_600_000))
    }

    private var trackerLabel: String {
        if tracker.isIdle { return "Idle" }
        if tracker.isPaused { return "Paused" }
        if tracker.isTracking { return "Tracking" }
        return "Offline"
    }

    private var trackerColor: Color {
        if tracker.isPaused { return .streak }
        if tracker.isTracking { return .productive }
        return Color(.tertiaryLabelColor)
    }

    private struct AppStat: Identifiable {
        let id: String
        let name: String
        let durationMs: TimeInterval
        let category: AppCategory
    }

    private struct ApplicationStatRow: View {
        let app: AppStat

        var body: some View {
            HStack(spacing: Space.md) {
                ZStack {
                    Rectangle()
                        .fill(app.category.color.opacity(0.15))
                        .frame(width: 34, height: 34)
                        .overlay(Rectangle().strokeBorder(app.category.color.opacity(0.55), lineWidth: 1))
                    Text(String(app.name.prefix(1)).uppercased())
                        .font(TypeScale.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(app.category.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(TypeScale.bodySm)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.driftText)
                        .lineLimit(1)
                    Text(app.category.label)
                        .font(TypeScale.tiny)
                        .foregroundStyle(Color.driftMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDurationWords(app.durationMs))
                        .font(TypeScale.monoXs)
                        .foregroundStyle(Color.driftText.opacity(0.82))
                    Rectangle()
                        .fill(app.category.color.opacity(0.72))
                        .frame(width: 36, height: 4)
                }
            }
            .padding(.horizontal, Space.lg)
            .frame(height: 58)
        }
    }

    private var appStats: [AppStat] {
        let grouped = Dictionary(grouping: visibleEvents, by: \.owner)
        return grouped.map { name, events in
            let durations = Dictionary(grouping: events, by: \.category)
                .mapValues { $0.reduce(0) { $0 + $1.durationMs } }
            let category = durations.max(by: { $0.value < $1.value })?.key ?? .neutral
            return AppStat(
                id: name,
                name: name,
                durationMs: events.reduce(0) { $0 + $1.durationMs },
                category: category
            )
        }
        .sorted { $0.durationMs > $1.durationMs }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    private static let liveEventID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
}

private struct PixelHeaderIcon: View {
    let color: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(color.opacity(0.11))
                .overlay(Rectangle().strokeBorder(color.opacity(0.34), lineWidth: 1))

            HStack(alignment: .bottom, spacing: 3) {
                Rectangle().fill(color).frame(width: 4, height: 9)
                Rectangle().fill(color.opacity(0.78)).frame(width: 4, height: 18)
                Rectangle().fill(color).frame(width: 4, height: 13)
                Rectangle().fill(Color.productive).frame(width: 4, height: 22)
            }
            .padding(5)
        }
    }
}

private struct MetricCell: View {
    let icon: String
    let label: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: Space.lg) {
            IconBadge(systemName: icon, color: color, size: 44)
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(label)
                    .sectionLabel()
                Text(value)
                    .font(TypeScale.monoLg)
                    .monospacedDigit()
                Text(detail)
                    .font(TypeScale.caption)
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.xl)
        .frame(maxHeight: .infinity)
    }
}

private struct HeroMetricTile: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color.driftMuted)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Color.driftText)
            Rectangle()
                .fill(color.opacity(0.82))
                .frame(height: 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 118, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.driftPanelInset.opacity(0.58))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(color.opacity(0.18), lineWidth: 1))
        }
    }
}

private struct MiniSignalStrip: View {
    let category: AppCategory
    let active: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<10, id: \.self) { index in
                Rectangle()
                    .fill(barColor(for: index))
                    .frame(width: 6, height: CGFloat(8 + (index % 4) * 4))
            }
        }
        .frame(height: 30, alignment: .bottom)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.driftPanelInset.opacity(active ? 0.88 : 0.52))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.border.opacity(0.34), lineWidth: 1))
        }
    }

    private func barColor(for index: Int) -> Color {
        guard active else { return Color.driftMuted.opacity(0.18) }
        if index < 6 { return category.color.opacity(0.86) }
        return Color.driftMuted.opacity(0.22)
    }
}

private struct PixelCurrentActivityIcon: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color.accentDeep)
                .frame(width: 34, height: 8)
                .offset(y: 0)
            Rectangle()
                .fill(Color.streak)
                .frame(width: 12, height: 4)
                .offset(x: 8, y: -8)
            Rectangle()
                .fill(Color.productive)
                .frame(width: 6, height: 28)
                .offset(x: 3, y: -8)
            Rectangle()
                .fill(Color.productive)
                .frame(width: 11, height: 5)
                .offset(x: -5, y: -18)
            Rectangle()
                .fill(Color.productive)
                .frame(width: 10, height: 5)
                .offset(x: 14, y: -24)
        }
    }
}

private struct EmptyDesertMarker: View {
    let accent: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color.driftPanelInset.opacity(0.65))
                .overlay(Rectangle().strokeBorder(Color.driftBorder.opacity(0.38), lineWidth: 1))

            PixelMesa()
                .fill(Color.accentDeep.opacity(0.20))
                .frame(width: 112, height: 38)
                .offset(x: -18, y: -17)

            PixelCactusSprite(scale: 0.42)
                .offset(x: 42, y: -17)

            PixelDLogo(size: 42, background: accent)
                .offset(x: -42, y: -58)

            HStack(spacing: 4) {
                ForEach(0..<9, id: \.self) { index in
                    Rectangle()
                        .fill(index < 6 ? Color.productive.opacity(0.75) : Color.driftMuted.opacity(0.22))
                        .frame(width: 10, height: 7)
                }
            }
            .offset(y: -10)
        }
    }
}

private struct EfficiencyGauge: View {
    let score: Int
    let accent: Color

    private var fraction: CGFloat {
        CGFloat(max(0, min(score, 100))) / 100
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .trim(from: 0.11, to: 0.86)
                    .stroke(Color.driftMuted.opacity(0.18), style: StrokeStyle(lineWidth: 9, lineCap: .butt))
                    .rotationEffect(.degrees(132))
                Circle()
                    .trim(from: 0.11, to: 0.11 + 0.75 * fraction)
                    .stroke(
                        LinearGradient(colors: [Color.distraction, Color.streak], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 9, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(132))
                VStack(spacing: 6) {
                    Text("\(score)")
                        .font(.system(size: 34, weight: .regular, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.streak)
                    Text("EFFICIENCY")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Color.driftMuted)
                }
            }
            .frame(width: 116, height: 116)

            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { index in
                    Rectangle()
                        .fill(index * 10 < score ? Color.distraction.opacity(index < 3 ? 1 : 0.85) : Color.driftMuted.opacity(0.18))
                        .frame(width: 8, height: 6)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.border.opacity(0.5)).frame(width: 1)
        }
    }
}

private struct CardDesertScene: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(Color(red: 0.35, green: 0.16, blue: 0.20).opacity(0.38)).frame(height: 20)
                Rectangle().fill(Color(red: 0.44, green: 0.20, blue: 0.22).opacity(0.44)).frame(height: 30)
            }

            PixelCloud()
                .fill(Color(red: 0.31, green: 0.15, blue: 0.24).opacity(0.45))
                .frame(width: 72, height: 18)
                .offset(x: -78, y: -76)
            PixelCloud()
                .fill(Color(red: 0.31, green: 0.15, blue: 0.24).opacity(0.35))
                .frame(width: 52, height: 13)
                .offset(x: 44, y: -88)

            PixelMesa()
                .fill(Color(red: 0.31, green: 0.15, blue: 0.24).opacity(0.72))
                .frame(width: 86, height: 31)
                .offset(x: -54, y: -23)
            PixelMesa()
                .fill(Color(red: 0.31, green: 0.15, blue: 0.24).opacity(0.58))
                .frame(width: 68, height: 22)
                .offset(x: 24, y: -22)
            PixelCactusSprite(scale: 0.62)
                .offset(x: 88, y: -11)
        }
        .clipped()
    }
}

private struct PixelCloud: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h * 0.8))
        p.addLine(to: CGPoint(x: w * 0.12, y: h * 0.8))
        p.addLine(to: CGPoint(x: w * 0.12, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.24, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.24, y: h * 0.22))
        p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.22))
        p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.08))
        p.addLine(to: CGPoint(x: w * 0.63, y: h * 0.08))
        p.addLine(to: CGPoint(x: w * 0.63, y: h * 0.25))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.25))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.91, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.91, y: h * 0.8))
        p.addLine(to: CGPoint(x: w, y: h * 0.8))
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

private struct PixelMesa: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: w * 0.14, y: h))
        p.addLine(to: CGPoint(x: w * 0.14, y: h * 0.60))
        p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.60))
        p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.60))
        p.addLine(to: CGPoint(x: w, y: h * 0.60))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

private struct PixelCactusSprite: View {
    var scale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 0.33, green: 0.46, blue: 0.24)).frame(width: 16, height: 88)
            Rectangle().fill(Color(red: 0.43, green: 0.58, blue: 0.24)).frame(width: 5, height: 88).offset(x: -5.5)
            Rectangle().fill(Color(red: 0.20, green: 0.31, blue: 0.18)).frame(width: 4, height: 88).offset(x: 6)
            Rectangle().fill(Color(red: 0.33, green: 0.46, blue: 0.24)).frame(width: 18, height: 12).offset(x: -14, y: -46)
            Rectangle().fill(Color(red: 0.33, green: 0.46, blue: 0.24)).frame(width: 10, height: 29).offset(x: -20, y: -56)
            Rectangle().fill(Color(red: 0.33, green: 0.46, blue: 0.24)).frame(width: 19, height: 12).offset(x: 15, y: -56)
            Rectangle().fill(Color(red: 0.33, green: 0.46, blue: 0.24)).frame(width: 10, height: 31).offset(x: 21, y: -66)
        }
        .frame(width: 50, height: 92)
        .scaleEffect(scale, anchor: .bottom)
    }
}

private struct ActivityRow: View {
    let event: AppEvent
    var isLive: Bool = false

    var body: some View {
        HStack(spacing: Space.md) {
            Rectangle()
                .fill(event.category.color.opacity(isLive ? 0.95 : 0.62))
                .frame(width: 4)

            Text(isLive ? "LIVE" : Self.timeFormatter.string(from: event.timestamp))
                .font(TypeScale.monoXs)
                .foregroundStyle(isLive ? Color.productive : Color.driftMuted)
                .frame(width: 68, alignment: .leading)

            ZStack {
                Rectangle()
                    .fill(event.category.color.opacity(0.16))
                    .frame(width: 32, height: 32)
                    .overlay(Rectangle().strokeBorder(event.category.color.opacity(0.66), lineWidth: 1))
                Text(String(rowTitle.prefix(1)).uppercased())
                    .font(TypeScale.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(event.category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rowTitle)
                    .font(TypeScale.bodySm)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.driftText)
                    .lineLimit(1)
                Text(rowSubtitle)
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.driftMuted)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatDurationWords(event.durationMs))
                .font(TypeScale.monoXs)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)

            Text(event.category.label.uppercased())
                .font(TypeScale.tiny)
                .foregroundStyle(event.category.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.trailing, Space.lg)
        .frame(height: 52)
        .background(isLive ? Color.productive.opacity(0.075) : Color.clear)
    }

    private var rowTitle: String {
        if let domain = domainName(from: event.url), !domain.isEmpty {
            return domain
        }
        return event.owner
    }

    private var rowSubtitle: String {
        let title = event.title.isEmpty ? event.owner : event.title
        if let url = event.url, !url.isEmpty {
            return "\(event.owner) - \(title)"
        }
        return title
    }

    private func domainName(from value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if let url = URL(string: value), let host = url.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return value
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/")
            .first
            .map(String.init)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

private extension View {
    func glassSurface(tint: Color = .accent) -> some View {
        background {
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            ZStack {
                shape
                    .fill(Color.driftPanel.opacity(0.90))
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(0.16)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        tint.opacity(0.06),
                        Color.black.opacity(0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            }
            .shadow(color: Color.black.opacity(0.24), radius: 0, x: 5, y: 5)
            .overlay {
                shape
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            }
            .overlay {
                shape
                    .strokeBorder(Color.driftBorder.opacity(0.52), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(tint.opacity(0.70))
                    .frame(width: 46, height: 2)
                    .padding(.leading, 28)
            }
        }
    }

    func glassTag(color: Color) -> some View {
        font(TypeScale.tiny)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(color.opacity(0.38), lineWidth: 1))
            }
    }
}

struct StatusBadge: View {
    let label: String
    let color: Color
    var pulsing: Bool = false
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        HStack(spacing: Space.xs) {
            ZStack {
                if pulsing {
                    Rectangle()
                        .stroke(color.opacity(0.35), lineWidth: 1)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulseScale)
                        .opacity(pulseScale > 1 ? 0 : 0.8)
                }
                Rectangle()
                    .fill(color)
                    .frame(width: 7, height: 7)
            }
            Text(label)
                .font(TypeScale.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xxs)
        .background(
            Rectangle()
                .fill(color.opacity(0.10))
                .overlay(Rectangle().strokeBorder(color.opacity(0.28), lineWidth: 1))
        )
        .onAppear {
            guard pulsing else { return }
            withAnimation(Anim.breathe) { pulseScale = 2.1 }
        }
    }
}

private struct PixelDustOverlay: View {
    let isDark: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10.0)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let width = max(Int(size.width), 1)
                let height = max(Int(size.height), 1)

                for index in 0..<90 {
                    let baseX = CGFloat((index * 83 + 29) % width)
                    let drift = CGFloat((time * Double(4 + index % 5)).truncatingRemainder(dividingBy: 34))
                    let x = (baseX + drift).truncatingRemainder(dividingBy: size.width)
                    let y = CGFloat((index * 47 + 61) % height)
                    let opacity = isDark ? 0.08 : 0.10
                    let color = index.isMultiple(of: 9)
                        ? Color.streak.opacity(opacity * 1.8)
                        : Color.white.opacity(opacity)
                    context.fill(
                        Path(CGRect(x: x.rounded(), y: y.rounded(), width: index.isMultiple(of: 11) ? 2 : 1, height: 1)),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DriftAmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let accent: Color
    let reduceMotion: Bool
    var showLizard: Bool = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("drift-desert-night", bundle: .module)
                    .resizable()
                    .interpolation(.none)
                    .antialiased(false)
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay {
                        Rectangle()
                            .fill(Color.driftBackground.opacity(colorScheme == .dark ? 0.08 : 0.46))
                    }
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(colorScheme == .dark ? 0.10 : 0.00),
                                Color.clear,
                                Color.black.opacity(colorScheme == .dark ? 0.18 : 0.00)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                if !reduceMotion {
                    PixelDustOverlay(isDark: colorScheme == .dark)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawScene(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let isDark = colorScheme == .dark
        let width = max(Int(size.width), 1)
        let height = max(Int(size.height), 1)
        let skyHeight = isDark ? size.height * 0.86 : size.height * 0.87

        func block(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: Color) {
            context.fill(
                Path(CGRect(x: x.rounded(), y: y.rounded(), width: width.rounded(), height: height.rounded())),
                with: .color(color)
            )
        }

        func cloud(_ x: CGFloat, _ y: CGFloat, _ unit: CGFloat, opacity: Double) {
            let shadow = isDark ? Color(red: 0.24, green: 0.13, blue: 0.32).opacity(opacity) : Color(red: 0.80, green: 0.69, blue: 0.82).opacity(opacity)
            let light = isDark ? Color(red: 0.36, green: 0.22, blue: 0.45).opacity(opacity * 0.88) : Color(red: 0.92, green: 0.82, blue: 0.88).opacity(opacity * 0.85)
            block(x, y + unit * 3, unit * 10, unit * 2, shadow)
            block(x + unit, y + unit * 2, unit * 3, unit * 2, shadow)
            block(x + unit * 3, y + unit, unit * 4, unit * 3, light)
            block(x + unit * 6, y + unit * 2, unit * 3, unit * 2, light)
            block(x + unit * 8, y + unit * 3, unit * 3, unit, shadow)
        }

        func cactus(_ x: CGFloat, _ ground: CGFloat, _ unit: CGFloat, opacity: Double = 1) {
            let dark = (isDark ? Color(red: 0.08, green: 0.20, blue: 0.14) : Color(red: 0.17, green: 0.31, blue: 0.20)).opacity(opacity)
            let green = (isDark ? Color(red: 0.25, green: 0.39, blue: 0.17) : Color(red: 0.34, green: 0.48, blue: 0.25)).opacity(opacity)
            let light = (isDark ? Color(red: 0.47, green: 0.56, blue: 0.18) : Color(red: 0.57, green: 0.64, blue: 0.30)).opacity(opacity)
            block(x, ground - unit * 9, unit * 3, unit * 9, green)
            block(x, ground - unit * 9, unit, unit * 9, dark)
            block(x + unit * 2, ground - unit * 9, unit, unit * 9, light)
            block(x - unit * 3, ground - unit * 6, unit * 3, unit * 2, green)
            block(x - unit * 3, ground - unit * 8, unit * 2, unit * 4, green)
            block(x + unit * 3, ground - unit * 5, unit * 3, unit * 2, dark)
            block(x + unit * 5, ground - unit * 7, unit * 2, unit * 4, green)
            block(x - unit, ground, unit * 5, unit, Color.driftShadow.opacity(0.34 * opacity))
        }

        func mesa(_ centerX: CGFloat, _ baseY: CGFloat, _ unit: CGFloat, _ color: Color, _ highlight: Color) {
            block(centerX - unit * 3, baseY - unit * 5, unit * 6, unit, highlight)
            block(centerX - unit * 5, baseY - unit * 4, unit * 10, unit, color)
            block(centerX - unit * 7, baseY - unit * 3, unit * 14, unit, color)
            block(centerX - unit * 9, baseY - unit * 2, unit * 18, unit * 2, color)
            block(centerX - unit * 4, baseY - unit * 4, unit, unit * 3, Color.driftShadow.opacity(0.12))
            block(centerX, baseY - unit * 4, unit, unit * 2, Color.driftShadow.opacity(0.10))
        }

        func lizard(_ x: CGFloat, _ y: CGFloat, tongue: Bool, tailUp: Bool) {
            let body = isDark ? Color(red: 0.33, green: 0.49, blue: 0.25) : Color(red: 0.39, green: 0.55, blue: 0.29)
            let dark = isDark ? Color(red: 0.12, green: 0.25, blue: 0.15) : Color(red: 0.20, green: 0.35, blue: 0.19)
            let belly = isDark ? Color(red: 0.56, green: 0.63, blue: 0.25) : Color(red: 0.62, green: 0.67, blue: 0.32)
            block(x + 10, y + 3, 21, 7, body)
            block(x + 15, y + 8, 12, 2, belly)
            block(x + 31, y + 2, 8, 6, body)
            block(x + 36, y + 4, 2, 2, Color.driftText.opacity(isDark ? 0.72 : 0.56))
            block(x + 3, y + (tailUp ? 1 : 5), 8, 3, dark)
            block(x, y + (tailUp ? 0 : 6), 5, 2, dark)
            block(x + 11, y + 10, 3, 3, dark)
            block(x + 22, y + 10, 3, 3, dark)
            block(x + 29, y + 9, 3, 3, dark)
            block(x + 39, y + 6, 3, 2, body)
            if tongue {
                block(x + 42, y + 6, 5, 1, Color.distraction)
                block(x + 47, y + 5, 2, 1, Color.distraction)
            }
        }

        let skyBands: [Color] = isDark
            ? [
                Color(red: 0.026, green: 0.023, blue: 0.071),
                Color(red: 0.039, green: 0.033, blue: 0.095),
                Color(red: 0.052, green: 0.043, blue: 0.122),
                Color(red: 0.070, green: 0.050, blue: 0.153),
                Color(red: 0.094, green: 0.061, blue: 0.183),
                Color(red: 0.126, green: 0.075, blue: 0.208)
            ]
            : [
                Color(red: 0.996, green: 0.987, blue: 0.970),
                Color(red: 0.995, green: 0.976, blue: 0.948),
                Color(red: 0.992, green: 0.961, blue: 0.921),
                Color(red: 0.984, green: 0.936, blue: 0.890),
                Color(red: 0.972, green: 0.907, blue: 0.845),
                Color(red: 0.955, green: 0.870, blue: 0.790)
            ]
        let bandHeight = skyHeight / CGFloat(skyBands.count)
        for (index, color) in skyBands.enumerated() {
            block(0, CGFloat(index) * bandHeight, size.width, bandHeight + 1, color)
        }

        if isDark {
            for index in 0..<72 {
                let x = CGFloat((index * 149 + 37) % width)
                let y = CGFloat((index * 83 + 19) % max(Int(skyHeight * 0.72), 1))
                let side: CGFloat = index.isMultiple(of: 11) ? 2 : 1
                let star = index.isMultiple(of: 7) ? Color.streak.opacity(0.38) : Color.white.opacity(0.24)
                block(x, y, side, side, star)
                if index.isMultiple(of: 17) {
                    block(x - 2, y, 5, 1, star.opacity(0.72))
                    block(x, y - 2, 1, 5, star.opacity(0.72))
                }
            }
        }

        for index in 0..<112 {
            let x = CGFloat((index * 71 + 13) % width)
            let range = max(Int(size.height - skyHeight), 1)
            let y = skyHeight + CGFloat((index * 47 + 29) % range)
            let particle = index.isMultiple(of: 3)
                ? Color.streak.opacity(isDark ? 0.16 : 0.22)
                : (isDark ? Color.white.opacity(0.07) : Color.accentDeep.opacity(0.13))
            block(x, y, index.isMultiple(of: 5) ? 2 : 1, index.isMultiple(of: 7) ? 2 : 1, particle)
        }

        let mesaColor = isDark ? Color(red: 0.20, green: 0.08, blue: 0.18).opacity(0.34) : Color(red: 0.72, green: 0.57, blue: 0.68).opacity(0.13)
        let mesaLight = isDark ? Color(red: 0.35, green: 0.13, blue: 0.24).opacity(0.28) : Color(red: 0.96, green: 0.70, blue: 0.52).opacity(0.16)
        mesa(size.width * 0.18, skyHeight + 2, 7, mesaColor, mesaLight)
        mesa(size.width * 0.82, skyHeight + 5, 6, mesaColor, mesaLight)

        let sandBands: [Color] = isDark
            ? [
                Color(red: 0.22, green: 0.10, blue: 0.15),
                Color(red: 0.28, green: 0.13, blue: 0.15),
                Color(red: 0.34, green: 0.17, blue: 0.15),
                Color(red: 0.40, green: 0.20, blue: 0.15)
            ]
            : [
                Color(red: 0.99, green: 0.87, blue: 0.74),
                Color(red: 0.99, green: 0.82, blue: 0.67),
                Color(red: 0.97, green: 0.76, blue: 0.59),
                Color(red: 0.94, green: 0.70, blue: 0.52)
            ]
        let groundHeight = size.height - skyHeight
        for (index, color) in sandBands.enumerated() {
            let y = skyHeight + groundHeight * CGFloat(index) / CGFloat(sandBands.count)
            block(0, y, size.width, groundHeight / CGFloat(sandBands.count) + 1, color)
        }

        for index in 0..<32 {
            let x = CGFloat((index * 173 + 41) % width)
            let y = skyHeight + CGFloat((index * 31 + 9) % max(Int(groundHeight), 1))
            let run = CGFloat(8 + (index * 7) % 34)
            block(x, y, run, 2, Color.driftShadow.opacity(isDark ? 0.18 : 0.12))
        }

        cactus(size.width * 0.08, size.height - 10, max(3, min(6, size.width / 180)), opacity: 0.76)
        cactus(size.width * 0.90, size.height - 12, max(3, min(5, size.width / 220)), opacity: 0.66)

        guard showLizard else { return }
        let routeDuration = 86.0
        let pauseEvery = 18.0
        let pauseDuration = 2.0
        let raw = reduceMotion ? 12.0 : time.truncatingRemainder(dividingBy: routeDuration)
        let segmentTime = raw.truncatingRemainder(dividingBy: pauseEvery)
        let pausesCompleted = floor(raw / pauseEvery)
        let pauseOverflow = max(0, segmentTime - (pauseEvery - pauseDuration))
        let movingTime = raw - pausesCompleted * pauseDuration - pauseOverflow
        let movingTotal = routeDuration - floor(routeDuration / pauseEvery) * pauseDuration
        let progress = CGFloat(max(0, min(1, movingTime / movingTotal)))
        let lizardX = -54 + (size.width + 108) * progress
        let lizardY = CGFloat(height) - 24
        let isPaused = reduceMotion || segmentTime > pauseEvery - pauseDuration
        let tongue = isPaused && !reduceMotion && Int((segmentTime - (pauseEvery - pauseDuration)) * 4).isMultiple(of: 2)
        let tailUp = reduceMotion ? false : Int(time * 2).isMultiple(of: 2)
        lizard(lizardX, lizardY, tongue: tongue, tailUp: tailUp)
    }
}
