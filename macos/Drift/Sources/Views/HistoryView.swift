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
    @State private var appearedGroupIDs: Set<String> = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.xl) {
                headerSection

                if appState.pastSessions.isEmpty {
                    emptySection
                } else {
                    filterBar

                    summaryStrip
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .id(timePeriod)

                    weeklyChart
                        .transition(.opacity)
                        .id(timePeriod)

                    secondaryToolbar

                    sessionContent
                }
            }
            .padding(Space.page)
        }
        .animation(Anim.appear, value: timePeriod)
        .onChange(of: timePeriod) { _, _ in appearedGroupIDs = [] }
        .onChange(of: sortOrder) { _, _ in appearedGroupIDs = [] }
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

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Space.xxxs) {
                Text("History")
                    .font(TypeScale.title)
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text("Your past focus sessions")
                    .font(TypeScale.bodySm)
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            if !appState.pastSessions.isEmpty {
                Button {
                    exportSessionsCSV()
                } label: {
                    HStack(spacing: Space.xxs) {
                        Image(systemName: "square.and.arrow.up")
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
                                    .strokeBorder(Color.sep.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                }
                .driftButton(.ghost)
                .accessibilityLabel("Export session history as CSV")
            }
        }
    }

    // MARK: - Filter Bar (period picker)

    @ViewBuilder
    private var filterBar: some View {
        HStack(spacing: Space.xxs) {
            ForEach(HistoryTimePeriod.allCases) { period in
                Button {
                    withAnimation(Anim.tap) { timePeriod = period }
                } label: {
                    Text(period.rawValue)
                        .font(.system(
                            size: 13,
                            weight: timePeriod == period ? .semibold : .regular
                        ))
                        .foregroundStyle(timePeriod == period ? Color.accent : Color.secondary)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(timePeriod == period
                                      ? Color.accent.opacity(0.12)
                                      : Color.clear)
                                .animation(Anim.quick, value: timePeriod == period)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(timePeriod == period ? .isSelected : [])
            }
        }
        .padding(Space.xxs)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.sep.opacity(0.12), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Summary Strip

    @ViewBuilder
    private var summaryStrip: some View {
        HStack(spacing: Space.md) {
            PeriodSummaryStat(
                value: "\(periodSessions.count)",
                label: periodCountLabel,
                icon: "list.bullet.rectangle",
                color: Color.accent
            )
            summaryDivider
            PeriodSummaryStat(
                value: formatDurationWords(totalPeriodMs),
                label: "Total Focus Time",
                icon: "clock.fill",
                color: Color.productive
            )
            summaryDivider
            PeriodSummaryStat(
                value: "\(avgFocusPercent)%",
                label: "Avg Focus",
                icon: "brain",
                color: Color.streak
            )
            summaryDivider
            // Stacked category bar
            VStack(alignment: .leading, spacing: Space.xxs) {
                periodStackedBar
                    .frame(height: Space.sm)
                Text("Focus breakdown")
                    .font(TypeScale.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
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

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(width: 0.5, height: 32)
    }

    @ViewBuilder
    private var periodStackedBar: some View {
        let totalMs = totalPeriodMs
        let productiveMs = periodSessions.reduce(0.0) { $0 + $1.productiveMs }
        let distractionMs = periodSessions.reduce(0.0) { $0 + $1.distractionMs }
        let neutralMs = periodSessions.reduce(0.0) { $0 + $1.neutralMs }
        let pFrac = totalMs > 0 ? CGFloat(productiveMs / totalMs) : 0
        let dFrac = totalMs > 0 ? CGFloat(distractionMs / totalMs) : 0
        let nFrac = max(0, 1 - pFrac - dFrac)

        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: Space.xxxs) {
                if pFrac > 0 {
                    RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                        .fill(Color.productive)
                        .frame(width: max(w * pFrac, 2))
                }
                if distractionMs > 0 {
                    RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                        .fill(Color.distraction)
                        .frame(width: max(w * dFrac, 2))
                }
                if nFrac > 0 {
                    RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                        .fill(Color.sep.opacity(0.35))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
    }

    // MARK: - Weekly Chart

    @ViewBuilder
    private var weeklyChart: some View {
        if timePeriod == .week || timePeriod == .month || timePeriod == .all {
            let days = last7Days
            let hasAnyData = days.contains { $0.totalMs > 0 }
            if hasAnyData {
                WeeklyBarChart(days: days)
            }
        }
    }

    // MARK: - Secondary Toolbar

    @ViewBuilder
    private var secondaryToolbar: some View {
        HStack(spacing: Space.sm) {
            // Search field
            HStack(spacing: Space.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                TextField("Search apps, dates...", text: $searchText)
                    .font(TypeScale.bodyMd)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search sessions")
                if !searchText.isEmpty {
                    Button {
                        withAnimation(Anim.quick) { searchText = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs + 1)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(Color.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .stroke(Color.sep.opacity(0.15), lineWidth: 1)
                    )
            )

            // Sort menu
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
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .medium))
                    Text(sortOrder.shortLabel)
                        .font(TypeScale.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.xs + 1)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.cardBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .stroke(Color.sep.opacity(0.15), lineWidth: 1)
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
            LazyVStack(spacing: Space.xl) {
                ForEach(groupedSessions) { group in
                    DayGroupSection(
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
                .font(.system(size: 28, weight: .light))
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
        .padding(.vertical, 48)
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
        case .all:   return "Sessions"
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

    private static func dayGroupLabel(
        for date: Date,
        calendar: Calendar,
        now: Date
    ) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if days < 7 {
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return f.string(from: date)
        }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let f = DateFormatter()
        f.dateFormat = sameYear ? "EEE MMM d" : "EEE MMM d, yyyy"
        return f.string(from: date)
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

// MARK: - Day Bar Data

private struct DayBarData: Identifiable {
    let id = UUID()
    let date: Date
    let totalMs: TimeInterval
    let focusFraction: CGFloat
}

// MARK: - Weekly Bar Chart

private struct WeeklyBarChart: View {
    let days: [DayBarData]

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()

    private var maxMs: TimeInterval {
        days.map(\.totalMs).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Last 7 Days")
                .sectionLabel()

            HStack(alignment: .bottom, spacing: Space.xs) {
                ForEach(days) { day in
                    WeeklyBarColumn(
                        day: day,
                        maxMs: max(maxMs, 1),
                        dayLabel: Self.dayFormatter.string(from: day.date)
                    )
                }
            }
            .frame(height: 96)
            .padding(.horizontal, Space.xxs)
        }
        .padding(Space.lg)
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

private struct WeeklyBarColumn: View {
    let day: DayBarData
    let maxMs: TimeInterval
    let dayLabel: String

    private var barFraction: CGFloat {
        day.totalMs > 0 ? CGFloat(day.totalMs / maxMs) : 0
    }

    private var barColor: Color {
        if day.totalMs == 0 { return Color.sep.opacity(0.25) }
        // Linearly interpolate from distraction (red) at 0% to productive (green) at 100%
        // distraction: rgb(0.937, 0.267, 0.267)   productive: rgb(0.133, 0.773, 0.365)
        let t = Double(day.focusFraction)
        let r = 0.937 + t * (0.133 - 0.937)
        let g = 0.267 + t * (0.773 - 0.267)
        let b = 0.267 + t * (0.365 - 0.267)
        return Color(red: r, green: g, blue: b)
    }

    var body: some View {
        VStack(spacing: Space.xs) {
            // Duration label above bar (only when tracked)
            if day.totalMs > 0 {
                Text(formatDurationWords(day.totalMs))
                    .font(TypeScale.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Color.clear.frame(height: 14)
            }

            GeometryReader { geo in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                        .fill(barColor)
                        .frame(height: max(geo.size.height * barFraction, day.totalMs > 0 ? 3 : 2))
                }
            }

            // Day label below
            Text(dayLabel)
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayLabel): \(day.totalMs > 0 ? formatDurationWords(day.totalMs) : "no data")")
    }
}

// MARK: - Period Summary Stat

private struct PeriodSummaryStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxxs) {
            HStack(spacing: Space.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color.opacity(0.8))
                    .accessibilityHidden(true)
                Text(label)
                    .font(TypeScale.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .font(TypeScale.monoSm)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(Anim.count, value: value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Day Group Section

private struct DayGroupSection: View {
    let group: HistorySessionGroup
    let appeared: Bool

    private var dayTotalMs: TimeInterval {
        group.sessions.reduce(0) { $0 + $1.totalMs }
    }

    private var dayProductiveMs: TimeInterval {
        group.sessions.reduce(0) { $0 + $1.productiveMs }
    }

    private var dayDistractionMs: TimeInterval {
        group.sessions.reduce(0) { $0 + $1.distractionMs }
    }

    private var dayNeutralMs: TimeInterval {
        group.sessions.reduce(0) { $0 + $1.neutralMs }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            // Day header row
            HStack(alignment: .center, spacing: Space.md) {
                Text(group.label)
                    .sectionLabel()

                // Stacked bar for this day
                DayStackedBar(
                    productiveMs: dayProductiveMs,
                    neutralMs: dayNeutralMs,
                    distractionMs: dayDistractionMs,
                    totalMs: dayTotalMs
                )
                .frame(maxWidth: 120, minHeight: Space.xs, maxHeight: Space.xs)

                Spacer()

                Text(formatDurationWords(dayTotalMs))
                    .font(TypeScale.monoXs)
                    .foregroundStyle(.tertiary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 4)
            .animation(Anim.appear, value: appeared)

            // Session rows
            VStack(spacing: 0) {
                ForEach(Array(group.sessions.enumerated()), id: \.element.id) { idx, session in
                    VStack(spacing: 0) {
                        if idx > 0 {
                            DriftDivider()
                                .padding(.leading, Space.lg + Space.md + Space.xs)
                        }
                        SessionRow(session: session)
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

// MARK: - Day Stacked Bar

private struct DayStackedBar: View {
    let productiveMs: TimeInterval
    let neutralMs: TimeInterval
    let distractionMs: TimeInterval
    let totalMs: TimeInterval

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let pFrac = totalMs > 0 ? CGFloat(productiveMs / totalMs) : 0
            let dFrac = totalMs > 0 ? CGFloat(distractionMs / totalMs) : 0
            let nFrac = max(0, 1 - pFrac - dFrac)

            HStack(spacing: Space.xxxs) {
                if pFrac > 0 {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.productive)
                        .frame(width: max(w * pFrac, 2))
                }
                if dFrac > 0 {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.distraction)
                        .frame(width: max(w * dFrac, 2))
                }
                if nFrac > 0 {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.sep.opacity(0.35))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: PastSession
    @State private var isExpanded = false
    @State private var isHovered = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private static let endTimeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private var sessionTitle: String {
        session.topApps.first ?? "Focus Session"
    }

    private var appBreakdown: String {
        guard !session.topApps.isEmpty else { return "No app data" }
        return session.topApps.prefix(3).joined(separator: " · ")
    }

    private var sessionColor: Color {
        if session.focusPercent >= 70 { return Color.productive }
        if session.focusPercent >= 40 { return Color.streak }
        return Color.distraction
    }

    private var focusPctColor: Color {
        if session.focusPercent >= 70 { return Color.productive }
        if session.focusPercent >= 40 { return Color.streak }
        return Color.distraction
    }

    private var endDate: Date {
        Date(timeInterval: session.totalMs / 1000, since: session.date)
    }

    private var timeRangeString: String {
        let start = Self.timeFormatter.string(from: session.date)
        let end = Self.endTimeFormatter.string(from: endDate)
        return "\(start) – \(end)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.md) {
                // Time column
                Text(timeRangeString)
                    .font(TypeScale.monoXs)
                    .foregroundStyle(.tertiary)
                    .frame(width: 140, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Dot indicator
                Circle()
                    .fill(sessionColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: sessionColor.opacity(0.5), radius: 3)

                // Title + app breakdown
                VStack(alignment: .leading, spacing: Space.xxxs) {
                    Text(sessionTitle)
                        .font(TypeScale.bodyMd)
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
                        .font(TypeScale.monoSm)
                        .foregroundStyle(.primary)
                    Text("\(session.focusPercent)% focus")
                        .font(TypeScale.caption)
                        .foregroundStyle(focusPctColor)
                }

                // Expand chevron (only if apps available)
                if !session.topApps.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
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
                        .padding(.leading, Space.lg + Space.md + Space.xs)

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
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint(
            session.topApps.isEmpty
                ? ""
                : "Double-tap to \(isExpanded ? "collapse" : "expand") app details"
        )
    }

    private var rowAccessibilityLabel: String {
        "\(timeRangeString), \(session.focusPercent)% focus, \(formatDurationWords(session.totalMs)), \(session.appCount) apps"
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
