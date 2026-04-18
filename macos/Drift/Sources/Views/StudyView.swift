import SwiftUI
import UserNotifications
import ApplicationServices
import Combine

// MARK: - Study View

struct StudyView: View {
    @StateObject private var viewModel = StudyViewModel()
    @StateObject private var blocker = FocusBlocker.shared

    var body: some View {
        ZStack {
            // Ambient layered background
            AmbientBackground(
                mode: viewModel.mode,
                driftFraction: viewModel.driftFraction
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.lg) {
                    if viewModel.showBlockedBanner {
                        BlockedBanner(
                            isVisible: $viewModel.showBlockedBanner,
                            site: blocker.lastBlockedSite
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    heroRingCard

                    sessionStatsRow
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    if viewModel.mode == .idle {
                        FocusBlockerSection(blocker: blocker)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if blocker.isBlocking {
                        activeBlockerBadge
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(Space.page)
            }

            // Completion flash overlay
            if viewModel.showCompletion {
                CompletionOverlay()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(Anim.appear, value: viewModel.mode)
        .animation(Anim.appear, value: viewModel.showCompletion)
        .onChange(of: viewModel.focusDuration) { _, v in
            if viewModel.mode == .idle { viewModel.timeRemaining = v * 60 }
        }
        .onChange(of: blocker.blockedAttempts) { _, v in
            guard v > 0 else { return }
            withAnimation(Anim.appear) { viewModel.showBlockedBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(Anim.quick) { viewModel.showBlockedBanner = false }
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .focusable()
        .onKeyPress(.space) {
            viewModel.togglePlayPause()
            return .handled
        }
        .onKeyPress(.escape) {
            if viewModel.mode != .idle { viewModel.showStopConfirmation = true }
            return .handled
        }
    }

    // MARK: - Hero Ring Card

    @ViewBuilder
    private var heroRingCard: some View {
        VStack(spacing: 0) {
            heroHeader
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.xl)
                .padding(.bottom, Space.sm)

            // Hero timer ring
            HeroTimerRing(
                timeRemaining: viewModel.timeRemaining,
                progress: viewModel.progress,
                mode: viewModel.mode,
                modeLabel: viewModel.modeLabel,
                ringColor: viewModel.ringColor,
                focusPercent: viewModel.focusPercent,
                completionFlash: viewModel.completionRingFlash
            )
            .padding(.vertical, Space.xl)

            VStack(spacing: Space.lg) {
                if viewModel.mode == .idle {
                    SubjectInput(subject: $viewModel.subject)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    DurationConfig(
                        focusDuration: $viewModel.focusDuration,
                        breakDuration: $viewModel.breakDuration
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if !viewModel.subject.isEmpty {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        Text(viewModel.subject)
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, Space.xl)
            .animation(Anim.appear, value: viewModel.mode)

            Spacer(minLength: Space.xl)

            // Controls — generous vertical space
            HeroControls(
                mode: viewModel.mode,
                onStart: viewModel.startFocus,
                onStop: { viewModel.showStopConfirmation = true },
                onSkip: viewModel.skipPhase
            )
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
            .alert("End Focus Session?", isPresented: $viewModel.showStopConfirmation) {
                Button("Keep Going", role: .cancel) {}
                Button("End Session", role: .destructive) { viewModel.stopStudy() }
            } message: {
                Text("Ending early means losing your focus streak.")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 20, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.sep.opacity(0.10), lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private var heroHeader: some View {
        HStack(alignment: .center) {
            if viewModel.mode == .idle {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("Focus")
                        .font(.system(size: 26, weight: .bold))
                        .tracking(-0.5)
                    Text("Deep work, distraction-free")
                        .font(TypeScale.body)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: Space.xs) {
                    StatusDot(status: viewModel.mode == .focus ? .tracking : .paused)
                    Text(viewModel.modeLabel.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(viewModel.ringColor)
                        .tracking(2)
                }
            }
            Spacer()
            if viewModel.mode != .idle {
                HStack(spacing: Space.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accent.opacity(0.6))
                    Text("Session \(viewModel.sessionCount + 1)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xxs)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(Anim.appear, value: viewModel.mode)
    }

    // MARK: - Session Stats Row

    @ViewBuilder
    private var sessionStatsRow: some View {
        HStack(spacing: Space.md) {
            StatMetricChip(
                icon: "brain.head.profile",
                value: formatStudyTime(viewModel.totalFocusTime),
                label: "Focus Time",
                color: Color.productive
            )
            StatMetricChip(
                icon: "hand.raised.fill",
                value: "\(blocker.blockedAttempts)",
                label: "Drift Events",
                color: Color.distraction
            )
            .opacity(viewModel.mode != .idle || blocker.blockedAttempts > 0 ? 1 : 0.4)
            StatMetricChip(
                icon: "checkmark.circle.fill",
                value: "\(viewModel.sessionCount)",
                label: "Sessions",
                color: Color.accent
            )
        }
        .animation(Anim.quick, value: blocker.blockedAttempts)
    }

    // MARK: - Active Blocker Badge (shown during focus when blocking)

    @ViewBuilder
    private var activeBlockerBadge: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.sm) {
                DriftTag(text: "\(blocker.blockedSites.count) sites blocked", color: Color.distraction)
                Spacer()
                HStack(spacing: Space.xxs) {
                    Circle()
                        .fill(Color.distraction)
                        .frame(width: Space.xs, height: Space.xs)
                    Text("Blocking Active")
                        .font(TypeScale.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.distraction)
                }
            }

            if !blocker.blockedSites.isEmpty {
                let preview = Array(blocker.blockedSites.prefix(4))
                HStack(spacing: Space.xs) {
                    ForEach(preview, id: \.self) { site in
                        Text(site)
                            .font(TypeScale.tiny)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Space.xs)
                            .padding(.vertical, Space.xxxs)
                            .background(
                                Capsule().fill(Color.primary.opacity(0.06))
                                    .overlay(Capsule().strokeBorder(Color.sep.opacity(0.12), lineWidth: 0.5))
                            )
                            .lineLimit(1)
                    }
                    if blocker.blockedSites.count > 4 {
                        Text("+\(blocker.blockedSites.count - 4) more")
                            .font(TypeScale.tiny)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.distraction.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.distraction.opacity(0.12), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Study View Model

@MainActor
final class StudyViewModel: ObservableObject {
    enum StudyMode: Equatable { case idle, focus, rest }

    @Published var mode: StudyMode = .idle
    @Published var timeRemaining: Int = 25 * 60
    @Published var totalFocusTime: Int = 0
    @Published var sessionCount: Int = 0
    @Published var subject: String = ""
    @Published var focusDuration: Int = 25
    @Published var breakDuration: Int = 5
    @Published var showStopConfirmation = false
    @Published var showBlockedBanner = false
    @Published var showCompletion = false
    @Published var completionRingFlash = false

    private var timerCancellable: AnyCancellable?
    private var phaseEndDate: Date?
    private var phaseTotalSeconds: Int = 0
    private var lastAnnouncedMinute: Int = -1

    var progress: CGFloat {
        switch mode {
        case .idle:  return 0
        case .focus: return 1 - CGFloat(timeRemaining) / CGFloat(focusDuration * 60)
        case .rest:  return 1 - CGFloat(timeRemaining) / CGFloat(breakDuration * 60)
        }
    }

    /// Fraction of elapsed focus time vs total elapsed time (0…1), for ambient drift
    var driftFraction: CGFloat {
        guard totalFocusTime + FocusBlocker.shared.blockedAttempts > 0 else { return 0 }
        let drift = CGFloat(FocusBlocker.shared.blockedAttempts)
        let total = CGFloat(totalFocusTime / 60) + drift
        return total > 0 ? min(drift / total, 1) : 0
    }

    /// 0-100 focus purity score (100 = no drift events)
    var focusPercent: Int {
        guard mode != .idle else { return 100 }
        let attempts = FocusBlocker.shared.blockedAttempts
        if attempts == 0 { return 100 }
        let focusMins = max(1, (focusDuration * 60 - timeRemaining) / 60)
        return max(0, 100 - Int(Double(attempts) / Double(focusMins) * 20))
    }

    var ringColor: Color {
        switch mode {
        case .idle, .focus: return Color.accent
        case .rest:         return Color.productive
        }
    }

    var modeLabel: String {
        switch mode {
        case .idle:  return "Ready"
        case .focus: return "Focus"
        case .rest:  return "Break"
        }
    }

    func onAppear() {}
    func onDisappear() { stopTimer() }

    func startFocus() {
        mode = .focus
        phaseTotalSeconds = focusDuration * 60
        timeRemaining = phaseTotalSeconds
        phaseEndDate = Date().addingTimeInterval(TimeInterval(phaseTotalSeconds))
        if !WindowTracker.shared.isTracking && AXIsProcessTrusted() {
            WindowTracker.shared.start()
        }
        AppState.shared.focusModeActive = true
        let blocker = FocusBlocker.shared
        if !blocker.isBlocking {
            blocker.startBlocking(durationMinutes: focusDuration, password: nil)
        }
        startTimer()
    }

    func stopStudy() {
        stopTimer()
        if mode == .focus { totalFocusTime += (focusDuration * 60 - timeRemaining) }
        mode = .idle
        timeRemaining = focusDuration * 60
        phaseEndDate = nil
        AppState.shared.focusModeActive = false
        let blocker = FocusBlocker.shared
        if blocker.isBlocking { let _ = blocker.stopBlocking(password: nil) }
    }

    func skipPhase() {
        stopTimer()
        if mode == .focus {
            sessionCount += 1
            totalFocusTime += (focusDuration * 60 - timeRemaining)
            startBreak()
        } else {
            startFocus()
        }
    }

    func togglePlayPause() {
        if mode == .idle { startFocus() }
    }

    private func startBreak() {
        mode = .rest
        phaseTotalSeconds = breakDuration * 60
        timeRemaining = phaseTotalSeconds
        phaseEndDate = Date().addingTimeInterval(TimeInterval(phaseTotalSeconds))
        startTimer()
        sendNotification(title: "Focus complete!", body: "Take a \(breakDuration)-minute break.")
    }

    private func startTimer() {
        stopTimer()
        lastAnnouncedMinute = -1
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func tick() {
        guard let endDate = phaseEndDate else { return }
        let remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        timeRemaining = remaining
        announceTimeIfNeeded(remaining)
        guard remaining <= 0 else { return }
        stopTimer()
        triggerCompletionAnimation()
        if mode == .focus {
            sessionCount += 1
            totalFocusTime += phaseTotalSeconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.startBreak()
            }
        } else {
            sendNotification(title: "Break over!", body: "Time to focus again.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.startFocus()
            }
        }
    }

    private func triggerCompletionAnimation() {
        withAnimation(Anim.appear) { completionRingFlash = true }
        withAnimation(Anim.appear.delay(0.4)) { showCompletion = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            withAnimation(Anim.appear) {
                self?.completionRingFlash = false
                self?.showCompletion = false
            }
        }
    }

    private func announceTimeIfNeeded(_ seconds: Int) {
        let currentMinute = seconds / 60
        let shouldAnnounce: Bool
        if seconds == 10 { shouldAnnounce = true }
        else if seconds == 60 { shouldAnnounce = true }
        else if currentMinute > 0 && currentMinute % 5 == 0 && seconds % 60 == 0 && currentMinute != lastAnnouncedMinute { shouldAnnounce = true }
        else { shouldAnnounce = false }
        guard shouldAnnounce else { return }
        lastAnnouncedMinute = currentMinute
        let label = seconds < 60 ? "\(seconds) seconds remaining" : "\(currentMinute) minute\(currentMinute == 1 ? "" : "s") remaining"
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            NSAccessibility.NotificationUserInfoKey.announcement: label,
            NSAccessibility.NotificationUserInfoKey.priority: NSAccessibilityPriorityLevel.high.rawValue
        ])
    }

    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }
}

// MARK: - Ambient Background

private struct AmbientBackground: View {
    let mode: StudyViewModel.StudyMode
    let driftFraction: CGFloat

    private var primaryColor: Color {
        switch mode {
        case .idle:  return .clear
        case .focus: return Color.accent
        case .rest:  return Color.productive
        }
    }

    var body: some View {
        ZStack {
            Color("Background")

            // Primary radial — breathes from center
            if mode != .idle {
                RadialGradient(
                    colors: [
                        primaryColor.opacity(mode == .focus ? 0.08 : 0.06),
                        .clear
                    ],
                    center: .center,
                    startRadius: 60,
                    endRadius: 400
                )
                .ignoresSafeArea()
                .animation(Anim.appear, value: mode)
            }

            // Secondary ambient — bottom-right drift tint when distraction is high
            if driftFraction > 0.25 {
                RadialGradient(
                    colors: [Color.distraction.opacity(0.03 * min(driftFraction * 4, 1)), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .animation(Anim.appear, value: driftFraction > 0.25)
            }
        }
    }
}

// MARK: - Hero Timer Ring (260pt, premium)

private struct HeroTimerRing: View {
    let timeRemaining: Int
    let progress: CGFloat
    let mode: StudyViewModel.StudyMode
    let modeLabel: String
    let ringColor: Color
    let focusPercent: Int
    let completionFlash: Bool

    private let ringSize: CGFloat = 260
    private let trackWidth: CGFloat = 10

    // Flash state — ring turns productive green on completion
    private var strokeColor: Color {
        completionFlash ? Color.productive : ringColor
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.sep.opacity(0.10), lineWidth: trackWidth)
                .frame(width: ringSize, height: ringSize)

            // Progress arc with angular gradient + glow
            if progress > 0 || completionFlash {
                let trimTo: CGFloat = completionFlash ? 1.0 : min(progress, 1.0)
                Circle()
                    .trim(from: 0, to: trimTo)
                    .stroke(
                        AngularGradient(
                            colors: [strokeColor.opacity(0.6), strokeColor],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: trackWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: strokeColor.opacity(0.35), radius: 12)
                    .animation(
                        completionFlash
                            ? .spring(response: 0.55, dampingFraction: 0.72)
                            : .linear(duration: 0.8),
                        value: trimTo
                    )
                    .animation(Anim.appear, value: completionFlash)
            }

            // Center content
            VStack(spacing: Space.xs) {
                Text(formatCountdown(timeRemaining))
                    .font(.system(size: 54, weight: .bold, design: .monospaced))
                    .tracking(-2)
                    .contentTransition(.numericText())
                    .animation(Anim.count, value: timeRemaining)
                    .foregroundStyle(Color.primary)

                Text(modeLabel.uppercased())
                    .font(TypeScale.caption)
                    .foregroundStyle(mode == .idle
                        ? Color.secondary.opacity(0.4)
                        : ringColor.opacity(0.85))
                    .tracking(2.5)
                    .animation(Anim.quick, value: mode)

                // Focus % badge — only shown during focus
                if mode == .focus {
                    focusBadge
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(formatCountdown(timeRemaining))
    }

    @ViewBuilder
    private var focusBadge: some View {
        let pct = focusPercent
        let badgeColor: Color = pct >= 80 ? Color.productive : pct >= 50 ? Color.streak : Color.distraction
        Text("\(pct)% focus")
            .font(TypeScale.tiny)
            .fontWeight(.semibold)
            .foregroundStyle(badgeColor)
            .padding(.horizontal, Space.xs)
            .padding(.vertical, Space.xxxs)
            .background(
                Capsule()
                    .fill(badgeColor.opacity(0.12))
                    .overlay(Capsule().strokeBorder(badgeColor.opacity(0.25), lineWidth: 0.5))
            )
            .contentTransition(.numericText())
            .animation(Anim.count, value: pct)
    }

    private var accessibilityLabel: String {
        "\(modeLabel) timer. \(timeRemaining / 60) minutes and \(timeRemaining % 60) seconds remaining"
    }

    private func formatCountdown(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Hero Controls

private struct HeroControls: View {
    let mode: StudyViewModel.StudyMode
    let onStart: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void

    var body: some View {
        Group {
            if mode == .idle {
                startButton
            } else {
                activeControls
            }
        }
        .animation(Anim.tap, value: mode)
    }

    // Large 64×64 primary play circle
    @ViewBuilder
    private var startButton: some View {
        VStack(spacing: Space.md) {
            Button(action: onStart) {
                ZStack {
                    Circle()
                        .fill(Color.accent)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.accent.opacity(0.40), radius: 14, y: 4)
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 2) // optical alignment for play icon
                }
            }
            .buttonStyle(DriftButtonStyle(variant: .primary))
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("Start focus session")
            .accessibilityHint("Press Space to start")

            Text("Press Space or click to start")
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    @ViewBuilder
    private var activeControls: some View {
        HStack(spacing: Space.xxl) {
            // Stop — secondary ghost circle
            Button(action: onStop) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .overlay(Circle().strokeBorder(Color.sep.opacity(0.15), lineWidth: 0.5))
                        .frame(width: 48, height: 48)
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(DriftButtonStyle(variant: .ghost))
            .accessibilityLabel("Stop session")
            .transition(.opacity.combined(with: .scale(scale: 0.9)))

            // Primary skip / advance — large filled circle
            Button(action: onSkip) {
                ZStack {
                    Circle()
                        .fill(mode == .focus ? Color.productive : Color.accent)
                        .frame(width: 64, height: 64)
                        .shadow(
                            color: (mode == .focus ? Color.productive : Color.accent).opacity(0.38),
                            radius: 14, y: 4
                        )
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(DriftButtonStyle(variant: .primary))
            .accessibilityLabel(mode == .focus ? "Skip to break" : "Skip break, start focus")
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }
}

// MARK: - Session Stats Metric Chip

private struct StatMetricChip: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Space.xs) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color.opacity(0.75))
                .accessibilityHidden(true)

            MetricPair(
                value: value,
                label: label,
                valueFont: TypeScale.monoMd,
                color: Color.primary,
                alignment: .center
            )
        }
        .frame(maxWidth: .infinity)
        .insetCard(padding: Space.md, radius: Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Completion Overlay

private struct CompletionOverlay: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Color.productive)
                .scaleEffect(appeared ? 1 : 0.5)
                .animation(Anim.appear, value: appeared)

            Text("Session Complete")
                .font(TypeScale.h2)
                .foregroundStyle(Color.primary)
                .opacity(appeared ? 1 : 0)
                .animation(Anim.appear.delay(0.1), value: appeared)

            Text("Great work. Take a well-earned break.")
                .font(TypeScale.body)
                .foregroundStyle(.secondary)
                .opacity(appeared ? 1 : 0)
                .animation(Anim.appear.delay(0.18), value: appeared)
        }
        .padding(Space.xxxl)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color(.controlBackgroundColor).opacity(0.95))
                .shadow(color: Color.productive.opacity(0.18), radius: 28, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .strokeBorder(Color.productive.opacity(0.20), lineWidth: 0.5)
                )
        )
        .onAppear { appeared = true }
    }
}

// MARK: - Blocked Banner

private struct BlockedBanner: View {
    @Binding var isVisible: Bool
    let site: String?

    var body: some View {
        if isVisible, let site {
            HStack(spacing: Space.md) {
                Image(systemName: "shield.checkered")
                    .font(TypeScale.heading)
                    .foregroundStyle(.white)
                Text("\(site) was blocked")
                    .font(TypeScale.heading)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(Anim.quick) { isVisible = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.distraction)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(site) was blocked")
        }
    }
}

// MARK: - Subject Input

private struct SubjectInput: View {
    @Binding var subject: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: "pencil.line")
                .font(TypeScale.body)
                .foregroundStyle(isFocused ? Color.accent.opacity(0.6) : Color.primary.opacity(0.28))
                .animation(Anim.quick, value: isFocused)
            TextField("What are you working on?", text: $subject)
                .textFieldStyle(.plain)
                .font(TypeScale.body)
                .focused($isFocused)
                .accessibilityLabel("Focus subject")
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(
                            isFocused ? Color.accent.opacity(0.25) : Color.sep.opacity(0.12),
                            lineWidth: isFocused ? 1 : 0.5
                        )
                )
        )
        .animation(Anim.quick, value: isFocused)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Duration Config

private struct DurationConfig: View {
    @Binding var focusDuration: Int
    @Binding var breakDuration: Int

    var body: some View {
        VStack(spacing: Space.md) {
            DurationChipRow(
                icon: "brain.head.profile",
                label: "Focus",
                selection: $focusDuration,
                options: [15, 25, 30, 45, 60]
            )
            Divider().opacity(0.25)
            DurationChipRow(
                icon: "cup.and.saucer",
                label: "Break",
                selection: $breakDuration,
                options: [3, 5, 10, 15]
            )
        }
        .padding(Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.sep.opacity(0.10), lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Duration settings")
    }
}

private struct DurationChipRow: View {
    let icon: String
    let label: String
    @Binding var selection: Int
    let options: [Int]

    var body: some View {
        HStack(spacing: Space.md) {
            HStack(spacing: Space.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text(label)
                    .font(TypeScale.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52, alignment: .leading)

            HStack(spacing: Space.xs) {
                ForEach(options, id: \.self) { opt in
                    Button {
                        withAnimation(Anim.tap) { selection = opt }
                    } label: {
                        Text("\(opt)m")
                            .font(.system(size: 12, weight: selection == opt ? .semibold : .regular))
                            .foregroundStyle(selection == opt ? Color.accent : Color.secondary)
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, Space.xs)
                            .background(
                                Capsule()
                                    .fill(selection == opt
                                          ? Color.accent.opacity(0.12)
                                          : Color.primary.opacity(0.05))
                                    .animation(Anim.quick, value: selection == opt)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(opt) minute \(label.lowercased())")
                }
                Spacer()
            }
        }
    }
}

// MARK: - Focus Blocker Section

private struct FocusBlockerSection: View {
    @ObservedObject var blocker: FocusBlocker
    @State private var showSetup = false
    @State private var blockerDuration: Int = 30
    @State private var blockerPassword: String = ""
    @State private var blockerPasswordConfirm: String = ""
    @State private var showStopDialog = false
    @State private var stopPassword: String = ""
    @State private var stopPasswordError = false
    @State private var showBlockerStopConfirmation = false
    @State private var tickCancellable: AnyCancellable?

    var body: some View {
        VStack(spacing: Space.xl) {
            blockerHeader

            if blocker.isBlocking {
                activeBlockingContent
            } else {
                idleBlockerContent
            }
        }
        .padding(Space.xl)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 12, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.sep.opacity(0.10), lineWidth: 0.5)
                )
        )
        .onAppear { startTick() }
        .onDisappear { tickCancellable?.cancel() }
        .animation(Anim.appear, value: blocker.isBlocking)
        .animation(Anim.appear, value: showSetup)
    }

    @ViewBuilder
    private var blockerHeader: some View {
        HStack(alignment: .center, spacing: Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(blocker.isBlocking
                          ? Color.distraction.opacity(0.10)
                          : Color.accent.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: "shield.checkered")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(blocker.isBlocking ? Color.distraction : Color.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Blocker")
                    .font(.system(size: 15, weight: .semibold))
                Text(blocker.isBlocking
                     ? "Blocking \(blocker.blockedSites.count) sites"
                     : "Block distracting sites")
                    .font(TypeScale.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if blocker.isBlocking {
                HStack(spacing: Space.xxs) {
                    Circle()
                        .fill(Color.distraction)
                        .frame(width: 6, height: 6)
                    Text("Active")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.distraction)
                }
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xxs)
                .background(Capsule().fill(Color.distraction.opacity(0.10)))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus Blocker. \(blocker.isBlocking ? "Currently blocking sites" : "Inactive")")
    }

    // MARK: - Active Blocking

    @ViewBuilder
    private var activeBlockingContent: some View {
        VStack(spacing: Space.lg) {
            BlockerCountdown(blocker: blocker)

            if blocker.blockedAttempts > 0 {
                HStack(spacing: Space.sm) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.distraction.opacity(0.7))
                    Text("\(blocker.blockedAttempts) attempt\(blocker.blockedAttempts == 1 ? "" : "s") blocked")
                        .font(TypeScale.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.distraction)
                    Spacer()
                    if let last = blocker.lastBlockedSite {
                        Text(last)
                            .font(TypeScale.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.distraction.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(Color.distraction.opacity(0.10), lineWidth: 0.5)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showStopDialog {
                StopPasswordView(
                    blocker: blocker,
                    password: $stopPassword,
                    passwordError: $stopPasswordError,
                    showDialog: $showStopDialog
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Button {
                    if blocker.passwordRequired {
                        showStopDialog = true
                    } else {
                        showBlockerStopConfirmation = true
                    }
                } label: {
                    HStack(spacing: Space.sm) {
                        Image(systemName: blocker.passwordRequired ? "lock.fill" : "stop.fill")
                            .font(.system(size: 12))
                        Text("Stop Blocking")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .strokeBorder(Color.distraction.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                    .foregroundStyle(Color.distraction)
                }
                .driftButton(.danger)
                .alert("Stop Blocking?", isPresented: $showBlockerStopConfirmation) {
                    Button("Keep Blocking", role: .cancel) {}
                    Button("Stop", role: .destructive) { let _ = blocker.stopBlocking(password: nil) }
                } message: {
                    Text("Distracting sites will become accessible again.")
                }
                .accessibilityLabel("Stop blocking early")
            }
        }
    }

    // MARK: - Idle Blocker

    @ViewBuilder
    private var idleBlockerContent: some View {
        VStack(spacing: Space.lg) {
            BlockedSitesList(
                blocker: blocker,
                newSite: .constant("")
            )

            if showSetup {
                blockerSetupPanel
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Button {
                    withAnimation(Anim.appear) { showSetup = true }
                } label: {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Start Focus Block")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Color.accent.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .strokeBorder(Color.accent.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                    .foregroundStyle(Color.accent)
                }
                .driftButton(.secondary)
                .accessibilityLabel("Set up focus blocker")
            }
        }
    }

    @ViewBuilder
    private var blockerSetupPanel: some View {
        VStack(spacing: Space.lg) {
            HStack {
                HStack(spacing: Space.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text("Duration")
                        .font(TypeScale.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $blockerDuration) {
                    Text("30 min").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("3 hours").tag(180)
                    Text("4 hours").tag(240)
                }
                .pickerStyle(.menu)
                .frame(width: 110)
                .accessibilityLabel("Blocking duration")
            }

            Divider().opacity(0.25)

            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "lock")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        Text("Lock Password")
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Optional")
                        .font(TypeScale.tiny)
                        .foregroundStyle(.quaternary)
                }

                SecureField("Set a password to prevent early stop", text: $blockerPassword)
                    .textFieldStyle(.plain)
                    .font(TypeScale.caption)
                    .padding(Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .strokeBorder(Color.sep.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                    .accessibilityLabel("Set lock password")

                if !blockerPassword.isEmpty {
                    SecureField("Confirm password", text: $blockerPasswordConfirm)
                        .textFieldStyle(.plain)
                        .font(TypeScale.caption)
                        .padding(Space.md)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                        .strokeBorder(
                                            passwordsMatch ? Color.sep.opacity(0.15) : Color.distraction.opacity(0.2),
                                            lineWidth: 0.5
                                        )
                                )
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityLabel("Confirm lock password")

                    if !blockerPasswordConfirm.isEmpty && !passwordsMatch {
                        Text("Passwords do not match")
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.distraction)
                            .transition(.opacity)
                    }
                }
            }

            HStack(spacing: Space.md) {
                Button {
                    withAnimation(Anim.quick) {
                        showSetup = false
                        blockerPassword = ""
                        blockerPasswordConfirm = ""
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, Space.xl)
                        .padding(.vertical, Space.md)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                        .strokeBorder(Color.sep.opacity(0.15), lineWidth: 0.5)
                                )
                        )
                        .foregroundStyle(.secondary)
                }
                .driftButton(.ghost)
                .accessibilityLabel("Cancel setup")

                Button(action: startBlocker) {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 13))
                        Text("Start Blocking")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(canStart ? Color.accent : Color.accent.opacity(0.4))
                    )
                    .foregroundStyle(.white)
                }
                .driftButton()
                .disabled(!canStart)
                .accessibilityLabel("Start blocking")
            }
        }
        .padding(Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.sep.opacity(0.10), lineWidth: 0.5)
                )
        )
    }

    private var passwordsMatch: Bool { blockerPassword == blockerPasswordConfirm }
    private var canStart: Bool { blockerPassword.isEmpty || (passwordsMatch && !blockerPasswordConfirm.isEmpty) }

    private func startBlocker() {
        let pw = blockerPassword.isEmpty ? nil : blockerPassword
        blocker.startBlocking(durationMinutes: blockerDuration, password: pw)
        withAnimation(Anim.quick) {
            showSetup = false
            blockerPassword = ""
            blockerPasswordConfirm = ""
        }
    }

    private func startTick() {
        tickCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in blocker.objectWillChange.send() }
    }
}

// MARK: - Blocker Countdown

private struct BlockerCountdown: View {
    @ObservedObject var blocker: FocusBlocker

    var body: some View {
        HStack(spacing: Space.xl) {
            ZStack {
                Circle()
                    .stroke(Color.sep.opacity(0.12), lineWidth: 6)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: min(blocker.progress, 1.0))
                    .stroke(
                        Color.distraction,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: blocker.progress)
                VStack(spacing: 2) {
                    Text(blocker.timeRemainingFormatted)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())
                        .animation(Anim.count, value: blocker.timeRemainingFormatted)
                    Text("left")
                        .font(TypeScale.tiny)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Blocking timer: \(blocker.timeRemainingFormatted) remaining")

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Protecting your focus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Distracting sites are blocked.\nStay in the zone.")
                    .font(TypeScale.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.distraction.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.distraction.opacity(0.10), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Stop Password View

private struct StopPasswordView: View {
    @ObservedObject var blocker: FocusBlocker
    @Binding var password: String
    @Binding var passwordError: Bool
    @Binding var showDialog: Bool

    var body: some View {
        VStack(spacing: Space.md) {
            HStack(spacing: Space.sm) {
                Image(systemName: "lock.fill")
                    .font(TypeScale.body)
                    .foregroundStyle(Color.distraction)
                Text("Enter password to stop blocking")
                    .font(TypeScale.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Space.md) {
                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .font(TypeScale.body)
                    .padding(Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .strokeBorder(
                                        passwordError ? Color.distraction.opacity(0.3) : Color.sep.opacity(0.15),
                                        lineWidth: 0.5
                                    )
                            )
                    )
                    .onSubmit { attemptStop() }
                    .accessibilityLabel("Blocking password")

                Button(action: attemptStop) {
                    Text("Unlock")
                        .font(TypeScale.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, Space.lg)
                        .padding(.vertical, Space.md)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(Color.distraction)
                        )
                        .foregroundStyle(.white)
                }
                .driftButton(.danger)
                .accessibilityLabel("Unlock and stop blocking")

                Button {
                    showDialog = false
                    password = ""
                    passwordError = false
                } label: {
                    Text("Cancel")
                        .font(TypeScale.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.md)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                        .foregroundStyle(.secondary)
                }
                .driftButton(.ghost)
                .accessibilityLabel("Cancel")
            }

            if passwordError {
                Text("Incorrect password")
                    .font(TypeScale.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.distraction)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.distraction.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.distraction.opacity(0.10), lineWidth: 0.5)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func attemptStop() {
        if blocker.stopBlocking(password: password) {
            withAnimation(Anim.quick) { showDialog = false; password = ""; passwordError = false }
        } else {
            withAnimation(Anim.quick) { passwordError = true }
        }
    }
}

// MARK: - Blocked Sites List

private struct BlockedSitesList: View {
    @ObservedObject var blocker: FocusBlocker
    @Binding var newSite: String
    @State private var showList = false
    @State private var localNewSite: String = ""

    var body: some View {
        VStack(spacing: Space.md) {
            Button {
                withAnimation(Anim.tap) { showList.toggle() }
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Text("Blocked Sites")
                        .font(TypeScale.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(blocker.blockedSites.count)")
                        .font(TypeScale.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(showList ? 90 : 0))
                        .animation(Anim.quick, value: showList)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Blocked sites: \(blocker.blockedSites.count)")
            .accessibilityHint("Activate to \(showList ? "collapse" : "expand")")

            if showList {
                VStack(spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.accent.opacity(0.6))
                        TextField("Add domain (e.g. reddit.com)", text: $localNewSite)
                            .textFieldStyle(.plain)
                            .font(TypeScale.caption)
                            .onSubmit { addSite() }
                            .accessibilityLabel("Add blocked domain")
                        Button(action: addSite) {
                            Text("Add")
                                .font(TypeScale.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, Space.md)
                                .padding(.vertical, Space.xxs)
                                .background(Capsule().fill(Color.accent))
                                .foregroundStyle(.white)
                        }
                        .driftButton()
                        .disabled(localNewSite.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(localNewSite.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                        .accessibilityLabel("Add site")
                    }
                    .padding(Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .strokeBorder(Color.sep.opacity(0.12), lineWidth: 0.5)
                            )
                    )

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: Space.sm),
                        GridItem(.flexible(), spacing: Space.sm),
                    ], spacing: Space.sm) {
                        ForEach(blocker.blockedSites, id: \.self) { site in
                            BlockedSiteChip(site: site) {
                                withAnimation(Anim.quick) { blocker.removeSite(site) }
                            }
                        }
                    }

                    Button {
                        withAnimation(Anim.quick) { blocker.resetToDefaults() }
                    } label: {
                        HStack(spacing: Space.xs) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text("Reset to defaults")
                                .font(TypeScale.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.tertiary)
                    }
                    .driftButton(.ghost)
                    .accessibilityLabel("Reset to default blocked sites")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Space.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.sep.opacity(0.10), lineWidth: 0.5)
                )
        )
    }

    private func addSite() {
        let site = localNewSite.trimmingCharacters(in: .whitespaces)
        guard !site.isEmpty else { return }
        withAnimation(Anim.quick) { blocker.addSite(site); localNewSite = "" }
    }
}

// MARK: - Blocked Site Chip

struct BlockedSiteChip: View {
    let site: String
    let onRemove: () -> Void
    @State private var isHovered = false
    @State private var removeHovered = false

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "globe")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(site)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Space.xxs)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(removeHovered ? Color.distraction : Color.secondary.opacity(0.5))
                    .frame(width: 16, height: 16)
                    .background(
                        Circle().fill(
                            removeHovered
                                ? Color.distraction.opacity(0.10)
                                : Color.primary.opacity(0.04)
                        )
                    )
            }
            .buttonStyle(.plain)
            .onHover { h in removeHovered = h }
            .accessibilityLabel("Remove \(site)")
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(Color.sep.opacity(isHovered ? 0.15 : 0.08), lineWidth: 0.5)
                )
        )
        .onHover { h in withAnimation(Anim.quick) { isHovered = h } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Blocked: \(site)")
    }
}

// MARK: - Helpers

private func formatStudyTime(_ totalSeconds: Int) -> String {
    if totalSeconds < 60 { return "\(totalSeconds)s" }
    let m = totalSeconds / 60
    if m < 60 { return "\(m)m" }
    return "\(m / 60)h \(m % 60)m"
}
