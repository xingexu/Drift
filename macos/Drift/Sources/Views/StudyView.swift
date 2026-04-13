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
            // Immersive ambient background
            AmbientBackground(mode: viewModel.mode, progress: viewModel.progress)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Blocked-site banner
                    BlockedBanner(
                        isVisible: $viewModel.showBlockedBanner,
                        site: blocker.lastBlockedSite
                    )

                    // Header with mode pill
                    StudyHeader(mode: viewModel.mode, modeLabel: viewModel.modeLabel)

                    // Timer ring
                    TimerRingView(
                        timeRemaining: viewModel.timeRemaining,
                        progress: viewModel.progress,
                        mode: viewModel.mode,
                        modeLabel: viewModel.modeLabel,
                        ringColor: viewModel.ringColor,
                        isPulsing: viewModel.mode == .focus
                    )
                    .padding(.vertical, 8)

                    // Subject input
                    SubjectInput(
                        subject: $viewModel.subject,
                        isDisabled: viewModel.mode != .idle
                    )

                    // Timer controls
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
                        .fill(Color(.separatorColor).opacity(0.15))
                        .frame(height: 1)
                        .padding(.vertical, 4)

                    // Focus Blocker section
                    FocusBlockerSection(blocker: blocker)
                }
                .padding(28)
            }
        }
        .onChange(of: viewModel.focusDuration) { _, newValue in
            if viewModel.mode == .idle { viewModel.timeRemaining = newValue * 60 }
        }
        .onChange(of: blocker.blockedAttempts) { _, newValue in
            guard newValue > 0 else { return }
            withAnimation(.spring(response: 0.4)) { viewModel.showBlockedBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.3)) { viewModel.showBlockedBanner = false }
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
        case .idle, .focus: return Color.drift
        case .rest: return Color("Green")
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

private struct AmbientBackground: View {
    let mode: StudyViewModel.StudyMode
    let progress: CGFloat

    @State private var phase: CGFloat = 0

    private var baseColor: Color {
        switch mode {
        case .idle: return .clear
        case .focus: return Color.drift
        case .rest: return Color("Green")
        }
    }

    var body: some View {
        ZStack {
            Color("Background")

            if mode != .idle {
                // Radial glow that breathes
                RadialGradient(
                    colors: [baseColor.opacity(0.06 + 0.02 * sin(phase)), .clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: 400
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: phase)

                // Progress-aware top accent
                LinearGradient(
                    colors: [baseColor.opacity(0.04 * Double(progress)), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
        }
        .drawingGroup()
        .onAppear { phase = 1 }
        .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: phase)
    }
}

// MARK: - Blocked Banner

private struct BlockedBanner: View {
    @Binding var isVisible: Bool
    let site: String?

    var body: some View {
        if isVisible, let site {
            HStack(spacing: 10) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(site) was blocked!")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { isVisible = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss blocked site banner")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color("Red").opacity(0.9), Color.orange.opacity(0.8)],
                        startPoint: .leading, endPoint: .trailing
                    ))
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
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus Timer")
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)
                Text("Pomodoro-style deep work sessions")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if mode != .idle {
                ModePill(mode: mode, label: modeLabel)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mode)
    }
}

// MARK: - Mode Pill

private struct ModePill: View {
    let mode: StudyViewModel.StudyMode
    let label: String

    @State private var pulsing = false

    private var pillColor: Color {
        mode == .focus ? Color.drift : Color("Green")
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(pillColor)
                .frame(width: 7, height: 7)
                .shadow(color: pillColor.opacity(pulsing ? 0.7 : 0.3), radius: pulsing ? 6 : 3)
                .scaleEffect(pulsing ? 1.15 : 1.0)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(pillColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(pillColor.opacity(0.1)))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .accessibilityLabel("Current mode: \(label)")
    }
}

// MARK: - Timer Ring View

private struct TimerRingView: View {
    let timeRemaining: Int
    let progress: CGFloat
    let mode: StudyViewModel.StudyMode
    let modeLabel: String
    let ringColor: Color
    let isPulsing: Bool

    @State private var breathe = false

    var body: some View {
        ZStack {
            // Outer track
            Circle()
                .stroke(Color(.separatorColor).opacity(0.2), lineWidth: 8)
                .frame(width: 220, height: 220)

            // Background glow when active
            if mode != .idle {
                Circle()
                    .fill(ringColor.opacity(breathe ? 0.06 : 0.03))
                    .frame(width: 240, height: 240)
                    .blur(radius: 24)
            }

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.4), ringColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.8), value: progress)
                .shadow(color: ringColor.opacity(0.3), radius: 8)

            // Tick mark at progress tip
            if mode != .idle && progress > 0.01 {
                Circle()
                    .fill(ringColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: ringColor.opacity(0.5), radius: 4)
                    .offset(y: -110)
                    .rotationEffect(.degrees(360 * Double(progress)))
                    .animation(.linear(duration: 0.8), value: progress)
            }

            // Center content
            VStack(spacing: 6) {
                Text(formatCountdown(timeRemaining))
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .tracking(-2)
                    .contentTransition(.numericText())
                    .animation(.default, value: timeRemaining)
                    .scaleEffect(isPulsing && breathe ? 1.01 : 1.0)

                Text(modeLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .drawingGroup()
        .shadow(color: ringColor.opacity(mode == .focus ? 0.12 : 0), radius: 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathe = true
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
        HStack(spacing: 10) {
            Image(systemName: "pencil.line")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            TextField("What are you working on?", text: $subject)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .accessibilityLabel("Focus subject")
                .accessibilityHint("Enter what you are working on")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
        )
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

// MARK: - Timer Controls

private struct TimerControls: View {
    let mode: StudyViewModel.StudyMode
    let onStart: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void

    @State private var startHovered = false
    @State private var stopHovered = false
    @State private var skipHovered = false

    var body: some View {
        HStack(spacing: 12) {
            if mode == .idle {
                startButton
            } else {
                stopButton
                skipButton
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: mode)
    }

    private var startButton: some View {
        Button(action: onStart) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                Text("Start Focus")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.drift)
                    .shadow(color: Color.drift.opacity(startHovered ? 0.4 : 0.2),
                            radius: startHovered ? 12 : 6, y: 3)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .scaleEffect(startHovered ? 1.04 : 1)
        .animation(.easeOut(duration: 0.12), value: startHovered)
        .onHover { h in startHovered = h }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .accessibilityLabel("Start focus session")
        .accessibilityHint("Press Space to start")
    }

    private var stopButton: some View {
        Button(action: onStop) {
            HStack(spacing: 6) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12))
                Text("Stop")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule().stroke(Color.primary.opacity(stopHovered ? 0.08 : 0.04), lineWidth: 1)
                    )
            )
            .foregroundStyle(stopHovered ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .scaleEffect(stopHovered ? 1.03 : 1)
        .animation(.easeOut(duration: 0.12), value: stopHovered)
        .onHover { h in stopHovered = h }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .accessibilityLabel("Stop session")
        .accessibilityHint("Press Escape to stop")
    }

    private var skipButton: some View {
        Button(action: onSkip) {
            HStack(spacing: 6) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 12))
                Text(mode == .focus ? "Skip to Break" : "Skip Break")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.drift)
                    .shadow(color: Color.drift.opacity(skipHovered ? 0.3 : 0.1),
                            radius: skipHovered ? 8 : 4, y: 2)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .scaleEffect(skipHovered ? 1.03 : 1)
        .animation(.easeOut(duration: 0.12), value: skipHovered)
        .onHover { h in skipHovered = h }
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
        HStack(spacing: 28) {
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
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
        )
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
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
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Text(label)
                .font(.system(size: 12, weight: .medium))
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
                iconColor: Color.drift.opacity(0.6),
                value: "\(sessionCount)",
                label: "Sessions"
            )

            Rectangle()
                .fill(Color(.separatorColor).opacity(0.3))
                .frame(width: 1, height: 36)

            StatItem(
                icon: "clock",
                iconColor: Color("Green").opacity(0.6),
                value: formatStudyTime(totalFocusTime),
                label: "Total Focus"
            )
        }
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
        )
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
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: value)
            Text(label)
                .font(.system(size: 11, weight: .medium))
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
        VStack(spacing: 20) {
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
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: blocker.isBlocking)
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
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.drift)
                    Text("Focus Blocker")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.3)
                }
                Text("Block distracting websites while you work")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if isBlocking {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color("Red"))
                        .frame(width: 7, height: 7)
                        .shadow(color: Color("Red").opacity(0.6), radius: 4)
                    Text("Blocking")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color("Red"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color("Red").opacity(0.1)))
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
    @State private var stopHovered = false

    var body: some View {
        VStack(spacing: 16) {
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { blockedBounce = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring()) { blockedBounce = false }
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
                    HStack(spacing: 8) {
                        Image(systemName: blocker.passwordRequired ? "lock.fill" : "stop.fill")
                            .font(.system(size: 12))
                        Text("Stop Early")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color("Red").opacity(stopHovered ? 0.2 : 0.1), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(Color("Red"))
                }
                .buttonStyle(.plain)
                .scaleEffect(stopHovered ? 1.03 : 1)
                .animation(.easeOut(duration: 0.12), value: stopHovered)
                .onHover { h in stopHovered = h }
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

private struct BlockerCountdown: View {
    @ObservedObject var blocker: FocusBlocker
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.separatorColor).opacity(0.2), lineWidth: 6)
                .frame(width: 140, height: 140)

            Circle()
                .fill(Color("Red").opacity(breathe ? 0.05 : 0.02))
                .frame(width: 140, height: 140)
                .blur(radius: 12)

            Circle()
                .trim(from: 0, to: min(blocker.progress, 1.0))
                .stroke(
                    AngularGradient(
                        colors: [Color("Red").opacity(0.4), Color("Red")],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: blocker.progress)

            VStack(spacing: 4) {
                Text(blocker.timeRemainingFormatted)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .tracking(-1)
                    .contentTransition(.numericText())
                    .animation(.default, value: blocker.timeRemainingFormatted)
                Text("remaining")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
        }
        .drawingGroup()
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color("Red").opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
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
                iconColor: Color("Red").opacity(0.6),
                value: "\(blockedAttempts)",
                label: "Blocked"
            )
            .scaleEffect(bounce ? 1.05 : 1.0)

            Rectangle().fill(Color(.separatorColor).opacity(0.3)).frame(width: 1, height: 36)

            StatItem(
                icon: "globe",
                iconColor: Color.drift.opacity(0.6),
                value: "\(siteCount)",
                label: "Sites"
            )

            if let lastSite = lastBlockedSite {
                Rectangle().fill(Color(.separatorColor).opacity(0.3)).frame(width: 1, height: 36)

                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange.opacity(0.6))
                    Text(lastSite)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("Last Blocked")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.3)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last blocked site: \(lastSite)")
            }
        }
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
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
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("Red"))
                Text("Enter password to stop blocking")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(passwordError ? Color("Red").opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .onSubmit { attemptStop() }
                    .accessibilityLabel("Blocking password")

                Button(action: attemptStop) {
                    Text("Unlock")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color("Red")))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unlock and stop blocking")

                Button {
                    showDialog = false
                    password = ""
                    passwordError = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel unlock")
            }

            if passwordError {
                Text("Incorrect password")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color("Red"))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("Red").opacity(0.1), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func attemptStop() {
        let success = blocker.stopBlocking(password: password)
        if success {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDialog = false
                password = ""
                passwordError = false
            }
        } else {
            withAnimation(.easeInOut(duration: 0.15)) {
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
    @State private var startHovered = false

    private var passwordsMatch: Bool {
        password == passwordConfirm
    }

    private var canStart: Bool {
        if password.isEmpty { return true }
        return passwordsMatch && !passwordConfirm.isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
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
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSetup)
    }

    private var setupPanel: some View {
        VStack(spacing: 14) {
            // Duration picker
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                Text("Duration")
                    .font(.system(size: 13, weight: .medium))
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "lock")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    Text("Lock Password")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Optional")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                SecureField("Set a password to prevent early stop", text: $password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .accessibilityLabel("Set lock password")

                if !password.isEmpty {
                    SecureField("Confirm password", text: $passwordConfirm)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            passwordsMatch ? Color.primary.opacity(0.06) : Color("Red").opacity(0.2),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityLabel("Confirm lock password")

                    if !passwordConfirm.isEmpty && !passwordsMatch {
                        Text("Passwords do not match")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color("Red"))
                            .transition(.opacity)
                    }
                }
            }

            // Start / Cancel buttons
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSetup = false
                        password = ""
                        passwordConfirm = ""
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                        )
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel blocker setup")

                Button(action: startBlocker) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 13))
                        Text("Start Blocking")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.drift)
                            .shadow(color: Color.drift.opacity(startHovered ? 0.4 : 0.2),
                                    radius: startHovered ? 10 : 5, y: 2)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .scaleEffect(startHovered ? 1.03 : 1)
                .animation(.easeOut(duration: 0.12), value: startHovered)
                .onHover { h in startHovered = h }
                .disabled(!canStart)
                .opacity(canStart ? 1 : 0.5)
                .accessibilityLabel("Start blocking distracting sites")
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.drift.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var startBlockButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showSetup = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14))
                Text("Start Focus Block")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.drift.opacity(startHovered ? 0.12 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.drift.opacity(startHovered ? 0.2 : 0.12), lineWidth: 1)
                    )
            )
            .foregroundStyle(Color.drift)
        }
        .buttonStyle(.plain)
        .scaleEffect(startHovered ? 1.01 : 1)
        .animation(.easeOut(duration: 0.12), value: startHovered)
        .onHover { h in startHovered = h }
        .accessibilityLabel("Set up focus blocker")
    }

    private func startBlocker() {
        let pw = password.isEmpty ? nil : password
        blocker.startBlocking(durationMinutes: duration, password: pw)

        withAnimation(.easeInOut(duration: 0.2)) {
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

    @State private var addHovered = false
    @State private var resetHovered = false

    var body: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showList.toggle() }
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    Text("Blocked Sites")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(blocker.blockedSites.count) sites")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showList ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: showList)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Blocked sites: \(blocker.blockedSites.count) sites")
            .accessibilityHint("Activate to \(showList ? "collapse" : "expand") the list")

            if showList {
                VStack(spacing: 8) {
                    // Add new site
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.drift.opacity(0.6))
                        TextField("Add domain (e.g. example.com)", text: $newSite)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .onSubmit { addSite() }
                            .accessibilityLabel("Add blocked domain")
                        Button(action: addSite) {
                            Text("Add")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.drift))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(addHovered ? 1.05 : 1)
                        .animation(.easeOut(duration: 0.1), value: addHovered)
                        .onHover { h in addHovered = h }
                        .disabled(newSite.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(newSite.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                        .accessibilityLabel("Add site to block list")
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                            )
                    )

                    // Sites grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ], spacing: 8) {
                        ForEach(blocker.blockedSites, id: \.self) { site in
                            BlockedSiteChip(site: site) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    blocker.removeSite(site)
                                }
                            }
                        }
                    }

                    // Reset to defaults
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { blocker.resetToDefaults() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text("Reset to defaults")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(resetHovered ? .primary : .tertiary)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(resetHovered ? 1.02 : 1)
                    .animation(.easeOut(duration: 0.1), value: resetHovered)
                    .onHover { h in resetHovered = h }
                    .padding(.top, 4)
                    .accessibilityLabel("Reset blocked sites to defaults")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
        )
    }

    private func addSite() {
        let site = newSite.trimmingCharacters(in: .whitespaces)
        guard !site.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
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
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(site)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(removeHovered ? Color("Red") : Color.secondary.opacity(0.5))
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(removeHovered ? Color("Red").opacity(0.1) : Color.primary.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
            .onHover { h in removeHovered = h }
            .accessibilityLabel("Remove \(site) from block list")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(isHovered ? 0.06 : 0.03), lineWidth: 1)
                )
        )
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.1)) { isHovered = h }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Blocked site: \(site)")
    }
}
