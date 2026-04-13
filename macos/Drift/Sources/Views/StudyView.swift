import SwiftUI
import UserNotifications
import ApplicationServices
import Combine

// MARK: - Study View (Main Orchestrator)

struct StudyView: View {
    @StateObject private var viewModel = StudyViewModel()
    @StateObject private var blocker = FocusBlocker.shared
    @Namespace private var timerNamespace

    var body: some View {
        ZStack {
            // Subtle ambient background -- barely noticeable, never distracting
            AmbientBackground(mode: viewModel.mode, progress: viewModel.progress)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.xxl) {
                    // Blocked-site banner
                    BlockedBanner(
                        isVisible: $viewModel.showBlockedBanner,
                        site: blocker.lastBlockedSite
                    )

                    // Header with mode pill
                    StudyHeader(mode: viewModel.mode, modeLabel: viewModel.modeLabel)

                    // Timer ring -- clean, simple strokes
                    TimerRingView(
                        timeRemaining: viewModel.timeRemaining,
                        progress: viewModel.progress,
                        mode: viewModel.mode,
                        modeLabel: viewModel.modeLabel,
                        ringColor: viewModel.ringColor
                    )
                    .padding(.vertical, Space.sm)

                    // Subject input
                    SubjectInput(
                        subject: $viewModel.subject,
                        isDisabled: viewModel.mode != .idle
                    )

                    // Timer controls -- big play/pause, small skip/stop
                    TimerControls(
                        mode: viewModel.mode,
                        onStart: viewModel.startFocus,
                        onStop: { viewModel.showStopConfirmation = true },
                        onSkip: viewModel.skipPhase
                    )
                    .alert("End Focus Session?", isPresented: $viewModel.showStopConfirmation) {
                        Button("Keep Going", role: .cancel) { }
                        Button("End Session", role: .destructive) { viewModel.stopStudy() }
                    } message: {
                        Text("You still have time left. Ending early means losing your focus streak.")
                    }

                    // Duration configuration
                    DurationConfig(
                        focusDuration: $viewModel.focusDuration,
                        breakDuration: $viewModel.breakDuration,
                        isDisabled: viewModel.mode != .idle
                    )

                    // Focus session stats
                    FocusStatsView(
                        sessionCount: viewModel.sessionCount,
                        totalFocusTime: viewModel.totalFocusTime
                    )

                    // Separator
                    Rectangle()
                        .fill(Color.sep.opacity(0.15))
                        .frame(height: 1)
                        .padding(.vertical, Space.xxs)

                    // Focus Blocker section -- native panel style
                    FocusBlockerSection(blocker: blocker)
                }
                .padding(Space.page)
            }
        }
        .onChange(of: viewModel.focusDuration) { _, newValue in
            if viewModel.mode == .idle { viewModel.timeRemaining = newValue * 60 }
        }
        .onChange(of: blocker.blockedAttempts) { _, newValue in
            guard newValue > 0 else { return }
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
        .onKeyPress("s", modifiers: .command) {
            if viewModel.mode != .idle { viewModel.skipPhase() }
            return .handled
        }
        .onKeyPress(.escape) {
            if viewModel.mode != .idle { viewModel.showStopConfirmation = true }
            return .handled
        }
    }
}

// MARK: - Study View Model

@MainActor
final class StudyViewModel: ObservableObject {
    enum StudyMode: Equatable { case idle, focus, rest }

    // Timer state
    @Published var mode: StudyMode = .idle
    @Published var timeRemaining: Int = 25 * 60
    @Published var totalFocusTime: Int = 0
    @Published var sessionCount: Int = 0
    @Published var subject: String = ""
    @Published var focusDuration: Int = 25
    @Published var breakDuration: Int = 5

    // UI state
    @Published var showStopConfirmation = false
    @Published var showBlockedBanner = false

    // Timer management -- use Date-based tracking for accuracy across
    // background/foreground transitions instead of naive decrement.
    private var timerCancellable: AnyCancellable?
    private var phaseEndDate: Date?
    private var phaseTotalSeconds: Int = 0

    // VoiceOver periodic announcement interval (seconds)
    private var lastAnnouncedMinute: Int = -1

    // Computed
    var progress: CGFloat {
        switch mode {
        case .idle: return 0
        case .focus: return 1 - CGFloat(timeRemaining) / CGFloat(focusDuration * 60)
        case .rest: return 1 - CGFloat(timeRemaining) / CGFloat(breakDuration * 60)
        }
    }

    var ringColor: Color {
        switch mode {
        case .idle, .focus: return .accent
        case .rest: return .productive
        }
    }

    var modeLabel: String {
        switch mode {
        case .idle: return "Ready"
        case .focus: return "Focus"
        case .rest: return "Break"
        }
    }

    // MARK: - Lifecycle

    func onAppear() {
        // No-op here; timer only starts on user action.
    }

    func onDisappear() {
        stopTimer()
    }

    // MARK: - Pomodoro Actions

    func startFocus() {
        mode = .focus
        phaseTotalSeconds = focusDuration * 60
        timeRemaining = phaseTotalSeconds
        phaseEndDate = Date().addingTimeInterval(TimeInterval(phaseTotalSeconds))

        // Ensure WindowTracker is running for focus mode detection
        if !WindowTracker.shared.isTracking && AXIsProcessTrusted() {
            WindowTracker.shared.start()
        }
        AppState.shared.focusModeActive = true

        // Auto-activate Focus Blocker when starting a focus session
        let blocker = FocusBlocker.shared
        if !blocker.isBlocking {
            blocker.startBlocking(durationMinutes: focusDuration, password: nil)
        }

        startTimer()
    }

    func stopStudy() {
        stopTimer()
        if mode == .focus {
            totalFocusTime += (focusDuration * 60 - timeRemaining)
        }
        mode = .idle
        timeRemaining = focusDuration * 60
        phaseEndDate = nil
        AppState.shared.focusModeActive = false

        // Auto-stop Focus Blocker
        let blocker = FocusBlocker.shared
        if blocker.isBlocking {
            let _ = blocker.stopBlocking(password: nil)
        }
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
        if mode == .idle {
            startFocus()
        }
        // Timer auto-runs; space in active mode is a no-op
        // (could be extended to pause if desired).
    }

    private func startBreak() {
        mode = .rest
        phaseTotalSeconds = breakDuration * 60
        timeRemaining = phaseTotalSeconds
        phaseEndDate = Date().addingTimeInterval(TimeInterval(phaseTotalSeconds))
        startTimer()
        sendNotification(title: "Focus complete!", body: "Take a \(breakDuration)-minute break.")
    }

    // MARK: - Date-based Timer (survives background/foreground)

    private func startTimer() {
        stopTimer()
        lastAnnouncedMinute = -1

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func tick() {
        guard let endDate = phaseEndDate else { return }
        let remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        timeRemaining = remaining

        // VoiceOver: announce every 5 minutes, at 1 minute, and at 10 seconds
        announceTimeIfNeeded(remaining)

        guard remaining <= 0 else { return }
        stopTimer()

        if mode == .focus {
            sessionCount += 1
            totalFocusTime += phaseTotalSeconds
            startBreak()
        } else {
            sendNotification(title: "Break over!", body: "Time to focus again.")
            startFocus()
        }
    }

    // MARK: - Accessibility Announcements

    private func announceTimeIfNeeded(_ seconds: Int) {
        let currentMinute = seconds / 60
        let shouldAnnounce: Bool

        if seconds == 10 {
            shouldAnnounce = true
        } else if seconds == 60 {
            shouldAnnounce = true
        } else if currentMinute > 0 && currentMinute % 5 == 0 && seconds % 60 == 0 && currentMinute != lastAnnouncedMinute {
            shouldAnnounce = true
        } else {
            shouldAnnounce = false
        }

        guard shouldAnnounce else { return }
        lastAnnouncedMinute = currentMinute

        let label: String
        if seconds < 60 {
            label = "\(seconds) seconds remaining"
        } else {
            label = "\(currentMinute) minute\(currentMinute == 1 ? "" : "s") remaining"
        }
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                NSAccessibility.NotificationUserInfoKey.announcement: label,
                NSAccessibility.NotificationUserInfoKey.priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }

    // MARK: - Notifications

    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}

// MARK: - Ambient Background
// Barely-noticeable glow. No psychedelic gradients, no breathing animation.

private struct AmbientBackground: View {
    let mode: StudyViewModel.StudyMode
    let progress: CGFloat

    private var baseColor: Color {
        switch mode {
        case .idle: return .clear
        case .focus: return .accent
        case .rest: return .productive
        }
    }

    var body: some View {
        ZStack {
            Color("Background")

            if mode != .idle {
                // Single very subtle radial wash -- static, no animation
                RadialGradient(
                    colors: [baseColor.opacity(0.04), .clear],
                    center: .center,
                    startRadius: 60,
                    endRadius: 400
                )
                .ignoresSafeArea()
            }
        }
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
                Text("\(site) was blocked!")
                    .font(TypeScale.heading)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(Anim.quick) { isVisible = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss blocked site banner")
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.distraction)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(site) was blocked")
        }
    }
}

// MARK: - Study Header

private struct StudyHeader: View {
    let mode: StudyViewModel.StudyMode
    let modeLabel: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("Focus Timer")
                    .font(TypeScale.hero)
                    .tracking(-0.5)
                Text("Pomodoro-style deep work sessions")
                    .font(TypeScale.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if mode != .idle {
                ModePill(mode: mode, label: modeLabel)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(Anim.appear, value: mode)
    }
}

// MARK: - Mode Pill

private struct ModePill: View {
    let mode: StudyViewModel.StudyMode
    let label: String

    private var pillColor: Color {
        mode == .focus ? .accent : .productive
    }

    var body: some View {
        HStack(spacing: Space.xs) {
            Circle()
                .fill(pillColor)
                .frame(width: 7, height: 7)
            Text(label)
                .font(TypeScale.caption)
                .fontWeight(.semibold)
                .foregroundStyle(pillColor)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs)
        .background(Capsule().fill(pillColor.opacity(0.1)))
        .accessibilityLabel("Current mode: \(label)")
    }
}

// MARK: - Timer Ring View
// Clean, simple strokes. No breathing glow -- the UI should be CALM during focus.

private struct TimerRingView: View {
    let timeRemaining: Int
    let progress: CGFloat
    let mode: StudyViewModel.StudyMode
    let modeLabel: String
    let ringColor: Color

    var body: some View {
        ZStack {
            // Outer track
            Circle()
                .stroke(Color.sep.opacity(0.2), lineWidth: 6)
                .frame(width: 220, height: 220)

            // Progress ring -- simple solid stroke, no angular gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.8), value: progress)

            // Center content
            VStack(spacing: Space.xs) {
                Text(formatCountdown(timeRemaining))
                    .font(TypeScale.mono)
                    .tracking(-2)
                    .contentTransition(.numericText())
                    .animation(Anim.count, value: timeRemaining)

                Text(modeLabel)
                    .font(TypeScale.heading)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timerAccessibilityLabel)
        .accessibilityValue(formatCountdown(timeRemaining))
    }

    private var timerAccessibilityLabel: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return "\(modeLabel) timer. \(minutes) minutes and \(seconds) seconds remaining"
    }

    private func formatCountdown(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Subject Input

private struct SubjectInput: View {
    @Binding var subject: String
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: "pencil.line")
                .font(TypeScale.body)
                .foregroundStyle(.tertiary)
            TextField("What are you working on?", text: $subject)
                .textFieldStyle(.plain)
                .font(TypeScale.body)
                .accessibilityLabel("Focus subject")
                .accessibilityHint("Enter what you are working on")
        }
        .padding(Space.lg)
        .driftCard(padding: 0)
        .padding(0) // card provides its own visual; inner padding above is sufficient
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .animation(Anim.quick, value: isDisabled)
    }
}

// MARK: - Timer Controls
// Big play/pause, small skip/stop. Dead simple.

private struct TimerControls: View {
    let mode: StudyViewModel.StudyMode
    let onStart: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: Space.md) {
            if mode == .idle {
                startButton
            } else {
                // Big play/pause (skip forward) is the primary action
                skipButton
                // Small stop is secondary
                stopButton
            }
        }
        .animation(Anim.tap, value: mode)
    }

    private var startButton: some View {
        Button(action: onStart) {
            HStack(spacing: Space.sm) {
                Image(systemName: "play.fill")
                    .font(TypeScale.heading)
                Text("Start Focus")
                    .font(TypeScale.heading)
            }
            .padding(.horizontal, Space.xxxl)
            .padding(.vertical, Space.md)
            .background(Capsule().fill(Color.accent))
            .foregroundStyle(.white)
        }
        .driftButton()
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .accessibilityLabel("Start focus session")
        .accessibilityHint("Press Space to start")
    }

    private var stopButton: some View {
        Button(action: onStop) {
            HStack(spacing: Space.xs) {
                Image(systemName: "stop.fill")
                    .font(TypeScale.caption)
                Text("Stop")
                    .font(TypeScale.body)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(Color.sep.opacity(0.15), lineWidth: 0.5))
            )
            .foregroundStyle(.secondary)
        }
        .driftButton(.ghost)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .accessibilityLabel("Stop session")
        .accessibilityHint("Press Escape to stop")
    }

    private var skipButton: some View {
        Button(action: onSkip) {
            HStack(spacing: Space.xs) {
                Image(systemName: "forward.fill")
                    .font(TypeScale.heading)
                Text(mode == .focus ? "Skip to Break" : "Skip Break")
                    .font(TypeScale.heading)
            }
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.md)
            .background(Capsule().fill(Color.accent))
            .foregroundStyle(.white)
        }
        .driftButton()
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .accessibilityLabel(mode == .focus ? "Skip to break" : "Skip break")
        .accessibilityHint("Command S to skip")
    }
}

// MARK: - Duration Configuration

private struct DurationConfig: View {
    @Binding var focusDuration: Int
    @Binding var breakDuration: Int
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: Space.xxl) {
            DurationPicker(
                icon: "brain.head.profile",
                label: "Focus",
                selection: $focusDuration,
                options: [15, 25, 30, 45, 60],
                suffix: "m"
            )

            DurationPicker(
                icon: "cup.and.saucer",
                label: "Break",
                selection: $breakDuration,
                options: [3, 5, 10, 15],
                suffix: "m"
            )
        }
        .driftCard(padding: Space.lg)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .animation(Anim.quick, value: isDisabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Duration settings")
    }
}

private struct DurationPicker: View {
    let icon: String
    let label: String
    @Binding var selection: Int
    let options: [Int]
    let suffix: String

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)
            Text(label)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { value in
                    Text("\(value)\(suffix)").tag(value)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 64)
            .accessibilityLabel("\(label) duration")
        }
    }
}

// MARK: - Focus Stats View

private struct FocusStatsView: View {
    let sessionCount: Int
    let totalFocusTime: Int

    var body: some View {
        HStack(spacing: 0) {
            StatItem(
                icon: "checkmark.circle",
                iconColor: Color.accent.opacity(0.6),
                value: "\(sessionCount)",
                label: "Sessions"
            )

            Rectangle()
                .fill(Color.sep.opacity(0.3))
                .frame(width: 1, height: 36)

            StatItem(
                icon: "clock",
                iconColor: Color.productive.opacity(0.6),
                value: formatStudyTime(totalFocusTime),
                label: "Total Focus"
            )
        }
        .driftCard(padding: Space.lg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus statistics")
    }

    private func formatStudyTime(_ totalSeconds: Int) -> String {
        if totalSeconds < 60 { return "\(totalSeconds)s" }
        let m = totalSeconds / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        return "\(h)h \(m % 60)m"
    }
}

private struct StatItem: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Space.xs) {
            Image(systemName: icon)
                .font(TypeScale.caption)
                .foregroundStyle(iconColor)
            Text(value)
                .font(TypeScale.title)
                .fontDesign(.monospaced)
                .contentTransition(.numericText())
                .animation(Anim.count, value: value)
            Text(label)
                .font(TypeScale.tiny)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Focus Blocker Section
// Looks like a native panel, not a custom card.

private struct FocusBlockerSection: View {
    @ObservedObject var blocker: FocusBlocker

    // Blocker-specific UI state
    @State private var showBlockerSetup = false
    @State private var blockerDuration: Int = 30
    @State private var blockerPassword: String = ""
    @State private var blockerPasswordConfirm: String = ""
    @State private var showStopDialog = false
    @State private var stopPassword: String = ""
    @State private var stopPasswordError = false
    @State private var showBlockerStopConfirmation = false

    // Tick for countdown refresh
    @State private var tickCancellable: AnyCancellable?

    var body: some View {
        VStack(spacing: Space.xl) {
            // Header
            BlockerHeader(isBlocking: blocker.isBlocking)

            if blocker.isBlocking {
                ActiveBlockingView(
                    blocker: blocker,
                    showStopDialog: $showStopDialog,
                    stopPassword: $stopPassword,
                    stopPasswordError: $stopPasswordError,
                    showStopConfirmation: $showBlockerStopConfirmation
                )
            } else {
                BlockerSetupView(
                    blocker: blocker,
                    showSetup: $showBlockerSetup,
                    duration: $blockerDuration,
                    password: $blockerPassword,
                    passwordConfirm: $blockerPasswordConfirm
                )
            }
        }
        .onAppear { startTick() }
        .onDisappear { tickCancellable?.cancel() }
        .animation(Anim.appear, value: blocker.isBlocking)
    }

    private func startTick() {
        tickCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                // Triggers re-evaluation of blocker's computed properties
                blocker.objectWillChange.send()
            }
    }
}

// MARK: - Blocker Header

private struct BlockerHeader: View {
    let isBlocking: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.xxs) {
                HStack(spacing: Space.sm) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.accent)
                    Text("Focus Blocker")
                        .font(TypeScale.title)
                        .tracking(-0.3)
                }
                Text("Block distracting websites while you work")
                    .font(TypeScale.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if isBlocking {
                HStack(spacing: Space.xs) {
                    Circle()
                        .fill(Color.distraction)
                        .frame(width: 7, height: 7)
                    Text("Blocking")
                        .font(TypeScale.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.distraction)
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.xs)
                .background(Capsule().fill(Color.distraction.opacity(0.1)))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus Blocker. \(isBlocking ? "Currently blocking distracting sites" : "Not active")")
    }
}

// MARK: - Active Blocking View

private struct ActiveBlockingView: View {
    @ObservedObject var blocker: FocusBlocker
    @Binding var showStopDialog: Bool
    @Binding var stopPassword: String
    @Binding var stopPasswordError: Bool
    @Binding var showStopConfirmation: Bool

    @State private var blockedBounce = false

    var body: some View {
        VStack(spacing: Space.lg) {
            // Countdown card
            BlockerCountdown(blocker: blocker)

            // Stats row
            BlockerStats(
                blockedAttempts: blocker.blockedAttempts,
                siteCount: blocker.blockedSites.count,
                lastBlockedSite: blocker.lastBlockedSite,
                bounce: blockedBounce
            )
            .onChange(of: blocker.blockedAttempts) { _, _ in
                withAnimation(Anim.tap) { blockedBounce = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(Anim.tap) { blockedBounce = false }
                }
            }

            // Stop Early
            if showStopDialog {
                StopPasswordView(
                    blocker: blocker,
                    password: $stopPassword,
                    passwordError: $stopPasswordError,
                    showDialog: $showStopDialog
                )
            } else {
                Button {
                    if blocker.passwordRequired {
                        showStopDialog = true
                    } else {
                        showStopConfirmation = true
                    }
                } label: {
                    HStack(spacing: Space.sm) {
                        Image(systemName: blocker.passwordRequired ? "lock.fill" : "stop.fill")
                            .font(TypeScale.caption)
                        Text("Stop Early")
                            .font(TypeScale.body)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, Space.xxl)
                    .padding(.vertical, Space.md)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().strokeBorder(Color.distraction.opacity(0.12), lineWidth: 0.5))
                    )
                    .foregroundStyle(.distraction)
                }
                .driftButton(.danger)
                .alert("Stop Blocking?", isPresented: $showStopConfirmation) {
                    Button("Keep Blocking", role: .cancel) { }
                    Button("Stop Blocking", role: .destructive) {
                        let _ = blocker.stopBlocking(password: nil)
                    }
                } message: {
                    Text("Distracting sites will become accessible again. Are you sure?")
                }
                .accessibilityLabel("Stop blocking early")
            }
        }
    }
}

// MARK: - Blocker Countdown
// Clean ring, no breathing glow.

private struct BlockerCountdown: View {
    @ObservedObject var blocker: FocusBlocker

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.sep.opacity(0.2), lineWidth: 5)
                .frame(width: 140, height: 140)

            Circle()
                .trim(from: 0, to: min(blocker.progress, 1.0))
                .stroke(
                    Color.distraction,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: blocker.progress)

            VStack(spacing: Space.xxs) {
                Text(blocker.timeRemainingFormatted)
                    .font(TypeScale.mono)
                    .tracking(-1)
                    .contentTransition(.numericText())
                    .animation(Anim.count, value: blocker.timeRemainingFormatted)
                Text("remaining")
                    .sectionLabel()
            }
        }
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity)
        .driftCard(padding: Space.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Blocking timer: \(blocker.timeRemainingFormatted) remaining")
    }
}

// MARK: - Blocker Stats

private struct BlockerStats: View {
    let blockedAttempts: Int
    let siteCount: Int
    let lastBlockedSite: String?
    let bounce: Bool

    var body: some View {
        HStack(spacing: 0) {
            StatItem(
                icon: "hand.raised.fill",
                iconColor: Color.distraction.opacity(0.6),
                value: "\(blockedAttempts)",
                label: "Blocked"
            )
            .scaleEffect(bounce ? 1.05 : 1.0)

            Rectangle().fill(Color.sep.opacity(0.3)).frame(width: 1, height: 36)

            StatItem(
                icon: "globe",
                iconColor: Color.accent.opacity(0.6),
                value: "\(siteCount)",
                label: "Sites"
            )

            if let lastSite = lastBlockedSite {
                Rectangle().fill(Color.sep.opacity(0.3)).frame(width: 1, height: 36)

                VStack(spacing: Space.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(TypeScale.caption)
                        .foregroundStyle(.streak.opacity(0.6))
                    Text(lastSite)
                        .font(TypeScale.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text("Last Blocked")
                        .sectionLabel()
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last blocked site: \(lastSite)")
            }
        }
        .driftCard(padding: Space.lg)
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
                    .foregroundStyle(.distraction)
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
                            .fill(.ultraThinMaterial)
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
                        .background(Capsule().fill(Color.distraction))
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
                        .background(Capsule().fill(.ultraThinMaterial))
                        .foregroundStyle(.secondary)
                }
                .driftButton(.ghost)
                .accessibilityLabel("Cancel unlock")
            }

            if passwordError {
                Text("Incorrect password")
                    .font(TypeScale.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.distraction)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .driftCard(padding: Space.lg)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func attemptStop() {
        let success = blocker.stopBlocking(password: password)
        if success {
            withAnimation(Anim.quick) {
                showDialog = false
                password = ""
                passwordError = false
            }
        } else {
            withAnimation(Anim.quick) {
                passwordError = true
            }
        }
    }
}

// MARK: - Blocker Setup View

private struct BlockerSetupView: View {
    @ObservedObject var blocker: FocusBlocker
    @Binding var showSetup: Bool
    @Binding var duration: Int
    @Binding var password: String
    @Binding var passwordConfirm: String

    // Sites list
    @State private var showSitesList = false
    @State private var newBlockedSite: String = ""

    private var passwordsMatch: Bool {
        password == passwordConfirm
    }

    private var canStart: Bool {
        if password.isEmpty { return true }
        return passwordsMatch && !passwordConfirm.isEmpty
    }

    var body: some View {
        VStack(spacing: Space.lg) {
            // Blocked sites list (collapsible)
            BlockedSitesList(
                blocker: blocker,
                showList: $showSitesList,
                newSite: $newBlockedSite
            )

            if showSetup {
                setupPanel
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                startBlockButton
            }
        }
        .animation(Anim.tap, value: showSetup)
    }

    private var setupPanel: some View {
        VStack(spacing: Space.lg) {
            // Duration picker
            HStack(spacing: Space.md) {
                Image(systemName: "clock")
                    .font(TypeScale.body)
                    .foregroundStyle(.tertiary)
                Text("Duration")
                    .font(TypeScale.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $duration) {
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

            Divider().opacity(0.3)

            // Password (optional)
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(spacing: Space.sm) {
                    Image(systemName: "lock")
                        .font(TypeScale.body)
                        .foregroundStyle(.tertiary)
                    Text("Lock Password")
                        .font(TypeScale.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Optional")
                        .font(TypeScale.caption)
                        .foregroundStyle(.tertiary)
                }

                SecureField("Set a password to prevent early stop", text: $password)
                    .textFieldStyle(.plain)
                    .font(TypeScale.caption)
                    .padding(Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .strokeBorder(Color.sep.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                    .accessibilityLabel("Set lock password")

                if !password.isEmpty {
                    SecureField("Confirm password", text: $passwordConfirm)
                        .textFieldStyle(.plain)
                        .font(TypeScale.caption)
                        .padding(Space.md)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
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

                    if !passwordConfirm.isEmpty && !passwordsMatch {
                        Text("Passwords do not match")
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.distraction)
                            .transition(.opacity)
                    }
                }
            }

            // Start / Cancel buttons
            HStack(spacing: Space.md) {
                Button {
                    withAnimation(Anim.quick) {
                        showSetup = false
                        password = ""
                        passwordConfirm = ""
                    }
                } label: {
                    Text("Cancel")
                        .font(TypeScale.body)
                        .fontWeight(.medium)
                        .padding(.horizontal, Space.xl)
                        .padding(.vertical, Space.md)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(Capsule().strokeBorder(Color.sep.opacity(0.15), lineWidth: 0.5))
                        )
                        .foregroundStyle(.secondary)
                }
                .driftButton(.ghost)
                .accessibilityLabel("Cancel blocker setup")

                Button(action: startBlocker) {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "shield.checkered")
                            .font(TypeScale.body)
                        Text("Start Blocking")
                            .font(TypeScale.body)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, Space.xxl)
                    .padding(.vertical, Space.md)
                    .background(Capsule().fill(Color.accent))
                    .foregroundStyle(.white)
                }
                .driftButton()
                .disabled(!canStart)
                .opacity(canStart ? 1 : 0.5)
                .accessibilityLabel("Start blocking distracting sites")
            }
            .padding(.top, Space.xxs)
        }
        .driftCard(padding: Space.lg)
    }

    private var startBlockButton: some View {
        Button {
            withAnimation(Anim.quick) { showSetup = true }
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "shield.checkered")
                    .font(TypeScale.heading)
                Text("Start Focus Block")
                    .font(TypeScale.heading)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(Color.accent.opacity(0.12), lineWidth: 0.5)
                    )
            )
            .foregroundStyle(.accent)
        }
        .driftButton(.secondary)
        .accessibilityLabel("Set up focus blocker")
    }

    private func startBlocker() {
        let pw = password.isEmpty ? nil : password
        blocker.startBlocking(durationMinutes: duration, password: pw)

        withAnimation(Anim.quick) {
            showSetup = false
            password = ""
            passwordConfirm = ""
        }
    }
}

// MARK: - Blocked Sites List

private struct BlockedSitesList: View {
    @ObservedObject var blocker: FocusBlocker
    @Binding var showList: Bool
    @Binding var newSite: String

    var body: some View {
        VStack(spacing: Space.md) {
            Button {
                withAnimation(Anim.quick) { showList.toggle() }
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .font(TypeScale.body)
                        .foregroundStyle(.tertiary)
                    Text("Blocked Sites")
                        .font(TypeScale.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(blocker.blockedSites.count) sites")
                        .font(TypeScale.caption)
                        .foregroundStyle(.tertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showList ? 90 : 0))
                        .animation(Anim.quick, value: showList)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Blocked sites: \(blocker.blockedSites.count) sites")
            .accessibilityHint("Activate to \(showList ? "collapse" : "expand") the list")

            if showList {
                VStack(spacing: Space.sm) {
                    // Add new site
                    HStack(spacing: Space.sm) {
                        Image(systemName: "plus.circle")
                            .font(TypeScale.body)
                            .foregroundStyle(.accent.opacity(0.6))
                        TextField("Add domain (e.g. example.com)", text: $newSite)
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
                        .disabled(newSite.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(newSite.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                        .accessibilityLabel("Add site to block list")
                    }
                    .padding(Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .strokeBorder(Color.sep.opacity(0.15), lineWidth: 0.5)
                            )
                    )

                    // Sites grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: Space.sm),
                        GridItem(.flexible(), spacing: Space.sm),
                    ], spacing: Space.sm) {
                        ForEach(blocker.blockedSites, id: \.self) { site in
                            BlockedSiteChip(site: site) {
                                withAnimation(Anim.quick) {
                                    blocker.removeSite(site)
                                }
                            }
                        }
                    }

                    // Reset to defaults
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
                    .padding(.top, Space.xxs)
                    .accessibilityLabel("Reset blocked sites to defaults")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .driftCard(padding: Space.lg)
    }

    private func addSite() {
        let site = newSite.trimmingCharacters(in: .whitespaces)
        guard !site.isEmpty else { return }
        withAnimation(Anim.quick) {
            blocker.addSite(site)
            newSite = ""
        }
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
                    .foregroundStyle(removeHovered ? .distraction : Color.secondary.opacity(0.5))
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(removeHovered ? Color.distraction.opacity(0.1) : Color.primary.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
            .onHover { h in removeHovered = h }
            .accessibilityLabel("Remove \(site) from block list")
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(Color.sep.opacity(isHovered ? 0.15 : 0.08), lineWidth: 0.5)
                )
        )
        .onHover { h in
            withAnimation(Anim.quick) { isHovered = h }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Blocked site: \(site)")
    }
}
