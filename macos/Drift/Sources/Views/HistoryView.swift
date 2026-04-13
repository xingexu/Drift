import SwiftUI
import UniformTypeIdentifiers

// MARK: - History View

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var sortOrder: HistorySortOrder = .newest
    @State private var filterMode: HistoryFilterMode = .all
    @State private var showExportSheet = false
    @State private var exportError: String?
    @State private var showExportError = false
    @State private var showExportSuccess = false
    @State private var exportedFileURL: URL?
    @State private var appearedSessionIDs: Set<UUID> = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.xxl) {
                headerSection

                if appState.pastSessions.isEmpty {
                    emptyState
                } else {
                    summaryRow
                    toolbarRow
                    sessionList
                }
            }
            .padding(Space.page)
        }
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

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("History")
                    .font(TypeScale.title)
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text("Your past focus sessions")
                    .font(TypeScale.body)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            if !appState.pastSessions.isEmpty {
                Button {
                    exportSessionsCSV()
                } label: {
                    HStack(spacing: Space.xxs + 1) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .medium))
                        Text("Export")
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.xs)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(Color.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm)
                                    .stroke(Color.sep.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                .driftButton(.ghost)
                .accessibilityLabel("Export session history")
                .accessibilityHint("Exports all sessions as a CSV file")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Space.lg + 2) {
            ZStack {
                Circle()
                    .fill(Color.drift.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.quaternary)
            }
            .accessibilityHidden(true)

            VStack(spacing: Space.sm) {
                Text("No sessions yet")
                    .font(TypeScale.heading)
                Text("Complete a tracking session to build your history.\nYour productivity trends will appear here.")
                    .font(TypeScale.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No sessions yet. Complete a tracking session to build your history.")
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: Space.lg - 2) {
            HistorySummaryStat(
                icon: "list.bullet.rectangle",
                iconColor: Color.drift,
                value: "\(filteredSessions.count)",
                label: filteredSessions.count == appState.pastSessions.count ? "Sessions" : "Showing",
                tintColor: Color.drift
            )
            HistorySummaryStat(
                icon: "star.fill",
                iconColor: .streak,
                value: "\(bestFocusPercent)%",
                label: "Best Focus",
                tintColor: .streak
            )
            HistorySummaryStat(
                icon: "clock.fill",
                iconColor: .productive,
                value: formatDurationWords(totalHistoryMs),
                label: "Total Time",
                tintColor: .productive
            )
        }
    }

    // MARK: - Toolbar (Search + Sort + Filter)

    private var toolbarRow: some View {
        HStack(spacing: Space.md) {
            // Search field
            HStack(spacing: Space.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                TextField("Search apps, dates...", text: $searchText)
                    .font(TypeScale.body)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search sessions")
                    .accessibilityHint("Filter sessions by app name or date")
                if !searchText.isEmpty {
                    Button {
                        withAnimation(Anim.quick) {
                            searchText = ""
                        }
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
            .padding(.vertical, Space.sm - 1)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(Color.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .stroke(Color.sep.opacity(0.15), lineWidth: 1)
                    )
            )

            // Sort picker
            Menu {
                ForEach(HistorySortOrder.allCases) { order in
                    Button {
                        withAnimation(Anim.quick) {
                            sortOrder = order
                        }
                    } label: {
                        HStack {
                            Text(order.label)
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
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
                .padding(.vertical, Space.sm - 1)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(Color.cardBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .stroke(Color.sep.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Sort sessions")
            .accessibilityValue(sortOrder.label)

            // Filter picker
            Menu {
                ForEach(HistoryFilterMode.allCases) { mode in
                    Button {
                        withAnimation(Anim.quick) {
                            filterMode = mode
                        }
                    } label: {
                        HStack {
                            Label(mode.label, systemImage: mode.icon)
                            if filterMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Space.xxs) {
                    Image(systemName: filterMode.icon)
                        .font(.system(size: 10, weight: .medium))
                    Text(filterMode.shortLabel)
                        .font(TypeScale.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(filterMode == .all ? .secondary : Color.drift)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm - 1)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(filterMode == .all
                              ? Color.cardBg
                              : Color.drift.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .stroke(
                                    filterMode == .all
                                        ? Color.sep.opacity(0.15)
                                        : Color.drift.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Filter sessions")
            .accessibilityValue(filterMode.label)
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        Group {
            if filteredSessions.isEmpty {
                noResultsState
            } else {
                LazyVStack(spacing: Space.md) {
                    ForEach(Array(filteredSessions.enumerated()), id: \.element.id) { index, session in
                        HistorySessionCard(session: session)
                            .staggerAppear(index: index, appeared: appearedSessionIDs.contains(session.id))
                            .onAppear {
                                appearedSessionIDs.insert(session.id)
                            }
                    }
                }
            }
        }
    }

    private var noResultsState: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.quaternary)
                .accessibilityHidden(true)

            Text("No matching sessions")
                .font(TypeScale.heading)
                .foregroundStyle(.secondary)

            Text("Try adjusting your search or filter criteria.")
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)

            Button {
                withAnimation(Anim.quick) {
                    searchText = ""
                    filterMode = .all
                }
            } label: {
                Text("Clear Filters")
                    .font(TypeScale.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.drift)
            }
            .driftButton(.ghost)
            .accessibilityLabel("Clear all filters")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Computed Properties

    private var filteredSessions: [PastSession] {
        var sessions = appState.pastSessions

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return sortedSessions(sessions) }

            sessions = sessions.filter { session in
                // Match against top apps
                if session.topApps.contains(where: { $0.lowercased().contains(query) }) {
                    return true
                }
                // Match against formatted date
                let dateStr = Self.searchDateFormatter.string(from: session.date).lowercased()
                if dateStr.contains(query) {
                    return true
                }
                return false
            }
        }

        // Apply category filter
        switch filterMode {
        case .all:
            break
        case .highFocus:
            sessions = sessions.filter { $0.focusPercent >= 70 }
        case .lowFocus:
            sessions = sessions.filter { $0.focusPercent < 40 }
        case .longSessions:
            sessions = sessions.filter { $0.totalMs >= 3_600_000 } // 1 hour+
        case .today:
            let calendar = Calendar.current
            sessions = sessions.filter { calendar.isDateInToday($0.date) }
        case .thisWeek:
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            sessions = sessions.filter { $0.date >= weekAgo }
        }

        return sortedSessions(sessions)
    }

    private func sortedSessions(_ sessions: [PastSession]) -> [PastSession] {
        switch sortOrder {
        case .newest:
            return sessions.sorted { $0.date > $1.date }
        case .oldest:
            return sessions.sorted { $0.date < $1.date }
        case .highestFocus:
            return sessions.sorted { $0.focusPercent > $1.focusPercent }
        case .lowestFocus:
            return sessions.sorted { $0.focusPercent < $1.focusPercent }
        case .longest:
            return sessions.sorted { $0.totalMs > $1.totalMs }
        case .shortest:
            return sessions.sorted { $0.totalMs < $1.totalMs }
        }
    }

    private var bestFocusPercent: Int {
        filteredSessions.map(\.focusPercent).max() ?? 0
    }

    private var totalHistoryMs: TimeInterval {
        filteredSessions.reduce(0) { $0 + $1.totalMs }
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
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        for session in sessions {
            let date = dateFmt.string(from: session.date)
            let time = timeFmt.string(from: session.date)
            let durationMin = Int(session.totalMs / 60_000)
            let topApps = session.topApps.joined(separator: "; ")
            let sanitizedApps = topApps
                .replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(date),\(time),\(durationMin),\(session.focusPercent),\(session.driftScore),\(session.appCount),\"\(sanitizedApps)\"\n"
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

// MARK: - Sort Order

enum HistorySortOrder: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case highestFocus
    case lowestFocus
    case longest
    case shortest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: return "Newest First"
        case .oldest: return "Oldest First"
        case .highestFocus: return "Highest Focus"
        case .lowestFocus: return "Lowest Focus"
        case .longest: return "Longest Duration"
        case .shortest: return "Shortest Duration"
        }
    }

    var shortLabel: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .highestFocus: return "Best"
        case .lowestFocus: return "Worst"
        case .longest: return "Longest"
        case .shortest: return "Shortest"
        }
    }
}

// MARK: - Filter Mode

enum HistoryFilterMode: String, CaseIterable, Identifiable {
    case all
    case highFocus
    case lowFocus
    case longSessions
    case today
    case thisWeek

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All Sessions"
        case .highFocus: return "High Focus (70%+)"
        case .lowFocus: return "Low Focus (<40%)"
        case .longSessions: return "Long Sessions (1h+)"
        case .today: return "Today"
        case .thisWeek: return "This Week"
        }
    }

    var shortLabel: String {
        switch self {
        case .all: return "All"
        case .highFocus: return "High"
        case .lowFocus: return "Low"
        case .longSessions: return "Long"
        case .today: return "Today"
        case .thisWeek: return "Week"
        }
    }

    var icon: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .highFocus: return "flame"
        case .lowFocus: return "exclamationmark.triangle"
        case .longSessions: return "hourglass"
        case .today: return "sun.max"
        case .thisWeek: return "calendar"
        }
    }
}

// MARK: - Summary Stat

private struct HistorySummaryStat: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let tintColor: Color

    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)

            Text(value)
                .font(TypeScale.mono)
                .font(.system(size: 22))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())

            Text(label)
                .sectionLabel()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.lg + 2)
        .padding(.horizontal, Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(tintColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.sep.opacity(0.15), lineWidth: 0.5)
                )
        )
        .hoverLift()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Session Card

private struct HistorySessionCard: View {
    let session: PastSession
    @State private var isExpanded = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content (always visible)
            VStack(alignment: .leading, spacing: Space.lg - 2) {
                // Date + time header with expand chevron
                HStack {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        Text(Self.dateFormatter.string(from: session.date))
                            .font(TypeScale.heading)
                            .font(.system(size: 14))
                    }
                    Spacer()
                    Text(Self.timeFormatter.string(from: session.date))
                        .font(TypeScale.monoSm)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    if !session.topApps.isEmpty {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.quaternary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(Anim.quick, value: isExpanded)
                    }
                }

                // Focus bar
                focusBar

                // Stats row
                statsRow
            }
            .padding(Space.lg + 2)

            // Expandable top apps section
            if isExpanded, !session.topApps.isEmpty {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Divider()
                        .padding(.horizontal, Space.lg + 2)

                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("Top Apps")
                            .sectionLabel()

                        // Wrap flow for app tags
                        FlowLayout(spacing: Space.xs) {
                            ForEach(session.topApps, id: \.self) { app in
                                Text(app)
                                    .font(TypeScale.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, Space.md)
                                    .padding(.vertical, Space.xxs)
                                    .background(
                                        RoundedRectangle(cornerRadius: Radius.sm)
                                            .fill(Color.primary.opacity(0.03))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: Radius.sm)
                                                    .stroke(Color.sep.opacity(0.1), lineWidth: 1)
                                            )
                                    )
                                    .accessibilityLabel("App: \(app)")
                            }
                        }
                    }
                    .padding(.horizontal, Space.lg + 2)
                    .padding(.bottom, Space.lg)
                    .padding(.top, Space.xxs)
                }
                .transition(.opacity)
            }
        }
        .driftCard(padding: 0)
        .hoverLift()
        .contentShape(Rectangle())
        .onTapGesture {
            guard !session.topApps.isEmpty else { return }
            withAnimation(Anim.tap) {
                isExpanded.toggle()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(session.topApps.isEmpty ? "" : "Double-tap to \(isExpanded ? "collapse" : "expand") app details")
    }

    // MARK: - Focus Bar

    private var focusBar: some View {
        GeometryReader { geo in
            let total = session.productiveMs + session.neutralMs + session.distractionMs
            let productiveRatio = total > 0 ? CGFloat(session.productiveMs / total) : 0
            let distractionRatio = total > 0 ? CGFloat(session.distractionMs / total) : 0
            let neutralRatio = max(0, 1 - productiveRatio - distractionRatio)
            let barWidth = geo.size.width

            HStack(spacing: Space.xxxs) {
                if productiveRatio > 0 {
                    RoundedRectangle(cornerRadius: Space.xxs)
                        .fill(Color.productive)
                        .frame(width: max(barWidth * productiveRatio, 2))
                }

                if distractionRatio > 0 {
                    RoundedRectangle(cornerRadius: Space.xxs)
                        .fill(Color.distraction)
                        .frame(width: max(barWidth * distractionRatio, 2))
                }

                if neutralRatio > 0 {
                    RoundedRectangle(cornerRadius: Space.xxs)
                        .fill(Color.sep.opacity(0.4))
                }
            }
        }
        .frame(height: Space.sm)
        .clipShape(RoundedRectangle(cornerRadius: Space.xxs))
        .accessibilityLabel("Focus breakdown: \(session.focusPercent)% productive, \(session.driftScore)% distraction")
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Space.lg) {
            HStack(spacing: Space.xxs + 1) {
                Circle()
                    .fill(Color.productive)
                    .frame(width: Space.xs, height: Space.xs)
                    .accessibilityHidden(true)
                Text("\(session.focusPercent)% focus")
                    .font(TypeScale.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Space.xxs + 1) {
                Circle()
                    .fill(Color.distraction)
                    .frame(width: Space.xs, height: Space.xs)
                    .accessibilityHidden(true)
                Text("\(session.driftScore)% drift")
                    .font(TypeScale.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label {
                Text(formatDurationWords(session.totalMs))
                    .font(TypeScale.caption)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "clock")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Duration: \(formatDurationWords(session.totalMs))")

            Label {
                Text("\(session.appCount) apps")
                    .font(TypeScale.caption)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("\(session.appCount) applications used")
        }
    }

    // MARK: - Accessibility

    private var cardAccessibilityLabel: String {
        let dateStr = Self.dateFormatter.string(from: session.date)
        let timeStr = Self.timeFormatter.string(from: session.date)
        return "\(dateStr) at \(timeStr), \(session.focusPercent)% focus, \(formatDurationWords(session.totalMs)), \(session.appCount) apps"
    }
}

// MARK: - Flow Layout

/// A simple horizontal wrapping layout for tag-like views.
private struct FlowLayout: Layout {
    var spacing: CGFloat = Space.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            guard index < subviews.count else { break }
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
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

        return LayoutResult(positions: positions, size: CGSize(width: totalWidth, height: totalHeight))
    }
}
