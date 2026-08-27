import SwiftUI
import AppKit

struct TrackingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var tracker: WindowTracker
    @State private var appeared = false
    @State private var showScoreInfo = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                todayHorizon
                currentActivity
                summaryStrip

                if hasVisibleActivity {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: Space.lg) {
                            recentActivity
                                .frame(maxWidth: .infinity)
                            applicationSummary
                                .frame(width: 420)
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
            .frame(maxWidth: 1180, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 44)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || appState.reduceMotion ? 0 : 6)
        }
        .onAppear {
            withAnimation(appState.reduceMotion ? nil : Anim.appear) { appeared = true }
        }
    }

    private var todayHorizon: some View {
        HStack(alignment: .center, spacing: 28) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Today · \(Self.dayFormatter.string(from: Date()))")
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.desertMutedText)
                Text(scoreHeadline)
                    .font(TypeScale.h1)
                    .foregroundStyle(Color.desertCreamText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .layoutPriority(1)
                Text(todaySummary)
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(Color.desertCreamText.opacity(0.78))
            }

            Spacer()

            HStack(spacing: 10) {
                Text("\(efficiencyScore)")
                    .font(TypeScale.monoMd)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("Focus quality")
                    .font(TypeScale.bodySm)
                    .foregroundStyle(Color.creamMuted)

                Button {
                    showScoreInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("How Drift calculates focus quality")
                .accessibilityLabel("How Drift calculates focus quality")
                .popover(isPresented: $showScoreInfo, arrowEdge: .bottom) {
                    TactilePanel(padding: 18, density: .popover) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How focus quality works")
                                .font(TypeScale.heading)
                            Text("Focused share raises it. Distraction time and frequent context switches lower confidence in the result.")
                                .font(TypeScale.caption)
                                .foregroundStyle(Color.driftMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: 280, alignment: .leading)
                    }
                    .preferredColorScheme(.dark)
                }
            }
            .foregroundStyle(Color.cream)
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(height: 44)
            .driftFunctionalGlass(
                cornerRadius: Radius.pill,
                dimmingOpacity: 0.50
            )
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 132)
    }

    private var currentActivity: some View {
        HStack(spacing: 16) {
            ApplicationIcon(name: tracker.isTracking ? tracker.activeApp : "Drift", size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text("CURRENT ACTIVITY")
                    .sectionLabel()
                Text(tracker.isTracking ? (tracker.activeApp.isEmpty ? "Reading active app…" : tracker.activeApp) : "Tracking is off")
                    .font(TypeScale.heading)
                    .lineLimit(1)
                Text(tracker.isTracking ? currentContextSubtitle : "Start tracking to classify your activity")
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.driftMuted)
                    .lineLimit(1)
            }

            Spacer()

            if tracker.isTracking {
                Text(formatDurationWords(liveEvent?.durationMs ?? 0))
                    .font(TypeScale.monoSm)
                    .foregroundStyle(Color.driftMuted)
                    .monospacedDigit()

                Menu {
                    ForEach(AppCategory.allCases, id: \.rawValue) { category in
                        Button {
                            guard !tracker.activeApp.isEmpty else { return }
                            appState.setClassificationOverride(category, for: "app:\(tracker.activeApp.lowercased())")
                        } label: {
                            Label(category.label, systemImage: categoryIcon(category))
                        }
                    }
                } label: {
                    ClassificationBadge(category: displayedActiveCategory)
                }
                .menuStyle(.borderlessButton)
                .help("Change classification")
                .accessibilityLabel("Change classification for \(tracker.activeApp)")

                SecondaryPillButton(title: "Stop tracking", icon: "stop.fill") {
                    tracker.stop()
                }
            } else {
                PrimaryPillButton(title: "Start tracking", icon: "play.fill") {
                    tracker.start()
                }
            }
        }
        .padding(.horizontal, 22)
        .frame(minHeight: 88)
        .driftContentSurface(cornerRadius: DriftSurfaceRadius.major)
    }

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            summaryCell(label: "FOCUSED", value: formatDurationWords(todayProductive), color: .productive)
            summaryDivider
            summaryCell(label: "DISTRACTED", value: formatDurationWords(todayDistraction), color: .distraction)
            summaryDivider
            summaryCell(label: "SWITCHES", value: "\(contextSwitches)", color: .streak)
            summaryDivider
            summaryCell(label: "LONGEST RUN", value: formatDurationWords(longestProductiveStreak), color: .productive)
        }
        .frame(height: 86)
        .driftContentSurface(cornerRadius: DriftSurfaceRadius.major)
    }

    private var summaryDivider: some View {
        Rectangle().fill(Color.border).frame(width: 1).padding(.vertical, 18)
    }

    private func summaryCell(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).sectionLabel()
            Text(value)
                .font(TypeScale.monoMd)
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var metricRail: some View {
        VStack(spacing: 0) {
            DashboardMetricCell(icon: "timer", label: "ACTIVE TIME", value: formatDurationWords(todayTotal), detail: "Today", color: appState.accentColor)
            metricDivider
            DashboardMetricCell(icon: "target", label: "FOCUS TIME", value: formatDurationWords(todayProductive), detail: percent(todayProductive, of: todayTotal), color: .productive)
            metricDivider
            DashboardMetricCell(icon: "arrow.triangle.2.circlepath", label: "CONTEXT SWITCHES", value: "\(contextSwitches)", detail: switchesPerHourLabel, color: .streak)
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
                    .fill(Color.black.opacity(0.10))
                    .overlay {
                        Rectangle().strokeBorder(Color.border.opacity(0.42), lineWidth: 1)
                    }
            }
        }
        .padding(Space.lg)
        .frame(height: 150)
        .glassSurface(density: .data)
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
        .glassSurface(density: .data)
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
                    ApplicationStatRow(
                        app: app,
                        maxDuration: appStats.first?.durationMs ?? 1
                    )
                    if app.id != appStats.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .glassSurface(density: .data)
    }

    private var emptyOverview: some View {
        EmptyState(
            icon: "point.3.connected.trianglepath.dotted",
            message: tracker.isTracking
                ? "Drift is reading the frontmost app. Your first activity row will appear here shortly."
                : "Your activity timeline will appear here after tracking begins. Drift never records keystrokes or screen contents."
        )
        .driftContentSurface(cornerRadius: DriftSurfaceRadius.major)
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
        .padding(.horizontal, Space.xl)
        .frame(height: 54)
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
        "WHERE DID YOUR TIME GO?"
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
    private var mergedVisibleEvents: [AppEvent] {
        var merged: [AppEvent] = []
        for event in visibleEvents {
            guard let previous = merged.last,
                  previous.owner == event.owner,
                  previous.title == event.title,
                  previous.category == event.category else {
                merged.append(event)
                continue
            }

            merged.removeLast()
            merged.append(
                AppEvent(
                    id: event.id == Self.liveEventID ? event.id : previous.id,
                    owner: previous.owner,
                    title: previous.title,
                    isBrowser: previous.isBrowser,
                    url: previous.url,
                    category: previous.category,
                    timestamp: previous.timestamp,
                    durationMs: previous.durationMs + event.durationMs
                )
            )
        }
        return merged
    }
    private var recentEvents: [AppEvent] {
        Array(mergedVisibleEvents.suffix(5).reversed())
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
        guard todayTotal >= 5 * 60_000 else { return "Not enough activity yet" }
        let switchesPerHour = Double(contextSwitches) / max(todayTotal / 3_600_000, 0.25)
        if todayDistraction / max(todayTotal, 1) > 0.28 { return "Frequent distractions" }
        if switchesPerHour > 18 { return "Productive, but fragmented" }
        if efficiencyScore >= 82 && longestProductiveStreak >= 20 * 60_000 { return "Deep, uninterrupted focus" }
        if todayProductive / max(todayTotal, 1) < 0.42 { return "Mostly neutral activity" }
        return "Focused, with a few detours"
    }

    private var todaySummary: String {
        "\(formatDurationWords(todayProductive)) focused out of \(formatDurationWords(todayTotal)) tracked"
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

    private var focusScoreBlocks: Int {
        max(1, Int((Double(efficiencyScore) / 100.0 * 14.0).rounded()))
    }

    private var scoreShortLabel: String {
        switch efficiencyScore {
        case 75...: return "Strong focus"
        case 55..<75: return "Steady focus"
        case 35..<55: return "Building focus"
        default: return "Needs focus"
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
        return "Ready"
    }

    private var trackerColor: Color {
        if tracker.isPaused { return .streak }
        if tracker.isTracking { return .productive }
        return Color(.tertiaryLabelColor)
    }

    private var displayedActiveCategory: AppCategory {
        guard !tracker.activeApp.isEmpty else { return tracker.activeCategory }
        return appState.classificationOverride(for: "app:\(tracker.activeApp.lowercased())")
            ?? tracker.activeCategory
    }

    private func categoryIcon(_ category: AppCategory) -> String {
        switch category {
        case .productive: return "checkmark.circle.fill"
        case .neutral: return "minus.circle.fill"
        case .distraction: return "exclamationmark.triangle.fill"
        }
    }

    private struct AppStat: Identifiable {
        let id: String
        let name: String
        let durationMs: TimeInterval
        let category: AppCategory
    }

    private struct ApplicationStatRow: View {
        let app: AppStat
        let maxDuration: TimeInterval

        var body: some View {
            HStack(spacing: Space.lg) {
                ApplicationIcon(name: app.name, size: 42)

                VStack(alignment: .leading, spacing: 5) {
                    Text(app.name)
                        .font(TypeScale.bodyMd)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.driftText)
                        .lineLimit(1)
                    Label(app.category.label, systemImage: categoryIcon)
                        .font(TypeScale.caption)
                        .foregroundStyle(app.category.color)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 7) {
                    Text(formatDurationWords(app.durationMs))
                        .font(TypeScale.monoSm)
                        .foregroundStyle(Color.driftText.opacity(0.82))
                    Rectangle()
                        .fill(Color.cream.opacity(0.10))
                        .frame(width: 82, height: 5)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(app.category.color.opacity(0.78))
                                .frame(width: 82 * CGFloat(max(0.05, min(1, app.durationMs / max(maxDuration, 1)))))
                        }
                }
            }
            .padding(.horizontal, Space.xl)
            .frame(height: 78)
        }

        private var categoryIcon: String {
            switch app.category {
            case .productive: return "checkmark.circle.fill"
            case .neutral: return "minus.circle.fill"
            case .distraction: return "exclamationmark.triangle.fill"
            }
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

struct ApplicationIcon: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Group {
            if let applicationURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: applicationURL.path))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(4)
            } else {
                ZStack {
                    Color.accent.opacity(0.10)
                    Text(String(name.prefix(1)).uppercased().isEmpty ? "D" : String(name.prefix(1)).uppercased())
                        .font(TypeScale.heading)
                        .foregroundStyle(Color.accent)
                }
            }
        }
        .frame(width: size, height: size)
        .background(Color.driftPanelRaised.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.border, lineWidth: 1))
    }

    private var applicationURL: URL? {
        if let runningURL = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.localizedCaseInsensitiveCompare(name) == .orderedSame
        })?.bundleURL {
            return runningURL
        }

        let fileManager = FileManager.default
        let candidates = [
            URL(fileURLWithPath: "/Applications").appendingPathComponent("\(name).app"),
            URL(fileURLWithPath: "/System/Applications").appendingPathComponent("\(name).app"),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications")
                .appendingPathComponent("\(name).app")
        ]
        return candidates.first { fileManager.fileExists(atPath: $0.path) }
    }
}

private struct PixelHeaderIcon: View {
    let color: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.black.opacity(0.14))
                .overlay(Rectangle().strokeBorder(Color.driftBorder, lineWidth: 2))

            HStack(alignment: .bottom, spacing: 3) {
                Rectangle().fill(color).frame(width: 5, height: 12)
                Rectangle().fill(color.opacity(0.62)).frame(width: 5, height: 25)
                Rectangle().fill(color).frame(width: 5, height: 18)
                Rectangle().fill(Color.productive).frame(width: 5, height: 31)
            }
            .padding(7)
        }
    }
}

private struct DashboardMetricCell: View {
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

private struct FocusStatTile: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 70, height: 70)
                Image(systemName: icon)
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(spacing: 8) {
                Text(value)
                    .font(TypeScale.monoMd)
                    .monospacedDigit()
                    .foregroundStyle(Color.driftText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(label)
                    .font(TypeScale.bodySm)
                    .foregroundStyle(Color.driftMuted)
            }
        }
        .frame(width: 210, height: 204)
        .background {
            Rectangle()
                .fill(Color.black.opacity(0.18))
                .overlay(Rectangle().strokeBorder(Color.driftBorder, lineWidth: 2))
                .shadow(color: Color.black.opacity(0.42), radius: 0, x: 5, y: 5)
        }
    }
}

private struct HeroMetricTile: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(TypeScale.label)
                .tracking(0)
                .foregroundStyle(Color.driftMuted)
            Text(value)
                .font(TypeScale.monoMd)
                .monospacedDigit()
                .foregroundStyle(Color.driftText)
            Rectangle()
                .fill(color.opacity(0.78))
                .frame(height: 5)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .frame(width: 154, alignment: .leading)
        .background {
            Rectangle()
                .fill(Color.black.opacity(0.16))
                .overlay(Rectangle().strokeBorder(Color.driftBorder, lineWidth: 2))
        }
    }
}

private struct TrackingToggleButton: View {
    let isTracking: Bool
    let isPaused: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var label: String {
        if isTracking { return "Stop tracking" }
        return "Start tracking"
    }

    private var icon: String {
        if isTracking { return "stop.fill" }
        return "play.fill"
    }

    private var fill: Color {
        if isTracking { return Color.distraction }
        return Color.productive
    }

    private var caption: String {
        if isTracking { return isPaused ? "Paused" : "Recording activity" }
        return "Ready when you are"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(label)
                        .font(TypeScale.heading)
                        .lineLimit(1)
                    Text(caption)
                        .font(TypeScale.caption)
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .frame(width: 286, height: 76)
            .background {
                Rectangle()
                    .fill(fill.opacity(isHovered ? 0.88 : 0.94))
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .overlay {
                        Rectangle().strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(isHovered ? 0.48 : 0.38), radius: 0, x: isHovered ? 6 : 5, y: isHovered ? 6 : 5)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(label)
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
            Rectangle()
                .fill(Color.black.opacity(0.14))
                .overlay(Rectangle().strokeBorder(Color.driftBorder, lineWidth: 2))
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
            Rectangle().fill(Color.accent.opacity(0.74)).frame(width: 28, height: 5)
            Rectangle().fill(Color.productive.opacity(0.86)).frame(width: 6, height: 30).offset(y: -4)
            Rectangle().fill(Color.productive.opacity(0.58)).frame(width: 12, height: 5).offset(x: -8, y: -18)
            Rectangle().fill(Color.productive.opacity(0.72)).frame(width: 12, height: 5).offset(x: 9, y: -23)
            Rectangle().fill(Color.streak.opacity(0.70)).frame(width: 4, height: 4).offset(x: 17, y: -8)
        }
    }
}

private struct EmptyDesertMarker: View {
    let accent: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.14))
                .overlay(Rectangle().strokeBorder(Color.driftBorder, lineWidth: 2))

            VStack(spacing: 8) {
                PixelCurrentActivityIcon()
                    .frame(width: 64, height: 54)
                HStack(spacing: 4) {
                    ForEach(0..<6, id: \.self) { index in
                        Rectangle()
                            .fill(index.isMultiple(of: 2) ? accent.opacity(0.75) : Color.streak.opacity(0.62))
                            .frame(width: 7, height: 5)
                    }
                }
            }
            .padding(.bottom, 18)
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
                        .font(TypeScale.monoLg)
                        .monospacedDigit()
                        .foregroundStyle(Color.streak)
                    Text("EFFICIENCY")
                        .font(TypeScale.tiny)
                        .tracking(0)
                        .foregroundStyle(Color.driftMuted)
                }
            }
            .frame(width: 116, height: 116)

            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { index in
                    Rectangle()
                        .fill(index * 10 < score ? qualityFill(for: index) : Color.driftMuted.opacity(0.16))
                        .frame(width: 8, height: 6)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.border.opacity(0.5)).frame(width: 1)
        }
    }

    private func qualityFill(for index: Int) -> Color {
        index < 4 ? Color.distraction.opacity(0.88) : Color.productive.opacity(0.82)
    }
}

private struct ActivityRow: View {
    let event: AppEvent
    var isLive: Bool = false
    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false
    @State private var showDetails = false

    var body: some View {
        HStack(spacing: Space.lg) {
            Text(isLive ? "LIVE" : timeRange)
                .font(TypeScale.monoSm)
                .foregroundStyle(isLive ? Color.productive : Color.driftMuted)
                .frame(width: 132, alignment: .leading)

            ApplicationIcon(name: event.owner, size: 38)

            VStack(alignment: .leading, spacing: 5) {
                Text(rowTitle)
                    .font(TypeScale.bodyMd)
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
                .font(TypeScale.monoSm)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            ClassificationBadge(category: displayedCategory)

            Menu {
                Menu("Change classification") {
                    ForEach(AppCategory.allCases, id: \.rawValue) { category in
                        Button {
                            appState.setClassificationOverride(category, for: classificationKey)
                        } label: {
                            Text(category.label)
                        }
                    }
                }
                Button("View details") {
                    showDetails = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.creamMuted)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(isHovered ? Color.cream.opacity(0.07) : Color.clear)
                    )
            }
            .menuStyle(.borderlessButton)
            .opacity(isHovered ? 1 : 0.35)
            .help("Activity actions")
            .accessibilityLabel("Actions for \(rowTitle)")
            .popover(isPresented: $showDetails, arrowEdge: .trailing) {
                TactilePanel(padding: 18, density: .popover) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(rowTitle).font(TypeScale.heading)
                        Text(rowSubtitle).font(TypeScale.caption).foregroundStyle(Color.driftMuted)
                        Text("\(timeRange) · \(formatDurationWords(event.durationMs))")
                            .font(TypeScale.monoXs)
                            .foregroundStyle(Color.driftMuted)
                        ClassificationBadge(category: displayedCategory)
                    }
                    .frame(width: 300, alignment: .leading)
                }
                .preferredColorScheme(.dark)
            }
        }
        .padding(.horizontal, Space.xl)
        .frame(height: 72)
        .background(isLive ? Color.productive.opacity(0.075) : (isHovered ? Color.cream.opacity(0.055) : Color.clear))
        .onHover { isHovered = $0 }
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

    private var displayedCategory: AppCategory {
        appState.classificationOverride(for: classificationKey) ?? event.category
    }

    private var classificationKey: String {
        if let domain = domainName(from: event.url), !domain.isEmpty {
            return "domain:\(domain.lowercased())"
        }
        return "app:\(event.owner.lowercased())"
    }

    private var timeRange: String {
        let end = event.timestamp.addingTimeInterval(event.durationMs / 1000)
        return "\(Self.timeFormatter.string(from: event.timestamp))–\(Self.timeFormatter.string(from: end))"
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
    func glassSurface(density: DriftGlassDensity = .data) -> some View {
        driftContentSurface(
            dense: density == .data,
            cornerRadius: DriftSurfaceRadius.major
        )
    }

    func glassTag(color: Color) -> some View {
        font(TypeScale.tiny)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(Capsule().strokeBorder(color.opacity(0.30), lineWidth: 1))
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
                .fill(color.opacity(0.08))
                .overlay(Rectangle().strokeBorder(color.opacity(0.20), lineWidth: 1))
        )
        .onAppear {
            guard pulsing else { return }
            withAnimation(Anim.breathe) { pulseScale = 2.1 }
        }
    }
}

struct DriftAmbientBackground: View {
    let accent: Color
    let reduceMotion: Bool
    var showLizard: Bool = true

    var body: some View {
        DriftPixelBackdrop(imageOpacity: 1, washOpacity: 0.18, blurRadius: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
