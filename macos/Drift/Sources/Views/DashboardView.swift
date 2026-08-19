import SwiftUI

struct TrackingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var tracker: WindowTracker
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.xxl) {
                header
                currentContext

                efficiencyPanel
                metricStrip
                attentionMap

                HStack(alignment: .top, spacing: Space.lg) {
                    recentActivity
                        .frame(maxWidth: .infinity)
                    applicationSummary
                        .frame(width: 360)
                }
            }
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.xxl)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
        .onAppear {
            withAnimation(Anim.appear) { appeared = true }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            HStack(alignment: .top, spacing: Space.md) {
                Image(systemName: "sparkle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.streak)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(greeting.uppercased())
                        .font(TypeScale.h1)
                    Text("Live activity, context, and classification.")
                        .font(TypeScale.bodyMd)
                        .foregroundStyle(Color.driftMuted)
                }
            }

            Spacer()
        }
    }

    private var currentContext: some View {
        HStack(spacing: Space.lg) {
            Rectangle()
                .fill(tracker.activeCategory.color)
                .frame(width: 0, height: 0)
                .opacity(0)

            PixelCurrentActivityIcon()
                .frame(width: 62, height: 48)

            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(tracker.activeApp.isEmpty ? "No active app" : tracker.activeApp)
                    .font(TypeScale.h2)
                    .lineLimit(1)
                Text(currentContextSubtitle)
                    .font(TypeScale.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !tracker.isTracking {
                PrimaryButton("Start Tracking", icon: "play.fill", color: appState.accentColor) {
                    tracker.start()
                }
            }

            Text(tracker.activeCategory.label.uppercased())
                .font(TypeScale.caption)
                .fontWeight(.semibold)
                .foregroundStyle(tracker.activeCategory.color)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xxs)
                .background(
                    Rectangle()
                        .fill(tracker.activeCategory.color.opacity(0.10))
                        .overlay(Rectangle().strokeBorder(tracker.activeCategory.color.opacity(0.28), lineWidth: 1))
                )
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 13)
        .frame(minHeight: 75)
        .panelSurface()
    }

    private var efficiencyPanel: some View {
        HStack(spacing: 0) {
            EfficiencyGauge(score: efficiencyScore, accent: appState.accentColor)
                .frame(width: 220)

            VStack(alignment: .leading, spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(scoreHeadline)
                        .font(TypeScale.h2)
                    Text(scoreComparison)
                        .font(TypeScale.bodyMd)
                        .foregroundStyle(baselineDelta == nil ? .secondary : comparisonColor)
                }

                Divider()

                HStack(spacing: 54) {
                    signal(icon: "clock", value: formatDurationWords(longestProductiveStreak), label: "Longest focus")
                    signal(icon: "arrow.triangle.2.circlepath", value: "\(contextSwitches)", label: "Context switches")
                    signal(icon: "scope", value: formatDurationWords(todayDistraction), label: "Distracted")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            CardDesertScene()
                .frame(width: 265)
        }
        .frame(minHeight: 152)
        .panelSurface()
    }

    private var metricStrip: some View {
        HStack(spacing: 0) {
            MetricCell(icon: "timer", label: "ACTIVE TIME", value: formatDurationWords(todayTotal), detail: "Today", color: appState.accentColor)
            metricDivider
            MetricCell(icon: "target", label: "FOCUS TIME", value: formatDurationWords(todayProductive), detail: percent(todayProductive, of: todayTotal), color: .productive)
            metricDivider
            MetricCell(icon: "arrow.triangle.2.circlepath", label: "CONTEXT SWITCHES", value: "\(contextSwitches)", detail: switchesPerHourLabel, color: .streak)
        }
        .panelSurface()
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(width: 0.5, height: 52)
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

            if visibleEvents.isEmpty {
                HStack(spacing: 4) {
                    ForEach(0..<54, id: \.self) { index in
                        Rectangle()
                            .fill(index.isMultiple(of: 7) ? Color.productive.opacity(0.36) : Color.driftMuted.opacity(0.16))
                            .frame(height: 28)
                    }
                }
            } else {
                GeometryReader { geometry in
                    HStack(spacing: 3) {
                        ForEach(visibleEvents.suffix(48)) { event in
                            Rectangle()
                                .fill(event.category.color)
                                .frame(
                                    width: max(
                                        5,
                                        geometry.size.width
                                            * CGFloat(event.durationMs / max(visibleEventTotalMs, 1))
                                    )
                                )
                                .help("\(event.owner) · \(formatDurationWords(event.durationMs)) · \(event.category.label)")
                        }
                    }
                }
                .frame(height: 54)
            }
        }
        .padding(Space.lg)
        .panelSurface()
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
        .panelSurface()
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
                    HStack(spacing: Space.sm) {
                        Rectangle()
                            .fill(app.category.color.opacity(0.14))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Text(String(app.name.prefix(1)).uppercased())
                                    .font(TypeScale.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(app.category.color)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(TypeScale.bodySm)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(app.category.label)
                                .font(TypeScale.tiny)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(formatDurationWords(app.durationMs))
                            .font(TypeScale.monoXs)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.sm)
                }
            }
        }
        .panelSurface()
    }

    private var emptyOverview: some View {
        VStack(spacing: Space.xl) {
            PixelDLogo(size: 84, background: appState.accentColor)

            VStack(spacing: Space.xs) {
                Text("START LIVE TRACKING")
                    .font(TypeScale.h2)
                Text("Apps, sites, page titles, and context will appear as soon as tracking starts.")
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            PrimaryButton("START TRACKING", icon: "play.fill", color: appState.accentColor) {
                tracker.start()
            }

            Text("Tracks apps, window titles, domains, and durations. Never keystrokes or screen contents.")
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .panelSurface()
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
        .padding(.vertical, Space.md)
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
        return tracker.isTracking ? "Waiting for active window detail" : "Start tracking to classify activity"
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
        tracker.isTracking || hasActivity || !todayEvents.isEmpty
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
        switch efficiencyScore {
        case 85...: return "A highly efficient day"
        case 70..<85: return "Strong, focused progress"
        case 50..<70: return "A mixed attention day"
        default: return "Attention was fragmented"
        }
    }

    private var scoreComparison: String {
        guard let delta = baselineDelta else {
            return "Complete \(max(0, 5 - appState.pastSessions.count)) more sessions to establish your baseline."
        }
        if delta == 0 { return "In line with your 30-session baseline." }
        return "\(delta > 0 ? "+" : "")\(delta) points versus your personal baseline."
    }

    private var comparisonColor: Color {
        (baselineDelta ?? 0) >= 0 ? .productive : .distraction
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
        .padding(.vertical, Space.lg)
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
            Text(isLive ? "LIVE" : Self.timeFormatter.string(from: event.timestamp))
                .font(TypeScale.monoXs)
                .foregroundStyle(isLive ? Color.productive : Color.driftMuted)
                .frame(width: 62, alignment: .leading)

            ZStack {
                Rectangle()
                    .fill(event.category.color.opacity(0.18))
                    .frame(width: 30, height: 30)
                    .overlay(Rectangle().strokeBorder(event.category.color.opacity(0.72), lineWidth: 1))
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

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatDurationWords(event.durationMs))
                    .font(TypeScale.monoXs)
                    .foregroundStyle(.secondary)
                Text(event.category.label.uppercased())
                    .font(TypeScale.tiny)
                    .foregroundStyle(event.category.color)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm)
        .background(isLive ? Color.productive.opacity(0.06) : Color.clear)
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
    func panelSurface() -> some View {
        background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.driftPanel)
                .shadow(color: Color.driftShadow, radius: 0, x: 4, y: 4)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.driftBorder, lineWidth: 1)
                }
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

struct DriftAmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let accent: Color
    let reduceMotion: Bool
    @State private var shifted = false

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let isDark = colorScheme == .dark
                let width = max(Int(size.width), 1)
                let skyHeight = isDark ? size.height * 0.74 : size.height * 0.84
                let motionOffset = shifted ? 9 : 0

                func block(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: Color) {
                    context.fill(
                        Path(CGRect(x: x.rounded(), y: y.rounded(), width: width.rounded(), height: height.rounded())),
                        with: .color(color)
                    )
                }

                func cloud(_ x: CGFloat, _ y: CGFloat, _ unit: CGFloat) {
                    let shadow = isDark ? Color(red: 0.25, green: 0.12, blue: 0.34) : Color(red: 0.86, green: 0.53, blue: 0.55)
                    let light = isDark ? Color(red: 0.38, green: 0.22, blue: 0.48) : Color(red: 1.0, green: 0.72, blue: 0.62)
                    block(x, y + unit * 3, unit * 10, unit * 2, shadow)
                    block(x + unit, y + unit * 2, unit * 3, unit * 2, shadow)
                    block(x + unit * 3, y + unit, unit * 4, unit * 3, light)
                    block(x + unit * 6, y + unit * 2, unit * 3, unit * 2, light)
                    block(x + unit * 8, y + unit * 3, unit * 3, unit, shadow)
                }

                func cactus(_ x: CGFloat, _ ground: CGFloat, _ unit: CGFloat) {
                    let dark = isDark ? Color(red: 0.055, green: 0.20, blue: 0.16) : Color(red: 0.12, green: 0.30, blue: 0.19)
                    let green = isDark ? Color(red: 0.26, green: 0.40, blue: 0.18) : Color(red: 0.31, green: 0.45, blue: 0.19)
                    let light = isDark ? Color(red: 0.55, green: 0.62, blue: 0.20) : Color(red: 0.58, green: 0.62, blue: 0.20)
                    block(x, ground - unit * 9, unit * 3, unit * 9, green)
                    block(x, ground - unit * 9, unit, unit * 9, dark)
                    block(x + unit * 2, ground - unit * 9, unit, unit * 9, light)
                    block(x - unit * 3, ground - unit * 6, unit * 3, unit * 2, green)
                    block(x - unit * 3, ground - unit * 8, unit * 2, unit * 4, green)
                    block(x + unit * 3, ground - unit * 5, unit * 3, unit * 2, dark)
                    block(x + unit * 5, ground - unit * 7, unit * 2, unit * 4, green)
                    block(x - unit, ground, unit * 5, unit, Color.driftShadow.opacity(0.55))
                }

                func mesa(_ centerX: CGFloat, _ baseY: CGFloat, _ unit: CGFloat, _ color: Color, _ highlight: Color) {
                    block(centerX - unit * 3, baseY - unit * 5, unit * 6, unit, highlight)
                    block(centerX - unit * 5, baseY - unit * 4, unit * 10, unit, color)
                    block(centerX - unit * 7, baseY - unit * 3, unit * 14, unit, color)
                    block(centerX - unit * 9, baseY - unit * 2, unit * 18, unit * 2, color)
                    block(centerX - unit * 4, baseY - unit * 4, unit, unit * 3, Color.driftShadow.opacity(0.28))
                    block(centerX, baseY - unit * 4, unit, unit * 2, Color.driftShadow.opacity(0.20))
                }

                let skyBands: [Color] = isDark
                    ? [
                        Color(red: 0.035, green: 0.016, blue: 0.09),
                        Color(red: 0.055, green: 0.024, blue: 0.13),
                        Color(red: 0.075, green: 0.032, blue: 0.17),
                        Color(red: 0.11, green: 0.045, blue: 0.21),
                        Color(red: 0.16, green: 0.065, blue: 0.24)
                    ]
                    : [
                        Color(red: 0.990, green: 0.982, blue: 0.960),
                        Color(red: 0.988, green: 0.974, blue: 0.948),
                        Color(red: 0.982, green: 0.958, blue: 0.925),
                        Color(red: 0.972, green: 0.938, blue: 0.898),
                        Color(red: 0.958, green: 0.910, blue: 0.860)
                    ]
                let bandHeight = skyHeight / CGFloat(skyBands.count)
                for (index, color) in skyBands.enumerated() {
                    block(0, CGFloat(index) * bandHeight, size.width, bandHeight + 1, color)
                }

                let starCount = isDark ? 96 : 26
                for index in 0..<starCount {
                    let x = CGFloat((index * 97 + motionOffset) % width)
                    let y = CGFloat((index * 53 + 17) % max(Int(skyHeight * 0.83), 1))
                    let side: CGFloat = index.isMultiple(of: 13) ? 3 : (index.isMultiple(of: 5) ? 2 : 1)
                    let color = index.isMultiple(of: 9)
                        ? Color.streak.opacity(isDark ? 0.86 : 0.38)
                        : (isDark ? Color.white.opacity(0.46) : Color.driftText.opacity(0.12))
                    block(x, y, side, side, color)
                    if index.isMultiple(of: 17) {
                        block(x - side, y, side * 3, side, color)
                        block(x, y - side, side, side * 3, color)
                    }
                }

                cloud(size.width * 0.10 + CGFloat(motionOffset), size.height * 0.14, 5)
                cloud(size.width * 0.58 - CGFloat(motionOffset), size.height * 0.22, 4)

                let celestialX = size.width * 0.82
                let celestialY = size.height * 0.09
                let moonLight = isDark ? Color(red: 1.0, green: 0.90, blue: 0.48) : Color(red: 1.0, green: 0.82, blue: 0.34)
                let moonShade = isDark ? Color(red: 0.82, green: 0.56, blue: 0.25) : Color(red: 0.98, green: 0.68, blue: 0.34)
                block(celestialX + 8, celestialY, 24, 4, moonLight)
                block(celestialX + 4, celestialY + 4, 32, 4, moonLight)
                block(celestialX, celestialY + 8, 40, 24, moonLight)
                block(celestialX + 4, celestialY + 32, 32, 4, moonLight)
                block(celestialX + 8, celestialY + 36, 24, 4, moonShade)
                block(celestialX + 28, celestialY + 12, 12, 20, moonShade)
                block(celestialX + 10, celestialY + 14, 6, 6, moonShade.opacity(0.72))
                block(celestialX + 20, celestialY + 24, 7, 7, moonShade.opacity(0.72))

                let mesaColor = isDark ? Color(red: 0.22, green: 0.08, blue: 0.20) : Color(red: 0.78, green: 0.58, blue: 0.68).opacity(0.32)
                let mesaLight = isDark ? Color(red: 0.38, green: 0.13, blue: 0.24) : Color(red: 0.95, green: 0.70, blue: 0.54).opacity(0.42)
                mesa(size.width * 0.17, skyHeight + 2, 7, mesaColor, mesaLight)
                mesa(size.width * 0.78, skyHeight + 6, 6, mesaColor, mesaLight)

                let farSand = isDark ? Color(red: 0.45, green: 0.20, blue: 0.20) : Color(red: 0.99, green: 0.78, blue: 0.58)
                let midSand = isDark ? Color(red: 0.58, green: 0.27, blue: 0.20) : Color(red: 1.00, green: 0.70, blue: 0.48)
                let nearSand = isDark ? Color(red: 0.66, green: 0.32, blue: 0.20) : Color(red: 1.00, green: 0.62, blue: 0.38)
                block(0, skyHeight, size.width, size.height - skyHeight, farSand)
                block(0, skyHeight + size.height * 0.07, size.width, size.height, midSand)
                block(0, skyHeight + size.height * 0.16, size.width, size.height, nearSand)

                for index in 0..<14 {
                    let x = CGFloat((index * 137 + 31) % width)
                    let y = skyHeight + CGFloat((index * 29) % max(Int(size.height - skyHeight), 1))
                    let run = CGFloat(10 + (index * 7) % 34)
                    block(x, y, run, 3, index.isMultiple(of: 2) ? mesaLight.opacity(0.46) : Color.driftShadow.opacity(0.20))
                }

                cactus(size.width * 0.08, size.height - 10, max(3, min(7, size.width / 150)))
                cactus(size.width * 0.88, size.height - 12, max(3, min(6, size.width / 180)))
                cactus(size.width * 0.58, size.height - 8, max(2, min(4, size.width / 260)))

                for index in 0..<9 {
                    let x = CGFloat((index * 173 + motionOffset * 2) % width)
                    let y = size.height * 0.64 + CGFloat((index * 37) % max(Int(size.height * 0.20), 1))
                    block(x, y, 3, 3, Color.streak.opacity(isDark ? 0.28 : 0.20))
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                    shifted = true
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
