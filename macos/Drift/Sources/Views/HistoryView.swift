import SwiftUI
import Charts

private enum AnalyticsRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "7 Days"
    case month = "30 Days"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        }
    }
}

private enum HistoryContent: String, CaseIterable, Identifiable {
    case sessions = "Sessions"
    case applications = "Applications"

    var id: String { rawValue }
}

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var range: AnalyticsRange = .week
    @State private var content: HistoryContent = .sessions
    @State private var appeared = false
    @State private var chartSelection: Date?
    @State private var selectedSession: PastSession?
    @State private var applicationSearch = ""
    @State private var categoryFilter: AppCategory?

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 138)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    if hasData {
                        kpiStrip
                        productivityTrend
                        contentPicker
                        if content == .sessions {
                            HStack(alignment: .top, spacing: Space.lg) {
                                sessionLedger
                                if let selectedSession {
                                    sessionInspector(selectedSession)
                                        .frame(width: 300)
                                }
                            }
                            .transition(.opacity)
                        } else {
                            applicationLedger
                        }
                    } else {
                        emptyAnalytics
                    }
                }
                .frame(maxWidth: 1180, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || appState.reduceMotion ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(appState.reduceMotion ? nil : Anim.appear) { appeared = true }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Space.xxl) {
            HStack(alignment: .center, spacing: Space.xxl) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("History")
                        .font(TypeScale.h1)
                        .foregroundStyle(Color.desertCreamText)
                    Text("A quieter record of where your attention went.")
                        .font(TypeScale.bodyMd)
                        .foregroundStyle(Color.desertMutedText)
                }
                .shadow(color: Color.black.opacity(0.75), radius: 4, y: 2)

                Spacer()

                SegmentedControl(
                    options: AnalyticsRange.allCases,
                    selection: $range,
                    title: { $0.rawValue }
                )
            }
            .frame(maxWidth: 1180)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsRange.allCases) { item in
                Button {
                    withAnimation(Anim.quick) { range = item }
                } label: {
                    Text(item.rawValue)
                        .font(TypeScale.caption)
                        .fontWeight(range == item ? .semibold : .regular)
                        .foregroundStyle(range == item ? .primary : .secondary)
                        .padding(.horizontal, Space.lg)
                        .padding(.vertical, Space.sm)
                        .frame(maxWidth: .infinity)
                        .background {
                            if range == item {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(Color.driftPanel)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                            .strokeBorder(Color.border, lineWidth: 0.5)
                                    }
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.primary.opacity(0.04))
        }
    }

    private var kpiStrip: some View {
        HStack(spacing: 0) {
            MetricCell(
                label: "FOCUSED TIME",
                value: formatDurationWords(totalProductive),
                comparison: showsComparisons
                    ? durationComparison(current: totalProductive, previous: previousProductive)
                    : nil,
                color: .productive
            )
            kpiDivider
            MetricCell(
                label: "DISTRACTION",
                value: formatDurationWords(totalDistraction),
                comparison: showsComparisons
                    ? durationComparison(current: totalDistraction, previous: previousDistraction, lowerIsBetter: true)
                    : nil,
                color: .distraction
            )
            kpiDivider
            MetricCell(
                label: "SWITCHES / HOUR",
                value: switchesPerHour,
                comparison: nil,
                color: .sand
            )
            kpiDivider
            MetricCell(
                label: "LONGEST RUN",
                value: formatDurationWords(longestFocusedRun),
                comparison: nil,
                color: .focusBlue
            )
        }
        .padding(18)
        .driftContentSurface(cornerRadius: DriftSurfaceRadius.major)
    }

    private var kpiDivider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(width: 1, height: 58)
            .padding(.horizontal, 18)
    }

    private var productivityTrend: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            chartHeader(
                title: "DAILY ATTENTION",
                detail: recordedDayCount > 1 ? "\(recordedDayCount) recorded days" : "First recorded day"
            )

            Chart {
                ForEach(dailyPoints) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Minutes", point.productiveMinutes)
                    )
                    .foregroundStyle(by: .value("Category", "Productive"))

                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Minutes", point.neutralMinutes)
                    )
                    .foregroundStyle(by: .value("Category", "Neutral"))

                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Minutes", point.distractionMinutes)
                    )
                    .foregroundStyle(by: .value("Category", "Distraction"))

                    if point.totalMs == 0 {
                        PointMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Minutes", 0)
                        )
                        .symbolSize(22)
                        .foregroundStyle(Color.cream.opacity(0.20))
                    }
                }

                if let selectedDailyPoint {
                    RuleMark(x: .value("Selected day", selectedDailyPoint.date, unit: .day))
                        .foregroundStyle(Color.cream.opacity(0.30))
                        .annotation(position: .top, alignment: .leading) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Self.sessionDateFormatter.string(from: selectedDailyPoint.date))
                                    .font(TypeScale.heading)
                                if selectedDailyPoint.totalMs == 0 {
                                    Text("No data")
                                        .foregroundStyle(Color.creamMuted)
                                } else {
                                    Text("Productive \(selectedDailyPoint.productiveMinutes)m")
                                        .foregroundStyle(Color.productive)
                                    Text("Neutral \(selectedDailyPoint.neutralMinutes)m")
                                        .foregroundStyle(Color.neutral)
                                    Text("Distraction \(selectedDailyPoint.distractionMinutes)m")
                                        .foregroundStyle(Color.distraction)
                                }
                            }
                            .font(TypeScale.caption)
                            .padding(10)
                            .driftGlass(.popover, cornerRadius: Radius.md)
                        }
                }
            }
            .chartForegroundStyleScale([
                "Productive": Color.productive,
                "Neutral": Color.neutral,
                "Distraction": Color.distraction
            ])
            .chartLegend(position: .top, alignment: .leading, spacing: 16)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.border)
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text("\(minutes)m")
                                .font(TypeScale.tiny)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(dailyPoints.count, 7))) {
                    AxisGridLine().foregroundStyle(.clear)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(TypeScale.tiny)
                        .foregroundStyle(.tertiary)
                }
            }
            .chartXSelection(value: $chartSelection)
            .frame(height: 220)
            .animation(
                appState.reduceMotion ? nil : .easeOut(duration: 0.26),
                value: range
            )
        }
        .padding(Space.xl)
        .driftContentSurface(dense: true, cornerRadius: DriftSurfaceRadius.major)
    }

    private var contentPicker: some View {
        SegmentedControl(
            options: HistoryContent.allCases,
            selection: $content,
            title: { $0.rawValue }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sessionLedger: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RECENT SESSIONS")
                    .sectionLabel()
                Spacer()
                Text("\(periodSessions.count) in range")
                    .font(TypeScale.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(Space.lg)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.border).frame(height: 0.5)
            }

            ForEach(Array(periodSessions.prefix(10))) { session in
                Button {
                    selectedSession = session
                } label: {
                    HStack(spacing: Space.lg) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.sessionDateFormatter.string(from: session.date))
                                .font(TypeScale.bodySm)
                                .fontWeight(.semibold)
                            Text(sessionTimeRange(session))
                                .font(TypeScale.tiny)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(width: 150, alignment: .leading)

                        ledgerValue(label: "DURATION", value: formatDurationWords(session.totalMs))
                        ledgerValue(label: "FOCUSED", value: "\(session.focusPercent)%")
                        ledgerValue(label: "SWITCHES", value: "\(sessionSwitches(session))")

                        VStack(alignment: .leading, spacing: 2) {
                            Text("TOP APPLICATIONS").sectionLabel()
                            Text(sessionTopApplications(session))
                                .font(TypeScale.caption)
                                .foregroundStyle(Color.driftMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.driftMuted)
                    }
                    .padding(.horizontal, Space.lg)
                    .frame(minHeight: 56)
                    .background(
                        selectedSession?.id == session.id
                            ? Color.cream.opacity(0.07)
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Session \(Self.sessionDateFormatter.string(from: session.date)), \(session.focusPercent) percent focused")

                if session.id != periodSessions.prefix(10).last?.id {
                    Divider()
                }
            }
        }
        .analyticsSurface()
    }

    private func sessionInspector(_ session: PastSession) -> some View {
        ContentSurfacePanel(padding: 20, dense: true, cornerRadius: DriftSurfaceRadius.compact) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Session details")
                            .font(TypeScale.heading)
                        Text(Self.sessionDateFormatter.string(from: session.date))
                            .font(TypeScale.caption)
                            .foregroundStyle(Color.driftMuted)
                    }
                    Spacer()
                    IconButton(icon: "xmark", label: "Close session details") {
                        selectedSession = nil
                    }
                }

                MetricCell(
                    label: "Focused",
                    value: "\(session.focusPercent)%",
                    comparison: formatDurationWords(session.productiveMs),
                    color: .productive
                )
                Divider()
                MetricCell(
                    label: "Switches",
                    value: "\(sessionSwitches(session))",
                    comparison: "Across \(session.appCount) applications",
                    color: .sand
                )
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOP APPLICATIONS").sectionLabel()
                    Text(sessionTopApplications(session))
                        .font(TypeScale.bodySm)
                        .foregroundStyle(Color.creamMuted)
                }
            }
        }
    }

    private var applicationLedger: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.md) {
                Text("APPLICATIONS").sectionLabel()
                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.driftMuted)
                    TextField("Search applications", text: $applicationSearch)
                        .textFieldStyle(.plain)
                        .font(TypeScale.bodySm)
                }
                .padding(.horizontal, 12)
                .frame(width: 230, height: 36)
                .driftInsetSurface()

                Menu {
                    Button("All categories") { categoryFilter = nil }
                    Divider()
                    ForEach(AppCategory.allCases, id: \.rawValue) { category in
                        Button(category.label) { categoryFilter = category }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(categoryFilter?.label ?? "All categories")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(TypeScale.bodySm)
                    .foregroundStyle(Color.cream)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .driftFunctionalGlass(cornerRadius: Radius.pill)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(Space.lg)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.border).frame(height: 0.5) }

            ForEach(filteredApplicationStats.prefix(12)) { app in
                HStack(spacing: Space.lg) {
                    ApplicationIcon(name: app.name, size: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name).font(TypeScale.bodySm).fontWeight(.semibold)
                        Text(formatDurationWords(app.durationMs))
                            .font(TypeScale.tiny)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    ledgerValue(label: "PRODUCTIVE", value: "\(app.productiveShare)%")
                    ledgerValue(label: "SWITCHES", value: "\(app.switchCount)")

                    TactileMenu(
                        selection: Binding(
                            get: {
                                appState.classificationOverride(for: "app:\(app.name.lowercased())")
                                    ?? app.category
                            },
                            set: {
                                appState.setClassificationOverride($0, for: "app:\(app.name.lowercased())")
                            }
                        ),
                        options: AppCategory.allCases.map {
                            TactileMenuOption(
                                title: $0.label,
                                icon: categoryIcon($0),
                                value: $0
                            )
                        }
                    )
                    .frame(width: 170)
                }
                .padding(.horizontal, Space.lg)
                .frame(height: 68)
                if app.id != filteredApplicationStats.prefix(12).last?.id {
                    Divider()
                }
            }
        }
        .analyticsSurface()
    }

    private var emptyAnalytics: some View {
        EmptyState(
            icon: "chart.bar.xaxis",
            message: "Complete a tracked session in this range and Drift will build your private history here."
        )
        .driftContentSurface(dense: true, cornerRadius: DriftSurfaceRadius.major)
    }

    private func chartHeader(title: String, detail: String) -> some View {
        HStack {
            Text(title).sectionLabel()
            Spacer()
            Text(detail)
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func ledgerValue(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).sectionLabel()
            Text(value).font(TypeScale.monoXs)
        }
        .frame(width: 90, alignment: .leading)
    }

    private var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -(range.days - 1), to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private var previousStartDate: Date {
        Calendar.current.date(byAdding: .day, value: -range.days, to: startDate) ?? startDate
    }

    private var periodSessions: [PastSession] {
        appState.pastSessions.filter { $0.date >= startDate }
    }

    private var previousSessions: [PastSession] {
        appState.pastSessions.filter { $0.date >= previousStartDate && $0.date < startDate }
    }

    private var includeCurrentSession: Bool {
        appState.session.totalMs >= 60_000 && (appState.session.startTime ?? Date()) >= startDate
    }

    private var hasData: Bool { !periodSessions.isEmpty || includeCurrentSession }
    private var totalActive: TimeInterval { periodSessions.reduce(includeCurrentSession ? appState.session.totalMs : 0) { $0 + $1.totalMs } }
    private var totalProductive: TimeInterval { periodSessions.reduce(includeCurrentSession ? appState.session.productiveMs : 0) { $0 + $1.productiveMs } }
    private var totalDistraction: TimeInterval { periodSessions.reduce(includeCurrentSession ? appState.session.distractionMs : 0) { $0 + $1.distractionMs } }
    private var previousProductive: TimeInterval { previousSessions.reduce(0) { $0 + $1.productiveMs } }
    private var previousDistraction: TimeInterval { previousSessions.reduce(0) { $0 + $1.distractionMs } }

    private var periodEvents: [AppEvent] {
        periodSessions.flatMap { $0.events ?? [] } + (includeCurrentSession ? appState.session.events : [])
    }

    private var periodSwitches: Int { max(periodEvents.count - 1, 0) }

    private var switchesPerHour: String {
        guard totalActive > 0 else { return "—" }
        let hours = totalActive / 3_600_000
        return String(format: "%.1f", Double(periodSwitches) / hours)
    }

    private var showsComparisons: Bool {
        recordedDayCount >= 2 && !previousSessions.isEmpty
    }

    private var recordedDayCount: Int {
        dailyPoints.filter { $0.totalMs > 0 }.count
    }

    private var selectedDailyPoint: DailyPoint? {
        guard let chartSelection else { return nil }
        return dailyPoints.min {
            abs($0.date.timeIntervalSince(chartSelection)) < abs($1.date.timeIntervalSince(chartSelection))
        }
    }

    private var longestFocusedRun: TimeInterval {
        var longest: TimeInterval = 0
        var current: TimeInterval = 0
        for event in periodEvents.sorted(by: { $0.timestamp < $1.timestamp }) {
            if event.category == .productive {
                current += event.durationMs
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private struct HistoryApp: Identifiable {
        let id: String
        let name: String
        let durationMs: TimeInterval
        let productiveMs: TimeInterval
        let switchCount: Int
        let category: AppCategory

        var productiveShare: Int {
            guard durationMs > 0 else { return 0 }
            return Int((productiveMs / durationMs * 100).rounded())
        }
    }

    private var applicationStats: [HistoryApp] {
        Dictionary(grouping: periodEvents, by: \.owner).map { name, events in
            let durations = Dictionary(grouping: events, by: \.category)
                .mapValues { $0.reduce(0) { $0 + $1.durationMs } }
            return HistoryApp(
                id: name,
                name: name,
                durationMs: events.reduce(0) { $0 + $1.durationMs },
                productiveMs: events.filter { $0.category == .productive }.reduce(0) { $0 + $1.durationMs },
                switchCount: max(events.count - 1, 0),
                category: durations.max(by: { $0.value < $1.value })?.key ?? .neutral
            )
        }
        .sorted { $0.durationMs > $1.durationMs }
    }

    private var filteredApplicationStats: [HistoryApp] {
        applicationStats.filter { app in
            let matchesSearch = applicationSearch.isEmpty
                || app.name.localizedCaseInsensitiveContains(applicationSearch)
            let displayedCategory = appState.classificationOverride(for: "app:\(app.name.lowercased())")
                ?? app.category
            let matchesCategory = categoryFilter == nil || displayedCategory == categoryFilter
            return matchesSearch && matchesCategory
        }
    }

    private func categoryIcon(_ category: AppCategory) -> String {
        switch category {
        case .productive: return "checkmark.circle.fill"
        case .neutral: return "minus.circle.fill"
        case .distraction: return "exclamationmark.triangle.fill"
        }
    }

    private func sessionSwitches(_ session: PastSession) -> Int {
        max((session.events ?? []).count - 1, 0)
    }

    private func sessionTopApplications(_ session: PastSession) -> String {
        let totals = Dictionary(grouping: session.events ?? [], by: \.owner)
            .mapValues { $0.reduce(0) { $0 + $1.durationMs } }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)
        return totals.isEmpty ? "No application detail" : totals.joined(separator: ", ")
    }

    private func sessionTimeRange(_ session: PastSession) -> String {
        let end = session.date.addingTimeInterval(session.totalMs / 1000)
        return "\(Self.sessionTimeFormatter.string(from: session.date))–\(Self.sessionTimeFormatter.string(from: end))"
    }

    private var averageEfficiency: Int {
        let scores = periodSessions.map(\.efficiencyScore) + (includeCurrentSession ? [appState.session.efficiencyScore] : [])
        guard !scores.isEmpty else { return 0 }
        return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }

    private var previousEfficiency: Double? {
        guard !previousSessions.isEmpty else { return nil }
        return Double(previousSessions.reduce(0) { $0 + $1.efficiencyScore }) / Double(previousSessions.count)
    }

    private var sessionComparison: String {
        guard !previousSessions.isEmpty else { return "Previous period unavailable" }
        let current = periodSessions.count + (includeCurrentSession ? 1 : 0)
        let delta = current - previousSessions.count
        if delta == 0 { return "No change" }
        return "\(delta > 0 ? "+" : "")\(delta) vs previous"
    }

    private func comparison(current: Double, previous: Double?, unit: String) -> String {
        guard let previous else { return "Previous period unavailable" }
        let delta = Int((current - previous).rounded())
        if delta == 0 { return "No change" }
        return "\(delta > 0 ? "+" : "")\(delta) \(unit) vs previous"
    }

    private func durationComparison(current: TimeInterval, previous: TimeInterval, lowerIsBetter: Bool = false) -> String {
        guard previous > 0 else { return "Previous period unavailable" }
        let change = Int(((current - previous) / previous * 100).rounded())
        if change == 0 { return "No change" }
        let favorable = lowerIsBetter ? change < 0 : change > 0
        return "\(change > 0 ? "+" : "")\(change)% · \(favorable ? "improved" : "declined")"
    }

    private struct DailyPoint: Identifiable {
        let id: Date
        let date: Date
        let productiveMs: TimeInterval
        let neutralMs: TimeInterval
        let distractionMs: TimeInterval

        var totalMs: TimeInterval { productiveMs + neutralMs + distractionMs }
        var focusMinutes: Int { Int((productiveMs / 60_000).rounded()) }
        var productiveMinutes: Int { Int((productiveMs / 60_000).rounded()) }
        var neutralMinutes: Int { Int((neutralMs / 60_000).rounded()) }
        var distractionMinutes: Int { Int((distractionMs / 60_000).rounded()) }
        var efficiency: Int {
            guard totalMs > 0 else { return 0 }
            return Int(((productiveMs / totalMs * 0.65 + (1 - distractionMs / totalMs) * 0.35) * 100).rounded())
        }
    }

    private var dailyPoints: [DailyPoint] {
        let calendar = Calendar.current
        var grouped = Dictionary(grouping: periodSessions) { calendar.startOfDay(for: $0.date) }

        if includeCurrentSession {
            let day = calendar.startOfDay(for: appState.session.startTime ?? Date())
            grouped[day, default: []].append(
                PastSession(
                    date: appState.session.startTime ?? Date(),
                    totalMs: appState.session.totalMs,
                    productiveMs: appState.session.productiveMs,
                    neutralMs: appState.session.neutralMs,
                    distractionMs: appState.session.distractionMs,
                    focusPercent: appState.session.focusPercent,
                    driftScore: appState.session.driftScore,
                    appCount: appState.session.uniqueApps
                )
            )
        }

        let rangeDates = (0..<range.days).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDate)
                .map(calendar.startOfDay(for:))
        }

        return rangeDates.map { date in
            let sessions = grouped[date, default: []]
            return DailyPoint(
                id: date,
                date: date,
                productiveMs: sessions.reduce(0) { $0 + $1.productiveMs },
                neutralMs: sessions.reduce(0) { $0 + $1.neutralMs },
                distractionMs: sessions.reduce(0) { $0 + $1.distractionMs }
            )
        }
    }

    private static let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    private static let sessionTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

}

private struct AnalyticsKPI: View {
    let label: String
    let value: String
    let comparison: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(label).sectionLabel()
            Text(value)
                .font(TypeScale.monoLg)
                .monospacedDigit()
            Text(comparison)
                .font(TypeScale.tiny)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(color)
                .frame(width: 32, height: 2)
                .padding(.leading, Space.lg)
        }
    }
}

private extension View {
    func analyticsSurface() -> some View {
        driftContentSurface(dense: true, cornerRadius: DriftSurfaceRadius.major)
    }
}
