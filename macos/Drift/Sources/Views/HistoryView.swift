import SwiftUI
import UniformTypeIdentifiers

// MARK: - History Time Period

enum HistoryTimePeriod: String, CaseIterable, Identifiable {
    case today = "Today"
    case week  = "Week"
    case month = "Month"
    case all   = "All"

    var id: String { rawValue }
}

// MARK: - Sort Order

enum HistorySortOrder: String, CaseIterable, Identifiable {
    case newest, oldest, highestFocus, lowestFocus, longest, shortest
    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest:       return "Newest First"
        case .oldest:       return "Oldest First"
        case .highestFocus: return "Highest Focus"
        case .lowestFocus:  return "Lowest Focus"
        case .longest:      return "Longest Duration"
        case .shortest:     return "Shortest Duration"
        }
    }

    var shortLabel: String {
        switch self {
        case .newest:       return "Newest"
        case .oldest:       return "Oldest"
        case .highestFocus: return "Best Focus"
        case .lowestFocus:  return "Worst Focus"
        case .longest:      return "Longest"
        case .shortest:     return "Shortest"
        }
    }
}

// MARK: - Session Group

struct HistorySessionGroup: Identifiable {
    let id: String
    let label: String
    let date: Date
    var sessions: [PastSession]
}

// MARK: - History View

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var timePeriod: HistoryTimePeriod = .week
    @State private var sortOrder: HistorySortOrder = .newest
    @State private var searchText = ""
    @State private var exportError: String?
    @State private var showExportError = false
    @State private var showExportSuccess = false
    @State private var exportedFileURL: URL?
    @State private var appeared = false
    @State private var appearedGroupIDs: Set<String> = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.xl) {
                // MARK: Page header
                headerSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.28).delay(0 * 0.06), value: appeared)

                if appState.pastSessions.isEmpty {
                    emptySection
                } else {
                    // MARK: Period tabs
                    periodTabs
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.28).delay(1 * 0.06), value: appeared)

                    // MARK: Stat cards
                    statCards
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.28).delay(2 * 0.06), value: appeared)
                        .id(timePeriod)

                    // MARK: Bar chart card
                    barChartCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.28).delay(3 * 0.06), value: appeared)
                        .id(timePeriod)

                    // MARK: Search bar
                    searchBar
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.28).delay(4 * 0.06), value: appeared)

                    // MARK: Session list
                    sessionContent
                }
            }
            .padding(Space.page)
        }
        .animation(Anim.appear, value: timePeriod)
        .onAppear {
            withAnimation { appeared = true }
        }
        .onChange(of: timePeriod) { _, _ in appearedGroupIDs = [] }
        .onChange(of: sortOrder)  { _, _ in appearedGroupIDs = [] }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "Could not export data. Please try again.")
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            if let url = exportedFileURL {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Session history has been exported as CSV.")
        }
    }

    // MARK: - Page Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Space.xxxs) {
                Text("History")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text("Your past focus sessions — search, filter, and export.")
                    .font(TypeScale.bodySm)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            if !appState.pastSessions.isEmpty {
                Button {
                    exportSessionsCSV()
                } label: {
                    HStack(spacing: Space.xxs) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 11, weight: .medium))
                        Text("Export CSV")
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.xs)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                }
                .driftButton(.ghost)
                .accessibilityLabel("Export session history as CSV")
            }
        }
    }

    // MARK: - Period Tabs (pill segmented style)

    @ViewBuilder
    private var periodTabs: some View {
        HStack(spacing: 0) {
            ForEach(HistoryTimePeriod.allCases) { period in
                Button {
                    withAnimation(Anim.tap) { timePeriod = period }
                } label: {
                    Text(period.rawValue)
                        .font(.system(size: 13, weight: timePeriod == period ? .semibold : .medium))
                        .foregroundStyle(timePeriod == period ? Color.primary : Color.secondary)
                        .padding(.horizontal, Space.lg)
                        .padding(.vertical, Space.sm)
                        .frame(maxWidth: .infinity)
                        .background(
                            Group {
                                if timePeriod == period {
                                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                        .fill(Color(.controlBackgroundColor))
                                        .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                                }
                            }
                            .animation(Anim.quick, value: timePeriod == period)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(timePeriod == period ? .isSelected : [])
            }
        }
        .padding(Space.xxxs)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    // MARK: - 4 Stat Cards

    @ViewBuilder
    private var statCards: some View {
        HStack(spacing: Space.sm) {
            HistoryStatCard(
                value: "\(periodSessions.count)",
                label: periodCountLabel.uppercased(),
                icon: "calendar"
            )
            HistoryStatCard(
                value: formatDurationWords(totalPeriodMs),
                label: "TOTAL FOCUS",
                icon: "timer.circle",
                color: Color.productive
            )
            HistoryStatCard(
                value: "\(avgFocusPercent)%",
                label: "AVG FOCUS",
                icon: "bolt",
                color: Color.caution
            )
            HistoryStatCard(
                value: avgSessionLabel,
                label: "AVG SESSION",
                icon: "chart.line.uptrend.xyaxis",
                color: Color.accent
            )
        }
    }

    // MARK: - Last 7 Days Bar Chart Card

    @ViewBuilder
    private var barChartCard: some View {
        let days = last7Days
        let hasData = days.contains { $0.totalMs > 0 }

        VStack(alignment: .leading, spacing: Space.md) {
            // Card header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Space.xxxs) {
                    Text("LAST 7 DAYS")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.tertiary)
                    HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                        Text(hasData ? formatDurationWords(bestDayMs) : "--")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("· best day \(bestDayShortName)")
                            .font(TypeScale.bodySm)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: Space.xl) {
                    VStack(alignment: .trailing, spacing: Space.xxxs) {
                        Text("PEAK HOURS")
                            .font(.system(size: 9.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(.tertiary)
                        Text(peakHoursLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .trailing, spacing: Space.xxxs) {
                        Text("AVG SESSION")
                            .font(.system(size: 9.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(.tertiary)
                        Text(avgSessionLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }

            // Bar chart
            GeometryReader { geo in
                let barCount = days.count
                let totalSpacing = Space.xs * CGFloat(barCount - 1)
                let barWidth = (geo.size.width - totalSpacing) / CGFloat(barCount)
                let chartHeight: CGFloat = 90
                let maxMs = days.map(\.totalMs).max() ?? 1

                HStack(alignment: .bottom, spacing: Space.xs) {
                    ForEach(days) { day in
                        let fraction: CGFloat = maxMs > 0 ? CGFloat(day.totalMs / maxMs) : 0
                        let barHeight = max(fraction * chartHeight, day.totalMs > 0 ? 4 : 2)
                        let barColor: Color = day.totalMs > 0
                            ? interpolateBarColor(fraction: day.focusFraction)
                            : Color.sep.opacity(0.25)

                        VStack(spacing: Space.xs) {
                            Spacer(minLength: 0)
                            UnevenRoundedRectangle(
                                topLeadingRadius: 3,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 3,
                                style: .continuous
                            )
                            .fill(barColor)
                            .frame(width: barWidth, height: barHeight)

                            Text(dayLabel(for: day.date))
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(height: chartHeight + 16) // bar height + label height
            }
            .frame(height: 106)
        }
        .padding(Space.xl)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.border, lineWidth: 0.5)
                )
        )
        .elevate(.xs)
    }

    // MARK: - Search Bar

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Image(systemName: "magnifyingglass")
                    .font(TypeScale.bodySm)
                    .foregroundStyle(.tertiary)

                TextField("Search apps, dates, tasks...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(TypeScale.bodyMd)
                    .accessibilityLabel("Search sessions")

                Spacer()

                if !searchText.isEmpty {
                    Button {
                        withAnimation(Anim.quick) { searchText = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(TypeScale.bodySm)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(Color.border, lineWidth: 0.5)
                    )
            )

            // Sort toggle
            Menu {
                ForEach(HistorySortOrder.allCases) { order in
                    Button {
                        withAnimation(Anim.quick) { sortOrder = order }
                    } label: {
                        HStack {
                            Text(order.label)
                            if sortOrder == order { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: Space.xxs) {
                    Text(sortOrder.shortLabel)
                        .font(TypeScale.caption)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(Color.border, lineWidth: 0.5)
                        )
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Sort sessions")
            .accessibilityValue(sortOrder.label)
        }
    }

    // MARK: - Session Content

    @ViewBuilder
    private var sessionContent: some View {
        if groupedSessions.isEmpty {
            noResultsState
        } else {
            LazyVStack(alignment: .leading, spacing: Space.xl) {
                ForEach(groupedSessions) { group in
                    DateGroupSection(
                        group: group,
                        appeared: appearedGroupIDs.contains(group.id)
                    )
                    .onAppear {
                        withAnimation(Anim.appear) {
                            _ = appearedGroupIDs.insert(group.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var noResultsState: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "magnifyingglass")
                .font(TypeScale.h1)
                .fontWeight(.light)
                .foregroundStyle(.quaternary)
                .accessibilityHidden(true)
            Text("No sessions found")
                .font(TypeScale.heading)
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty
                 ? "No sessions in this time period yet."
                 : "Try adjusting your search.")
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)
            if !searchText.isEmpty {
                Button {
                    withAnimation(Anim.quick) { searchText = "" }
                } label: {
                    Text("Clear Search")
                        .font(TypeScale.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accent)
                }
                .driftButton(.ghost)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, Space.xxxl + Space.lg)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var emptySection: some View {
        EmptyStateView(
            icon: "clock.badge.checkmark",
            title: "No sessions yet",
            message: "Start tracking to see your history here"
        )
        .padding(.top, Space.xxxl)
    }

    // MARK: - Computed Properties

    private var periodCountLabel: String {
        switch timePeriod {
        case .today: return "Today"
        case .week:  return "This Week"
        case .month: return "This Month"
        case .all:   return "All Time"
        }
    }

    private var periodSessions: [PastSession] {
        let calendar = Calendar.current
        let now = Date()
        switch timePeriod {
        case .today:
            return appState.pastSessions.filter { calendar.isDateInToday($0.date) }
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return appState.pastSessions.filter { $0.date >= start }
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return appState.pastSessions.filter { $0.date >= start }
        case .all:
            return appState.pastSessions
        }
    }

    private var filteredSessions: [PastSession] {
        var sessions = periodSessions
        if !searchText.isEmpty {
            let q = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !q.isEmpty {
                sessions = sessions.filter { s in
                    s.topApps.contains { $0.lowercased().contains(q) }
                    || Self.searchDateFormatter.string(from: s.date).lowercased().contains(q)
                }
            }
        }
        return sortedSessions(sessions)
    }

    private var groupedSessions: [HistorySessionGroup] {
        let calendar = Calendar.current
        let now = Date()
        let sessions = filteredSessions
        if sessions.isEmpty { return [] }

        switch timePeriod {
        case .today:
            return [HistorySessionGroup(
                id: "today",
                label: "Today",
                date: calendar.startOfDay(for: now),
                sessions: sessions
            )]
        case .week, .month, .all:
            return groupByDay(sessions, calendar: calendar, now: now)
        }
    }

    private func groupByDay(
        _ sessions: [PastSession],
        calendar: Calendar,
        now: Date
    ) -> [HistorySessionGroup] {
        var map: [(key: Date, sessions: [PastSession])] = []
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            if let idx = map.firstIndex(where: { $0.key == day }) {
                map[idx].sessions.append(session)
            } else {
                map.append((key: day, sessions: [session]))
            }
        }
        map.sort { $0.key > $1.key }
        return map.map { day, daySessions in
            HistorySessionGroup(
                id: "\(day.timeIntervalSince1970)",
                label: Self.dayGroupLabel(for: day, calendar: calendar, now: now),
                date: day,
                sessions: daySessions
            )
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f
    }()
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE MMM d"; return f
    }()
    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE MMM d, yyyy"; return f
    }()

    private static func dayGroupLabel(
        for date: Date,
        calendar: Calendar,
        now: Date
    ) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if days < 7 {
            return weekdayFormatter.string(from: date)
        }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return (sameYear ? shortDateFormatter : longDateFormatter).string(from: date)
    }

    private func sortedSessions(_ sessions: [PastSession]) -> [PastSession] {
        switch sortOrder {
        case .newest:       return sessions.sorted { $0.date > $1.date }
        case .oldest:       return sessions.sorted { $0.date < $1.date }
        case .highestFocus: return sessions.sorted { $0.focusPercent > $1.focusPercent }
        case .lowestFocus:  return sessions.sorted { $0.focusPercent < $1.focusPercent }
        case .longest:      return sessions.sorted { $0.totalMs > $1.totalMs }
        case .shortest:     return sessions.sorted { $0.totalMs < $1.totalMs }
        }
    }

    private var totalPeriodMs: TimeInterval {
        periodSessions.reduce(0) { $0 + $1.totalMs }
    }

    private var avgFocusPercent: Int {
        guard !periodSessions.isEmpty else { return 0 }
        return periodSessions.map(\.focusPercent).reduce(0, +) / periodSessions.count
    }

    private var avgSessionLabel: String {
        guard !periodSessions.isEmpty else { return "--" }
        let avg = periodSessions.reduce(0.0) { $0 + $1.totalMs } / TimeInterval(periodSessions.count)
        return formatDurationWords(avg)
    }

    private var peakHoursLabel: String {
        guard !periodSessions.isEmpty else { return "--" }
        var hourCounts: [Int: Int] = [:]
        for session in periodSessions {
            let hour = Calendar.current.component(.hour, from: session.date)
            hourCounts[hour, default: 0] += 1
        }
        guard let peakHour = hourCounts.max(by: { $0.value < $1.value })?.key else { return "--" }
        let endHour = (peakHour + 2) % 24
        func fmt(_ h: Int) -> String {
            let h24 = h % 24
            let h12 = h24 % 12 == 0 ? 12 : h24 % 12
            let suffix = h24 < 12 ? "am" : "pm"
            return "\(h12)\(suffix)"
        }
        return "\(fmt(peakHour))–\(fmt(endHour))"
    }

    // Returns the last 7 calendar days with aggregated session data
    private var last7Days: [DayBarData] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<7).reversed().map { offset -> DayBarData in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else {
                return DayBarData(date: now, totalMs: 0, focusFraction: 0)
            }
            let dayStart = calendar.startOfDay(for: day)
            let daySessions = appState.pastSessions.filter {
                calendar.isDate($0.date, inSameDayAs: dayStart)
            }
            let totalMs = daySessions.reduce(0.0) { $0 + $1.totalMs }
            let productiveMs = daySessions.reduce(0.0) { $0 + $1.productiveMs }
            let focusFraction = totalMs > 0 ? CGFloat(productiveMs / totalMs) : 0
            return DayBarData(date: day, totalMs: totalMs, focusFraction: focusFraction)
        }
    }

    private var bestDayMs: TimeInterval {
        last7Days.map(\.totalMs).max() ?? 0
    }

    private var bestDayShortName: String {
        guard let best = last7Days.max(by: { $0.totalMs < $1.totalMs }), best.totalMs > 0 else {
            return "--"
        }
        return Self.weekdayFormatter.string(from: best.date)
    }

    private func dayLabel(for date: Date) -> String {
        Self.weekdayFormatter.string(from: date)
    }

    private func interpolateBarColor(fraction: CGFloat) -> Color {
        let t = Double(fraction)
        let r = 0.937 + t * (0.133 - 0.937)
        let g = 0.267 + t * (0.773 - 0.267)
        let b = 0.267 + t * (0.365 - 0.267)
        return Color(red: r, green: g, blue: b)
    }

    private static let searchDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE MMM d yyyy MMMM"
        return f
    }()

    // MARK: - Export

    private func exportSessionsCSV() {
        let sessions = filteredSessions
        guard !sessions.isEmpty else {
            exportError = "No sessions to export."
            showExportError = true
            return
        }
        var csv = "Date,Time,Duration (min),Focus %,Drift %,Apps Used,Top Apps\n"
        let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"
        for session in sessions {
            let topApps = session.topApps
                .joined(separator: "; ")
                .replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(dateFmt.string(from: session.date)),"
                + "\(timeFmt.string(from: session.date)),"
                + "\(Int(session.totalMs / 60_000)),"
                + "\(session.focusPercent),"
                + "\(session.driftScore),"
                + "\(session.appCount),"
                + "\"\(topApps)\"\n"
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "drift-sessions-\(dateFmt.string(from: Date())).csv"
        panel.title = "Export Session History"
        panel.message = "Choose where to save your session history."
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                exportedFileURL = url
                showExportSuccess = true
            } catch {
                exportError = "Failed to write file: \(error.localizedDescription)"
                showExportError = true
            }
        }
    }
}

// MARK: - History Stat Card

private struct HistoryStatCard: View {
    let value: String
    let label: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
        .elevate(.xs)
    }
}

// MARK: - Day Bar Data

private struct DayBarData: Identifiable {
    let id = UUID()
    let date: Date
    let totalMs: TimeInterval
    let focusFraction: CGFloat
}

// MARK: - Date Group Section

private struct DateGroupSection: View {
    let group: HistorySessionGroup
    let appeared: Bool

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var dayTotalMs: TimeInterval {
        group.sessions.reduce(0) { $0 + $1.totalMs }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            // Date group header row with hairline feel
            HStack(spacing: Space.xs) {
                Text(group.label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)

                Text(Self.dateFormatter.string(from: group.date))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.quaternary)

                Spacer()

                Text(formatDurationWords(dayTotalMs))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Space.xxxs)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 4)
            .animation(Anim.appear, value: appeared)

            // Session rows card
            VStack(spacing: 0) {
                ForEach(Array(group.sessions.enumerated()), id: \.element.id) { idx, session in
                    VStack(spacing: 0) {
                        if idx > 0 {
                            DriftDivider()
                                .padding(.leading, Space.lg)
                        }
                        HistorySessionRow(session: session)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(
                        Anim.appear.delay(Double(idx) * 0.045),
                        value: appeared
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .strokeBorder(Color.border, lineWidth: 0.5)
                    )
            )
            .elevate(.xs)
        }
    }
}

// MARK: - History Session Row

private struct HistorySessionRow: View {
    let session: PastSession
    @State private var isExpanded = false
    @State private var isHovered = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private var sessionTitle: String {
        session.topApps.first ?? "Focus Session"
    }

    private var appBreakdown: String {
        guard !session.topApps.isEmpty else { return "No app data" }
        return session.topApps.prefix(4).joined(separator: " · ")
    }

    private var dotColor: Color {
        session.focusPercent > 50 ? Color.productive : Color.caution
    }

    private var focusPctColor: Color {
        if session.focusPercent >= 70 { return Color.productive }
        if session.focusPercent >= 40 { return Color.streak }
        return Color.distraction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.md) {
                // Time + dot indicator
                HStack(spacing: Space.xs) {
                    Text(Self.timeFormatter.string(from: session.date))
                        .font(TypeScale.monoXs)
                        .foregroundStyle(.tertiary)
                        .frame(width: 56, alignment: .trailing)
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: dotColor.opacity(0.5), radius: 3)
                }

                // Title + app breakdown
                VStack(alignment: .leading, spacing: Space.xxxs) {
                    Text(sessionTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(appBreakdown)
                        .font(TypeScale.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Duration + focus %
                VStack(alignment: .trailing, spacing: Space.xxxs) {
                    Text(formatDurationWords(session.totalMs))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("\(session.focusPercent)% focus")
                        .font(TypeScale.caption)
                        .foregroundStyle(focusPctColor)
                }

                // Expand chevron
                if !session.topApps.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(TypeScale.tiny)
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(Anim.tap, value: isExpanded)
                }
            }
            .padding(.vertical, Space.sm)
            .padding(.horizontal, Space.md)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.025) : Color.clear)
                    .animation(Anim.hover, value: isHovered)
            )
            .onHover { isHovered = $0 }
            .onTapGesture {
                guard !session.topApps.isEmpty else { return }
                withAnimation(Anim.tap) { isExpanded.toggle() }
            }

            // Expanded app tags
            if isExpanded, !session.topApps.isEmpty {
                VStack(alignment: .leading, spacing: Space.xs) {
                    DriftDivider()
                        .padding(.leading, Space.md)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.xs) {
                            ForEach(session.topApps, id: \.self) { app in
                                DriftTag(text: app, color: Color.accent)
                            }
                        }
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(Self.timeFormatter.string(from: session.date)), \(session.focusPercent)% focus, \(formatDurationWords(session.totalMs))"
        )
        .accessibilityHint(
            session.topApps.isEmpty ? "" : "Double-tap to \(isExpanded ? "collapse" : "expand") app details"
        )
    }
}

// MARK: - Flow Layout (retained for compatibility)

private struct FlowLayout: Layout {
    var spacing: CGFloat = Space.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layoutSubviews(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            guard index < subviews.count else { break }
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult { var positions: [CGPoint]; var size: CGSize }

    private func layoutSubviews(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + rowHeight
        }
        return LayoutResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: totalHeight)
        )
    }
}
