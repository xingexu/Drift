import SwiftUI
import Charts

private enum IntelligenceScope: String, CaseIterable, Identifiable {
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

struct ApplicationsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var scope: IntelligenceScope = .week
    @State private var searchText = ""
    @State private var selectedAppID: String?
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.xxl) {
                header
                controls

                if appStats.isEmpty {
                    emptyApplications
                } else {
                    applicationTable

                    if let selectedApp {
                        applicationDetail(selectedApp)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(Space.page)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
        }
        .onAppear {
            withAnimation(Anim.appear) { appeared = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text("APPLICATIONS")
                .font(TypeScale.h1)
            Text("See where your recorded time goes.")
                .font(TypeScale.bodyMd)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: Space.md) {
            HStack(spacing: Space.xs) {
                Image(systemName: "magnifyingglass")
                    .font(TypeScale.bodySm)
                    .foregroundStyle(.tertiary)
                TextField("Search applications", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(TypeScale.bodyMd)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .frame(maxWidth: 340)
            .background {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color.driftPanel)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(Color.border, lineWidth: 0.5)
                    }
            }

            Spacer()

            HStack(spacing: 0) {
                ForEach(IntelligenceScope.allCases) { item in
                    Button {
                        withAnimation(Anim.quick) {
                            scope = item
                            selectedAppID = nil
                        }
                    } label: {
                        Text(item.rawValue)
                            .font(TypeScale.caption)
                            .fontWeight(scope == item ? .semibold : .regular)
                            .foregroundStyle(scope == item ? .primary : .secondary)
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, Space.xs)
                            .background {
                                if scope == item {
                                    RoundedRectangle(cornerRadius: Radius.sm)
                                        .fill(Color.driftPanel)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.primary.opacity(0.04)))
        }
    }

    private var applicationTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("APPLICATION").frame(maxWidth: .infinity, alignment: .leading)
                Text("TIME").frame(width: 110, alignment: .leading)
                Text("CLASSIFICATION").frame(width: 130, alignment: .leading)
            }
            .sectionLabel()
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .background(Color.primary.opacity(0.025))

            Divider()

            ForEach(appStats) { app in
                Button {
                    withAnimation(Anim.tap) {
                        selectedAppID = selectedAppID == app.id ? nil : app.id
                    }
                } label: {
                    HStack {
                        HStack(spacing: Space.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: Radius.sm)
                                    .fill(app.color.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                Text(String(app.name.prefix(1)).uppercased())
                                    .font(TypeScale.bodySm)
                                    .fontWeight(.bold)
                                    .foregroundStyle(app.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(TypeScale.bodyMd)
                                    .fontWeight(.semibold)
                                Text(app.contextSummary)
                                    .font(TypeScale.tiny)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(formatDurationWords(app.durationMs))
                            .font(TypeScale.monoXs)
                            .frame(width: 110, alignment: .leading)

                        Text(app.classification)
                            .font(TypeScale.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(app.color)
                            .frame(width: 130, alignment: .leading)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.md)
                    .background(selectedAppID == app.id ? app.color.opacity(0.045) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if app.id != appStats.last?.id {
                    Divider()
                }
            }
        }
        .intelligenceSurface()
    }

    private func applicationDetail(_ app: ApplicationStat) -> some View {
        HStack(alignment: .top, spacing: Space.xxl) {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(TypeScale.h2)
                        Text("Usage context")
                            .font(TypeScale.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(app.changeLabel)
                        .font(TypeScale.caption)
                        .foregroundStyle(app.changeColor)
                }

                Chart(app.categoryBreakdown) { point in
                    BarMark(
                        x: .value("Minutes", point.durationMs / 60_000),
                        y: .value("Category", point.category.label)
                    )
                    .foregroundStyle(point.category.color)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.border)
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text("\(Int(minutes))m")
                                    .font(TypeScale.tiny)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisGridLine().foregroundStyle(.clear)
                        AxisValueLabel().font(TypeScale.tiny)
                    }
                }
                .frame(height: 130)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: Space.md) {
                Text("RECENT PERIODS")
                    .sectionLabel()

                ForEach(app.events.sorted(by: { $0.timestamp > $1.timestamp }).prefix(5)) { event in
                    HStack(spacing: Space.sm) {
                        Rectangle()
                            .fill(event.category.color)
                            .frame(width: 3, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.eventFormatter.string(from: event.timestamp))
                                .font(TypeScale.caption)
                                .fontWeight(.semibold)
                            Text(event.title.isEmpty ? event.category.label : event.title)
                                .font(TypeScale.tiny)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(formatDurationWords(event.durationMs))
                            .font(TypeScale.monoXs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 340)
        }
        .padding(Space.xl)
        .intelligenceSurface()
    }

    private var emptyApplications: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No application detail in this range")
                .font(TypeScale.h2)
            Text("Newly completed sessions retain event-level application usage. Existing summary-only sessions remain untouched.")
                .font(TypeScale.bodyMd)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 470)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 90)
        .intelligenceSurface()
    }

    private var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -(scope.days - 1), to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private var events: [AppEvent] {
        let archived = appState.pastSessions
            .filter { $0.date >= startDate }
            .flatMap { $0.events ?? [] }
        return archived + appState.session.events
    }

    private var appStats: [ApplicationStat] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Dictionary(grouping: events, by: \.owner)
            .map { ApplicationStat(name: $0.key, events: $0.value) }
            .filter { query.isEmpty || $0.name.lowercased().contains(query) }
            .sorted { $0.durationMs > $1.durationMs }
    }

    private var selectedApp: ApplicationStat? {
        guard let selectedAppID else { return nil }
        return appStats.first { $0.id == selectedAppID }
    }

    private static let eventFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE · h:mm a"
        return formatter
    }()
}

private struct ApplicationStat: Identifiable {
    let name: String
    let events: [AppEvent]
    var id: String { name }
    var durationMs: TimeInterval { events.reduce(0) { $0 + $1.durationMs } }
    var productiveMs: TimeInterval { duration(for: .productive) }
    var neutralMs: TimeInterval { duration(for: .neutral) }
    var distractionMs: TimeInterval { duration(for: .distraction) }

    var efficiency: Int {
        guard durationMs > 0 else { return 0 }
        return Int((productiveMs / durationMs * 100).rounded())
    }

    var dominantCategory: AppCategory {
        categoryBreakdown.max(by: { $0.durationMs < $1.durationMs })?.category ?? .neutral
    }

    var classification: String {
        let significantCategories = categoryBreakdown.filter {
            durationMs > 0 && $0.durationMs / durationMs >= 0.20
        }
        return significantCategories.count > 1 ? "Mixed" : dominantCategory.label
    }

    var color: Color {
        classification == "Mixed" ? .streak : dominantCategory.color
    }

    var contextSummary: String {
        if classification == "Mixed" {
            return "Classification changes with context"
        }
        return "\(events.count) recorded periods"
    }

    var categoryBreakdown: [CategoryPoint] {
        AppCategory.allCasesForAnalytics.map {
            CategoryPoint(category: $0, durationMs: duration(for: $0))
        }
    }

    var changeLabel: String {
        let calendar = Calendar.current
        let now = Date()
        let currentStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let previousStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let current = events.filter { $0.timestamp >= currentStart }.reduce(0) { $0 + $1.durationMs }
        let previous = events.filter { $0.timestamp >= previousStart && $0.timestamp < currentStart }.reduce(0) { $0 + $1.durationMs }
        guard previous > 0 else { return "Previous week unavailable" }
        let change = Int(((current - previous) / previous * 100).rounded())
        return "\(change > 0 ? "+" : "")\(change)% vs previous week"
    }

    var changeColor: Color {
        changeLabel.hasPrefix("-") ? .productive : Color(.secondaryLabelColor)
    }

    func duration(for category: AppCategory) -> TimeInterval {
        events.filter { $0.category == category }.reduce(0) { $0 + $1.durationMs }
    }

    struct CategoryPoint: Identifiable {
        let category: AppCategory
        let durationMs: TimeInterval
        var id: String { category.rawValue }
    }
}

struct InsightsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.xxl) {
                header
                learningStatus

                if insights.isEmpty {
                    emptyInsights
                } else {
                    LazyVStack(spacing: Space.md) {
                        ForEach(insights) { insight in
                            InsightRow(insight: insight)
                        }
                    }
                }
            }
            .padding(Space.page)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
        }
        .onAppear {
            withAnimation(Anim.appear) { appeared = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text("INSIGHTS")
                .font(TypeScale.h1)
            Text("A short list of patterns from recorded activity.")
                .font(TypeScale.bodyMd)
                .foregroundStyle(.secondary)
        }
    }

    private var learningStatus: some View {
        HStack(spacing: Space.lg) {
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 6)
                Rectangle()
                    .fill(appState.accentColor)
                    .frame(width: 180 * learningProgress, height: 6)
            }
            .frame(width: 180)

            VStack(alignment: .leading, spacing: 2) {
                Text(baselineReady ? "Personal baseline active" : "Learning your baseline")
                    .font(TypeScale.bodySm)
                    .fontWeight(.semibold)
                Text(baselineReady ? "\(appState.pastSessions.count) sessions available" : "\(min(appState.pastSessions.count, 5)) of 5 sessions collected")
                    .font(TypeScale.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("\(insights.count) observations")
                .font(TypeScale.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Space.lg)
        .intelligenceSurface()
    }

    private var emptyInsights: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "lightbulb.max")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Drift is still learning")
                .font(TypeScale.h2)
            Text("Insights appear when a pattern has enough supporting activity. Keep tracking normally—Drift will not invent observations to fill this page.")
                .font(TypeScale.bodyMd)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 86)
        .intelligenceSurface()
    }

    private var baselineReady: Bool { appState.pastSessions.count >= 5 }
    private var learningProgress: CGFloat { min(CGFloat(appState.pastSessions.count) / 5, 1) }

    private var recentSessions: [PastSession] {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return appState.pastSessions.filter { $0.date >= start }
    }

    private var recentEvents: [AppEvent] {
        recentSessions.flatMap { $0.events ?? [] } + appState.session.events
    }

    private var insights: [DriftInsight] {
        var output: [DriftInsight] = []

        let productiveEvents = recentEvents.filter { $0.category == .productive }
        if productiveEvents.count >= 3 {
            let grouped = Dictionary(grouping: productiveEvents) {
                Calendar.current.component(.hour, from: $0.timestamp)
            }
            if let best = grouped.max(by: {
                $0.value.reduce(0) { $0 + $1.durationMs } < $1.value.reduce(0) { $0 + $1.durationMs }
            }) {
                let duration = best.value.reduce(0) { $0 + $1.durationMs }
                if duration >= 900_000 {
                    output.append(
                        DriftInsight(
                            title: "Your strongest focus period starts around \(Self.hourLabel(best.key)).",
                            detail: "\(formatDurationWords(duration)) of productive work was recorded in this hour across the last seven days.",
                            icon: "sun.max",
                            tone: .positive
                        )
                    )
                }
            }
        }

        let shortInterruptions = recentEvents.filter {
            $0.category == .distraction && $0.durationMs <= 300_000
        }
        let interruptionTime = shortInterruptions.reduce(0) { $0 + $1.durationMs }
        if shortInterruptions.count >= 3 && interruptionTime >= 300_000 {
            output.append(
                DriftInsight(
                    title: "Short interruptions cost \(formatDurationWords(interruptionTime)) this week.",
                    detail: "\(shortInterruptions.count) distracting periods lasted five minutes or less.",
                    icon: "arrow.triangle.branch",
                    tone: .warning
                )
            )
        }

        let longest = longestProductiveStreak(in: recentEvents)
        if longest >= 1_500_000 {
            output.append(
                DriftInsight(
                    title: "Your longest uninterrupted focus block was \(formatDurationWords(longest)).",
                    detail: "Drift counts consecutive productive periods until a neutral or distracting interruption occurs.",
                    icon: "timer",
                    tone: .positive
                )
            )
        }

        let totalMs = recentEvents.reduce(0) { $0 + $1.durationMs }
        if totalMs >= 3_600_000 {
            let switchesPerHour = Double(max(recentEvents.count - 1, 0)) / (totalMs / 3_600_000)
            if switchesPerHour >= 18 {
                output.append(
                    DriftInsight(
                        title: "Your attention changed apps \(String(format: "%.1f", switchesPerHour)) times per hour.",
                        detail: "Frequent switching reduces the continuity component of your efficiency score.",
                        icon: "arrow.left.arrow.right",
                        tone: .warning
                    )
                )
            }
        }

        if baselineReady {
            let weekday = Calendar.current.component(.weekday, from: Date())
            let comparable = appState.pastSessions.filter {
                Calendar.current.component(.weekday, from: $0.date) == weekday
            }
            if comparable.count >= 3 && appState.session.totalMs >= 600_000 {
                let average = Double(comparable.reduce(0) { $0 + $1.efficiencyScore }) / Double(comparable.count)
                let delta = appState.session.efficiencyScore - Int(average.rounded())
                if abs(delta) >= 5 {
                    output.append(
                        DriftInsight(
                            title: "Today is \(abs(delta)) efficiency points \(delta > 0 ? "above" : "below") your normal \(Self.weekdayName).",
                            detail: "This comparison uses \(comparable.count) previous sessions from the same weekday.",
                            icon: "calendar",
                            tone: delta > 0 ? .positive : .neutral
                        )
                    )
                }
            }
        }

        return Array(output.prefix(6))
    }

    private func longestProductiveStreak(in events: [AppEvent]) -> TimeInterval {
        var longest: TimeInterval = 0
        var current: TimeInterval = 0
        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            if event.category == .productive {
                current += event.durationMs
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private static func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date())
    }

    private static var weekdayName: String {
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]
    }
}

private struct DriftInsight: Identifiable {
    enum Tone {
        case positive, warning, neutral

        var color: Color {
            switch self {
            case .positive: return .productive
            case .warning: return .streak
            case .neutral: return Color(.secondaryLabelColor)
            }
        }
    }

    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let tone: Tone
}

private struct InsightRow: View {
    let insight: DriftInsight

    var body: some View {
        HStack(alignment: .top, spacing: Space.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(insight.tone.color.opacity(0.10))
                    .frame(width: 42, height: 42)
                Image(systemName: insight.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(insight.tone.color)
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(insight.title)
                    .font(TypeScale.heading)
                Text(insight.detail)
                    .font(TypeScale.bodySm)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Space.xl)
        .intelligenceSurface()
    }
}

private extension AppCategory {
    static let allCasesForAnalytics: [AppCategory] = [.productive, .neutral, .distraction]
}

private extension View {
    func intelligenceSurface() -> some View {
        background {
            Rectangle()
                .fill(Color.driftPanel)
                .shadow(color: Color.black.opacity(0.10), radius: 0, x: 4, y: 4)
                .overlay {
                    Rectangle()
                        .strokeBorder(Color.border, lineWidth: 1)
                }
        }
    }
}
