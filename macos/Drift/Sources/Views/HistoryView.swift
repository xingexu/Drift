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
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                if appState.pastSessions.isEmpty {
                    emptyState
                } else {
                    summaryRow
                    toolbarRow
                    sessionList
                }
            }
            .padding(28)
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
            VStack(alignment: .leading, spacing: 4) {
                Text("History")
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text("Your past focus sessions")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            if !appState.pastSessions.isEmpty {
                Button {
                    exportSessionsCSV()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .medium))
                        Text("Export")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Export session history")
                .accessibilityHint("Exports all sessions as a CSV file")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.drift.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.quaternary)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("No sessions yet")
                    .font(.system(size: 16, weight: .semibold))
                Text("Complete a tracking session to build your history.\nYour productivity trends will appear here.")
                    .font(.system(size: 13))
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
        HStack(spacing: 14) {
            HistorySummaryStat(
                icon: "list.bullet.rectangle",
                iconColor: Color.drift,
                value: "\(filteredSessions.count)",
                label: filteredSessions.count == appState.pastSessions.count ? "Sessions" : "Showing",
                gradient: [Color.drift.opacity(0.08), Color.drift.opacity(0.02)]
            )
            HistorySummaryStat(
                icon: "star.fill",
                iconColor: .orange,
                value: "\(bestFocusPercent)%",
                label: "Best Focus",
                gradient: [Color.orange.opacity(0.08), Color.orange.opacity(0.02)]
            )
            HistorySummaryStat(
                icon: "clock.fill",
                iconColor: Color("Green"),
                value: formatDurationWords(totalHistoryMs),
                label: "Total Time",
                gradient: [Color("Green").opacity(0.08), Color("Green").opacity(0.02)]
            )
        }
    }

    // MARK: - Toolbar (Search + Sort + Filter)

    private var toolbarRow: some View {
        HStack(spacing: 10) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                TextField("Search apps, dates...", text: $searchText)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search sessions")
                    .accessibilityHint("Filter sessions by app name or date")
                if !searchText.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )

            // Sort picker
            Menu {
                ForEach(HistorySortOrder.allCases) { order in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
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
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .medium))
                    Text(sortOrder.shortLabel)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
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
                        withAnimation(.easeInOut(duration: 0.2)) {
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
                HStack(spacing: 4) {
                    Image(systemName: filterMode.icon)
                        .font(.system(size: 10, weight: .medium))
                    Text(filterMode.shortLabel)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(filterMode == .all ? .secondary : Color.drift)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(filterMode == .all
                              ? Color(.controlBackgroundColor)
                              : Color.drift.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    filterMode == .all
                                        ? Color.primary.opacity(0.06)
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
                LazyVStack(spacing: 12) {
                    ForEach(Array(filteredSessions.enumerated()), id: \.element.id) { index, session in
                        HistorySessionCard(session: session)
                            .opacity(appearedSessionIDs.contains(session.id) ? 1 : 0)
                            .offset(y: appearedSessionIDs.contains(session.id) ? 0 : 8)
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.3).delay(Double(index) * 0.03)) {
                                    appearedSessionIDs.insert(session.id)
                                }
                            }
                    }
                }
            }
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.quaternary)
                .accessibilityHidden(true)

            Text("No matching sessions")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Try adjusting your search or filter criteria.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Button {
                withAnimation {
                    searchText = ""
                    filterMode = .all
                }
            } label: {
                Text("Clear Filters")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.drift)
            }
            .buttonStyle(.plain)
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
    let gradient: [Color]
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isHovered ? .thinMaterial : .ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(isHovered ? 0.06 : 0.03), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Session Card

private struct HistorySessionCard: View {
    let session: PastSession
    @State private var isHovered = false
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
            VStack(alignment: .leading, spacing: 14) {
                // Date + time header with expand chevron
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        Text(Self.dateFormatter.string(from: session.date))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Spacer()
                    Text(Self.timeFormatter.string(from: session.date))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    if !session.topApps.isEmpty {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.quaternary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    }
                }

                // Focus bar
                focusBar

                // Stats row
                statsRow
            }
            .padding(18)

            // Expandable top apps section
            if isExpanded, !session.topApps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 18)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Apps")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        // Wrap flow for app tags
                        FlowLayout(spacing: 6) {
                            ForEach(session.topApps, id: \.self) { app in
                                Text(app)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.primary.opacity(0.03))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                                            )
                                    )
                                    .accessibilityLabel("App: \(app)")
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                    .padding(.top, 4)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(isHovered ? 0.06 : 0.03), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.005 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            guard !session.topApps.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
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

            HStack(spacing: 2) {
                if productiveRatio > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color("Green"), Color("Green").opacity(0.8)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(barWidth * productiveRatio, 2))
                }

                if distractionRatio > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color("Red").opacity(0.8), Color("Red")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(barWidth * distractionRatio, 2))
                }

                if neutralRatio > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.separatorColor).opacity(0.4))
                }
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityLabel("Focus breakdown: \(session.focusPercent)% productive, \(session.driftScore)% distraction")
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color("Green"))
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text("\(session.focusPercent)% focus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                Circle()
                    .fill(Color("Red"))
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text("\(session.driftScore)% drift")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label {
                Text(formatDurationWords(session.totalMs))
                    .font(.system(size: 11, weight: .medium))
            } icon: {
                Image(systemName: "clock")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Duration: \(formatDurationWords(session.totalMs))")

            Label {
                Text("\(session.appCount) apps")
                    .font(.system(size: 11, weight: .medium))
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
    var spacing: CGFloat = 6

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
