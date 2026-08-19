import SwiftUI

private enum TimelineFilter: String, CaseIterable, Identifiable {
    case all = "All activity"
    case productive = "Productive"
    case neutral = "Neutral"
    case distraction = "Distracting"

    var id: String { rawValue }
}

struct SessionView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var tracker: WindowTracker
    @State private var filter: TimelineFilter = .all
    @State private var expandedEventID: UUID?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Space.page)
                .padding(.top, Space.page)
                .padding(.bottom, Space.lg)

            summaryStrip
                .padding(.horizontal, Space.page)
                .padding(.bottom, Space.lg)

            timelineToolbar
                .padding(.horizontal, Space.page)
                .padding(.bottom, Space.sm)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if tracker.isTracking && !tracker.activeApp.isEmpty {
                        liveRow
                        Divider().padding(.leading, 104)
                    }

                    if filteredEvents.isEmpty {
                        emptyTimeline
                    } else {
                        ForEach(filteredEvents) { event in
                            TimelineEventRow(
                                event: event,
                                isExpanded: expandedEventID == event.id
                            ) {
                                withAnimation(Anim.tap) {
                                    expandedEventID = expandedEventID == event.id ? nil : event.id
                                }
                            }

                            if event.id != filteredEvents.last?.id {
                                Divider().padding(.leading, 104)
                            }
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(Color.driftPanel)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                .strokeBorder(Color.border, lineWidth: 0.5)
                        }
                }
                .padding(.horizontal, Space.page)
                .padding(.bottom, Space.page)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(Anim.appear) { appeared = true }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("TIMELINE")
                    .font(TypeScale.h1)
                Text("A chronological record of how your attention moved today.")
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            PrimaryButton(actionLabel.uppercased(), icon: actionIcon, color: appState.accentColor) {
                toggleTracking()
            }
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            TimelineMetric(label: "ACTIVE", value: formatDurationWords(todayTotal), color: appState.accentColor)
            stripDivider
            TimelineMetric(label: "PRODUCTIVE", value: formatDurationWords(todayProductive), color: .productive)
            stripDivider
            TimelineMetric(label: "DISTRACTED", value: formatDurationWords(todayDistraction), color: .distraction)
            stripDivider
            TimelineMetric(label: "SWITCHES", value: "\(max(todayEvents.count - 1, 0))", color: .streak)
        }
        .background {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.driftPanel)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.border, lineWidth: 0.5)
                }
        }
    }

    private var stripDivider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(width: 0.5, height: 40)
    }

    private var timelineToolbar: some View {
        HStack {
            HStack(spacing: 0) {
                ForEach(TimelineFilter.allCases) { item in
                    Button {
                        withAnimation(Anim.quick) { filter = item }
                    } label: {
                        Text(item.rawValue)
                            .font(TypeScale.caption)
                            .fontWeight(filter == item ? .semibold : .regular)
                            .foregroundStyle(filter == item ? .primary : .secondary)
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, Space.xs)
                            .background {
                                if filter == item {
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

            Spacer()
        }
    }

    private var liveRow: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NOW")
                    .font(TypeScale.tiny)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.productive)
                Text(Self.timeFormatter.string(from: Date()))
                    .font(TypeScale.monoXs)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 74, alignment: .leading)

            ZStack {
                Rectangle()
                    .fill(appState.session.currentCategory.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Rectangle()
                    .fill(appState.session.currentCategory.color)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tracker.activeApp)
                    .font(TypeScale.bodyMd)
                    .fontWeight(.semibold)
                Text(tracker.activeTitle.isEmpty ? "Active window" : tracker.activeTitle)
                    .font(TypeScale.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(appState.session.currentCategory.label)
                .font(TypeScale.tiny)
                .fontWeight(.semibold)
                .foregroundStyle(appState.session.currentCategory.color)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xxs)
                .background(
                    Rectangle()
                        .fill(appState.session.currentCategory.color.opacity(0.09))
                        .overlay(Rectangle().strokeBorder(appState.session.currentCategory.color.opacity(0.22), lineWidth: 1))
                )
        }
        .padding(Space.lg)
    }

    private var emptyTimeline: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text(todayEvents.isEmpty ? "No activity periods yet" : "No matching activity")
                .font(TypeScale.heading)
            Text(
                todayEvents.isEmpty
                    ? "Drift records a period after you switch applications. Idle time pauses automatically and is never assigned to an app."
                    : "Choose another classification to inspect your day."
            )
            .font(TypeScale.bodySm)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 430)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
    }

    private var todaySessions: [PastSession] {
        appState.pastSessions.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayEvents: [AppEvent] {
        (todaySessions.flatMap { $0.events ?? [] } + appState.session.events)
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var filteredEvents: [AppEvent] {
        switch filter {
        case .all:
            return todayEvents
        case .productive:
            return todayEvents.filter { $0.category == .productive }
        case .neutral:
            return todayEvents.filter { $0.category == .neutral }
        case .distraction:
            return todayEvents.filter { $0.category == .distraction }
        }
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

    private var actionLabel: String {
        if tracker.isTracking && !tracker.isPaused { return "Pause tracking" }
        if tracker.isPaused { return "Resume tracking" }
        return "Start tracking"
    }

    private var actionIcon: String {
        tracker.isTracking && !tracker.isPaused ? "pause.fill" : "play.fill"
    }

    private func toggleTracking() {
        if tracker.isTracking && !tracker.isPaused {
            tracker.pause()
        } else {
            tracker.start()
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

private struct TimelineMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .sectionLabel()
            Text(value)
                .font(TypeScale.monoMd)
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }
}

private struct TimelineEventRow: View {
    let event: AppEvent
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: Space.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.timeFormatter.string(from: event.timestamp))
                            .font(TypeScale.monoXs)
                            .foregroundStyle(.secondary)
                        Text(formatDurationWords(event.durationMs))
                            .font(TypeScale.tiny)
                            .foregroundStyle(.quaternary)
                    }
                    .frame(width: 74, alignment: .leading)

                    Rectangle()
                        .fill(event.category.color)
                        .frame(width: 3, height: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.owner)
                            .font(TypeScale.bodyMd)
                            .fontWeight(.semibold)
                        Text(event.title.isEmpty ? "Window details unavailable" : event.title)
                            .font(TypeScale.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(event.category.label)
                        .font(TypeScale.tiny)
                        .fontWeight(.semibold)
                        .foregroundStyle(event.category.color)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, Space.xxs)
                        .background(
                            Rectangle()
                                .fill(event.category.color.opacity(0.09))
                                .overlay(Rectangle().strokeBorder(event.category.color.opacity(0.22), lineWidth: 1))
                        )

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Space.lg)

                if isExpanded {
                    HStack(spacing: Space.xxl) {
                        detail(label: "START", value: Self.fullTimeFormatter.string(from: event.timestamp))
                        detail(label: "DURATION", value: formatDurationWords(event.durationMs))
                        detail(label: "TYPE", value: event.isBrowser ? "Browser" : "Application")
                        if let url = event.url, !url.isEmpty {
                            detail(label: "DOMAIN", value: url)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 104)
                    .padding(.bottom, Space.lg)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func detail(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).sectionLabel()
            Text(value)
                .font(TypeScale.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let fullTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter
    }()
}
