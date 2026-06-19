import SwiftUI
import UniformTypeIdentifiers

// MARK: - Session View

struct SessionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker
    @State private var appeared = false
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var exportError: String?
    @State private var exportedFileURL: URL?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.xxl) {

                // MARK: Page Header
                pageHeader
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.28).delay(0.0), value: appeared)

                // MARK: Main Body
                HStack(alignment: .top, spacing: Space.lg) {

                    // LEFT: ring + status + controls
                    leftCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.28).delay(0.06), value: appeared)

                    // RIGHT: stat tiles column
                    rightColumn
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.28).delay(0.12), value: appeared)
                }

                // MARK: App Breakdown
                appBreakdownCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.28).delay(0.18), value: appeared)
            }
            .padding(Space.page)
        }
        .task {
            guard !appeared else { return }
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(Anim.appear) {
                appeared = true
            }
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "Could not export session data.")
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            if let url = exportedFileURL {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Session data has been exported as CSV.")
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("Session")
                    .font(TypeScale.h1)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("A live view of what you're doing right now. Start a session to begin tracking productive time.")
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack(spacing: Space.xs) {
                GhostButton("Reset", icon: "arrow.counterclockwise") {
                    tracker.resetSession()
                }
                .disabled(!tracker.isTracking)
                .opacity(tracker.isTracking ? 1 : 0.45)

                GhostButton("Export", icon: "square.and.arrow.up") {
                    exportCurrentSession()
                }
            }
        }
    }

    // MARK: - Left Card

    private var leftCard: some View {
        VStack(spacing: Space.xl) {

            // 1. Status pill
            statusPill

            // 2. Ring chart
            ringChart

            // 3. Controls
            controlStrip
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                }
        }
        .elevate(.md)
    }

    // MARK: Status Pill

    private var statusPill: some View {
        HStack(spacing: Space.xs) {
            StatusDot(status: trackerStatus)
            Text(pillLabel)
                .font(TypeScale.bodyMd)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm)
        .background {
            Capsule()
                .fill(Color.primary.opacity(0.06))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
        }
        .animation(Anim.quick, value: pillLabel)
    }

    private var pillLabel: String {
        if tracker.isTracking && !tracker.isPaused {
            return "Tracking \u{00B7} Session in progress"
        }
        return "Stopped \u{00B7} Waiting for activity"
    }

    // MARK: Ring Chart

    private var ringChart: some View {
        let productiveFraction = CGFloat(appState.session.focusPercent) / 100.0

        return ZStack {
            // Track (full 270 arc, dimmed distraction color)
            ProductivityArcTrack(fraction: 1.0, color: Color.distraction.opacity(0.18))

            // Soft glow blur layer beneath fill
            ProductivityArcFill(
                fraction: max(productiveFraction, 0.01),
                gradient: AngularGradient(
                    colors: [Color.productive.opacity(0.35), Color.productive.opacity(0.20)],
                    center: .center,
                    startAngle: .degrees(-225),
                    endAngle: .degrees(225)
                )
            )
            .blur(radius: 8)

            // Productive fill
            ProductivityArcFill(
                fraction: productiveFraction,
                gradient: AngularGradient(
                    colors: [Color.productive.opacity(0.75), Color.productive],
                    center: .center,
                    startAngle: .degrees(-225),
                    endAngle: .degrees(225)
                )
            )

            // Center label stack
            VStack(spacing: Space.xxs) {
                Text(formatDuration(appState.session.totalMs))
                    .font(TypeScale.display)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(Anim.count, value: appState.session.totalMs)

                Text(tracker.isTracking && !tracker.isPaused ? "ELAPSED" : "READY")
                    .font(TypeScale.tiny)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                    .animation(Anim.quick, value: tracker.isTracking)

                HStack(spacing: Space.xxs) {
                    Circle()
                        .fill(Color.productive)
                        .frame(width: Space.xs, height: Space.xs)
                    Text("\(appState.session.focusPercent)% productive")
                        .font(TypeScale.caption)
                        .foregroundStyle(.tertiary)
                        .contentTransition(.numericText())
                        .animation(Anim.count, value: appState.session.focusPercent)
                }
                .padding(.top, Space.xxxs)
            }
        }
        .frame(width: 200, height: 160)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Productivity ring: \(appState.session.focusPercent) percent productive, \(appState.session.driftScore) percent drift.")
    }

    // MARK: Control Strip

    private var controlStrip: some View {
        HStack(spacing: Space.md) {
            // Reset (ghost secondary)
            Button {
                tracker.resetSession()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tracker.isTracking ? Color(.labelColor) : Color(.tertiaryLabelColor))
                    .frame(width: 36, height: 36)
                    .background {
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
                    }
            }
            .buttonStyle(.plain)
            .disabled(!tracker.isTracking)
            .accessibilityLabel("Reset session")

            // Play / Pause — big blue circle
            SessionActionButton(
                icon: actionButtonIcon,
                label: actionButtonLabel,
                accessibilityHint: actionAccessibilityHint,
                action: toggleTracking
            )

            // Stop — square icon ghost button
            Button {
                if tracker.isTracking {
                    tracker.resetSession()
                }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tracker.isTracking ? Color(.labelColor) : Color(.tertiaryLabelColor))
                    .frame(width: 36, height: 36)
                    .background {
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
                    }
            }
            .buttonStyle(.plain)
            .disabled(!tracker.isTracking)
            .accessibilityLabel("Stop session")
        }
    }

    // MARK: - Right Column (fixed ~280pt)

    private var rightColumn: some View {
        VStack(spacing: Space.sm) {

            // Active app tile
            activeAppTile

            // Metric tiles
            metricTile(
                icon: "timer",
                iconColor: Color.accent,
                value: formatDurationWords(appState.session.totalMs),
                label: "TOTAL TIME"
            )

            metricTile(
                icon: "bolt.fill",
                iconColor: Color.productive,
                value: formatDurationWords(appState.session.productiveMs),
                label: "PRODUCTIVE"
            )

            metricTile(
                icon: "arrow.trianglehead.2.clockwise.rotate.90",
                iconColor: Color.streak,
                value: "\(appState.session.uniqueApps)",
                label: "APP SWITCHES"
            )

            metricTile(
                icon: "exclamationmark.triangle.fill",
                iconColor: Color.distraction,
                value: formatDurationWords(appState.session.distractionMs),
                label: "DISTRACTION"
            )
        }
        .frame(width: 280)
    }

    // MARK: Active App Tile

    private var activeAppTile: some View {
        let appName = tracker.activeApp
        let category = appState.session.currentCategory
        let isActive = tracker.isTracking && !tracker.isPaused && !appName.isEmpty

        return HStack(spacing: Space.sm) {
            // Round icon badge with first letter
            ZStack {
                Circle()
                    .fill((isActive ? category.color : Color(.tertiaryLabelColor)).opacity(0.15))
                    .frame(width: 34, height: 34)
                Text(isActive ? String(appName.prefix(1)).uppercased() : "—")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isActive ? category.color : Color(.tertiaryLabelColor))
            }

            VStack(alignment: .leading, spacing: Space.xxxs) {
                Text(isActive ? appName : "No active app")
                    .font(TypeScale.bodyMd)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.identity)
                    .animation(Anim.quick, value: appName)

                Text(isActive ? "Active" : "Idle")
                    .font(TypeScale.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            DriftTag(
                text: isActive ? category.label : "Neutral",
                color: isActive ? category.color : Color(.tertiaryLabelColor)
            )
            .animation(Anim.quick, value: category.label)
        }
        .padding(Space.md)
        .background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(
                            isActive && category.label == "Productive"
                                ? Color.productive.opacity(0.30)
                                : Color.primary.opacity(0.07),
                            lineWidth: isActive && category.label == "Productive" ? 1 : 0.5
                        )
                }
        }
        .elevate(.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isActive ? "Active app: \(appName), \(category.label)" : "No active app, Idle")
    }

    // MARK: Metric Tile Builder

    private func metricTile(icon: String, iconColor: Color, value: String, label: String) -> some View {
        StatTile(icon: icon, iconColor: iconColor, value: value, label: label)
    }

    // MARK: - App Breakdown Card

    private var appBreakdownCard: some View {
        let breakdown = buildAppBreakdown()

        return VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("App Breakdown")
                    .sectionLabel()
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(breakdown.count) apps")
                    .font(TypeScale.caption)
                    .foregroundStyle(.quaternary)
            }

            if breakdown.isEmpty {
                SessionEmptyTimeline()
            } else {
                let maxMs = breakdown.first?.durationMs ?? 1
                VStack(spacing: Space.xs) {
                    ForEach(Array(breakdown.enumerated()), id: \.element.name) { idx, item in
                        AppBreakdownRow(
                            item: item,
                            maxMs: maxMs
                        )
                        .staggerAppear(index: idx, appeared: appeared, baseDelay: 0.04)

                        if idx < breakdown.count - 1 {
                            DriftDivider(opacity: 0.6)
                        }
                    }
                }
            }
        }
        .padding(Space.xl)
        .background {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                }
        }
        .elevate(.md)
    }

    // MARK: - Computed Properties

    private var trackerStatus: StatusDot.Status {
        if tracker.isIdle { return .idle }
        if tracker.isPaused { return .paused }
        if tracker.isTracking { return .tracking }
        return .idle
    }

    private var statusLabel: String {
        if tracker.isIdle { return "Idle" }
        if tracker.isPaused { return "Paused" }
        if tracker.isTracking { return "Tracking" }
        return "Stopped"
    }

    private var actionButtonIcon: String {
        if tracker.isTracking && !tracker.isPaused { return "pause.fill" }
        return "play.fill"
    }

    private var actionButtonLabel: String {
        if !tracker.isTracking { return "Start" }
        if tracker.isPaused { return "Resume" }
        return "Pause"
    }

    private var actionAccessibilityHint: String {
        if !tracker.isTracking { return "Starts a new tracking session" }
        if tracker.isPaused { return "Resumes the paused session" }
        return "Pauses the current session"
    }

    // MARK: - Actions

    private func toggleTracking() {
        withAnimation(Anim.tap) {
            if tracker.isTracking && !tracker.isPaused {
                tracker.pause()
            } else {
                tracker.start()
            }
        }
    }

    // MARK: - App Breakdown Builder

    fileprivate struct AppBreakdownItem {
        let name: String
        let category: AppCategory
        let durationMs: TimeInterval
        let eventCount: Int
    }

    private func buildAppBreakdown() -> [AppBreakdownItem] {
        var durationMap: [String: TimeInterval] = [:]
        var categoryMap: [String: AppCategory] = [:]
        var countMap: [String: Int] = [:]

        for event in appState.session.events {
            durationMap[event.owner, default: 0] += event.durationMs
            countMap[event.owner, default: 0] += 1
            // Last-write wins for category (most recent)
            categoryMap[event.owner] = event.category
        }

        return durationMap
            .map { name, ms in
                AppBreakdownItem(
                    name: name,
                    category: categoryMap[name] ?? .neutral,
                    durationMs: ms,
                    eventCount: countMap[name] ?? 0
                )
            }
            .sorted { $0.durationMs > $1.durationMs }
            .prefix(8)
            .map { $0 }
    }

    // MARK: - Export

    private func exportCurrentSession() {
        let session = appState.session
        guard session.totalMs > 0 else {
            exportError = "No session data to export. Start tracking first."
            showExportError = true
            return
        }

        let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm:ss"
        let now = session.startTime ?? Date()

        // Build app-level rows from breakdown items
        let breakdown = buildAppBreakdown()
        var csv  = "Date,Start Time,Duration (min),Focus %,Drift %,Apps Used\n"
        csv += "\(dateFmt.string(from: now)),"
            + "\(timeFmt.string(from: now)),"
            + "\(Int(session.totalMs / 60_000)),"
            + "\(session.focusPercent),"
            + "\(session.driftScore),"
            + "\(session.uniqueApps)\n"
        csv += "\nApp,Category,Duration (min),Events\n"
        for item in breakdown {
            let appName = item.name
                .replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(appName)\","
                + "\(item.category.label),"
                + "\(Int(item.durationMs / 60_000)),"
                + "\(item.eventCount)\n"
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "drift-session-\(dateFmt.string(from: now)).csv"
        panel.title = "Export Session"
        panel.message = "Choose where to save this session's data."
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

// MARK: - Stat Tile (right column metric cards)

private struct StatTile: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Space.sm) {
            IconBadge(systemName: icon, color: iconColor, size: 32)

            VStack(alignment: .leading, spacing: Space.xxxs) {
                Text(value)
                    .font(TypeScale.monoMd)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(Anim.count, value: value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(TypeScale.tiny)
                    .foregroundStyle(.tertiary)
                    .tracking(0.8)
            }

            Spacer()
        }
        .padding(Space.md)
        .background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(
                            isHovered ? iconColor.opacity(0.22) : Color.primary.opacity(0.07),
                            lineWidth: 0.5
                        )
                }
        }
        .elevate(isHovered ? .md : .sm)
        .scaleEffect(isHovered ? 1.012 : 1.0)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Productivity Arc Shapes (270° sweep)

/// The track or fill arc — 270° sweep starting from bottom-left (135°).
private struct ProductivityArcTrack: View {
    let fraction: CGFloat
    let color: Color
    private let startAngle: Angle = .degrees(135)
    private let sweepDegrees: Double = 270

    var body: some View {
        Arc(fraction: fraction, startAngle: startAngle, sweepDegrees: sweepDegrees)
            .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
            .frame(width: 180, height: 180)
    }
}

private struct ProductivityArcFill<G: ShapeStyle>: View {
    let fraction: CGFloat
    let gradient: G
    private let startAngle: Angle = .degrees(135)
    private let sweepDegrees: Double = 270

    var body: some View {
        Arc(fraction: fraction, startAngle: startAngle, sweepDegrees: sweepDegrees)
            .stroke(gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
            .frame(width: 180, height: 180)
            .animation(Anim.appear, value: fraction)
    }
}

private struct Arc: Shape {
    var fraction: CGFloat
    let startAngle: Angle
    let sweepDegrees: Double

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let endDegrees = sweepDegrees * Double(max(0, min(1, fraction)))
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: startAngle,
            endAngle: startAngle + .degrees(endDegrees),
            clockwise: false
        )
        return p
    }
}

// MARK: - App Breakdown Row

private struct AppBreakdownRow: View {
    let item: SessionView.AppBreakdownItem
    let maxMs: TimeInterval

    @State private var isHovered = false

    private var avatarLetter: String {
        String(item.name.prefix(1)).uppercased()
    }

    private var timeFraction: CGFloat {
        guard maxMs > 0 else { return 0 }
        return CGFloat(item.durationMs / maxMs)
    }

    var body: some View {
        HStack(spacing: Space.md) {
            // First-letter avatar badge
            ZStack {
                Circle()
                    .fill(item.category.color.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text(avatarLetter)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(item.category.color)
            }

            // App name + category tag
            VStack(alignment: .leading, spacing: Space.xxxs) {
                HStack(spacing: Space.xs) {
                    Text(item.name)
                        .font(TypeScale.bodyMd)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    DriftTag(text: item.category.label, color: item.category.color)
                }
                // Relative time bar (thin capsule)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.07))
                        Capsule()
                            .fill(item.category.color.opacity(0.55))
                            .frame(width: max(4, geo.size.width * timeFraction))
                    }
                }
                .frame(height: 3)
                .animation(Anim.appear, value: timeFraction)
            }

            Spacer(minLength: Space.xs)

            // Duration on the right
            Text(formatDurationWords(item.durationMs))
                .font(TypeScale.monoXs)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, Space.xxs)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.04) : .clear)
        )
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.category.label), \(formatDurationWords(item.durationMs))")
    }
}

// MARK: - Session Action Button (Start / Pause / Resume — big blue circle)

private struct SessionActionButton: View {
    let icon: String
    let label: String
    let accessibilityHint: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isHovered ? Color.accent.opacity(0.88) : Color.accent)
                    .frame(width: 52, height: 52)
                    .shadow(
                        color: Color.accent.opacity(isHovered ? 0.45 : 0.30),
                        radius: isHovered ? 12 : 8,
                        y: 3
                    )
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .animation(Anim.hover, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.06 : 1.0)
        .animation(Anim.hover, value: isHovered)
        .accessibilityLabel(label)
        .accessibilityHint(accessibilityHint)
    }
}

// MARK: - Session Empty Timeline

private struct SessionEmptyTimeline: View {
    var body: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: "waveform.path")
                .font(TypeScale.h2)
                .fontWeight(.light)
                .foregroundStyle(.quaternary)
            Text("Activity will appear here during tracking.")
                .font(TypeScale.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, Space.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No activity yet. Activity will appear here during tracking.")
    }
}

