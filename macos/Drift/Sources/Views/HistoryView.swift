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

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var range: AnalyticsRange = .week
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.xxl) {
                header
                rangePicker

                if hasData {
                    kpiStrip

                    productivityTrend
                    sessionLedger
                } else {
                    emptyAnalytics
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("ANALYTICS")
                    .font(TypeScale.h1)
                Text("Patterns, comparisons, and trends from your own history.")
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
            }

            Spacer()

        }
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
            AnalyticsKPI(
                label: "EFFICIENCY",
                value: "\(averageEfficiency)",
                comparison: comparison(current: Double(averageEfficiency), previous: previousEfficiency, unit: "pts"),
                color: appState.accentColor
            )
            kpiDivider
            AnalyticsKPI(
                label: "FOCUS TIME",
                value: formatDurationWords(totalProductive),
                comparison: durationComparison(current: totalProductive, previous: previousProductive),
                color: .productive
            )
            kpiDivider
            AnalyticsKPI(
                label: "DISTRACTION",
                value: formatDurationWords(totalDistraction),
                comparison: durationComparison(current: totalDistraction, previous: previousDistraction, lowerIsBetter: true),
                color: .distraction
            )
            kpiDivider
            AnalyticsKPI(
                label: "SESSIONS",
                value: "\(periodSessions.count + (includeCurrentSession ? 1 : 0))",
                comparison: sessionComparison,
                color: .streak
            )
        }
        .analyticsSurface()
    }

    private var kpiDivider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(width: 0.5, height: 56)
    }

    private var productivityTrend: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            chartHeader(
                title: "PRODUCTIVITY OVER TIME",
                detail: dailyPoints.count > 1 ? "\(dailyPoints.count) recorded days" : "First recorded day"
            )

            Chart(dailyPoints) { point in
                AreaMark(
                    x: .value("Day", point.date),
                    y: .value("Efficiency", point.efficiency)
                )
                .foregroundStyle(appState.accentColor.opacity(0.14))
                .interpolationMethod(.stepCenter)

                LineMark(
                    x: .value("Day", point.date),
                    y: .value("Efficiency", point.efficiency)
                )
                .foregroundStyle(appState.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .butt))
                .interpolationMethod(.stepCenter)

                PointMark(
                    x: .value("Day", point.date),
                    y: .value("Efficiency", point.efficiency)
                )
                .foregroundStyle(appState.accentColor)
                .symbolSize(20)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine().foregroundStyle(Color.border)
                    AxisValueLabel {
                        if let score = value.as(Int.self) {
                            Text("\(score)")
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
            .frame(height: 220)
        }
        .padding(Space.xl)
        .analyticsSurface()
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
                HStack(spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.sessionDateFormatter.string(from: session.date))
                            .font(TypeScale.bodySm)
                            .fontWeight(.semibold)
                        Text(Self.sessionTimeFormatter.string(from: session.date))
                            .font(TypeScale.tiny)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 130, alignment: .leading)

                    ledgerValue(label: "DURATION", value: formatDurationWords(session.totalMs))
                    ledgerValue(label: "EFFICIENCY", value: "\(session.efficiencyScore)")
                    ledgerValue(label: "FOCUS", value: "\(session.focusPercent)%")
                    ledgerValue(label: "APPS", value: "\(session.appCount)")

                    Spacer()

                    Rectangle()
                        .fill(session.driftScore < 25 ? Color.productive : Color.distraction)
                        .frame(width: 36, height: 4)
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)

                if session.id != periodSessions.prefix(10).last?.id {
                    Divider()
                }
            }
        }
        .analyticsSurface()
    }

    private var emptyAnalytics: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Not enough data for analytics")
                .font(TypeScale.h2)
            Text("Complete a tracked session in this range. Drift will compare it only against your own recorded history.")
                .font(TypeScale.bodyMd)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 90)
        .analyticsSurface()
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

        return grouped.map { date, sessions in
            DailyPoint(
                id: date,
                date: date,
                productiveMs: sessions.reduce(0) { $0 + $1.productiveMs },
                neutralMs: sessions.reduce(0) { $0 + $1.neutralMs },
                distractionMs: sessions.reduce(0) { $0 + $1.distractionMs }
            )
        }
        .sorted { $0.date < $1.date }
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
