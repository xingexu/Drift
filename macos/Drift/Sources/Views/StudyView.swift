import SwiftUI
@preconcurrency import UserNotifications
import ApplicationServices
import Combine

// MARK: - Study View

struct StudyView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = StudyViewModel()
    @StateObject private var blocker = FocusBlocker.shared

    @State private var showMiniPlayer = false
    @State private var showBlockingList = false
    @State private var showBlockingDetails = false
    @State private var customizeHovered = false
    private let miniPlayerPanel = MiniPlayerPanel()

    // MARK: - Body

    var body: some View {
        ZStack {
            if viewModel.mode == .idle {
                idleFocusSetup
                    .transition(
                        appState.reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .scale(scale: 0.98))
                    )
            } else {
                activeFocusJourney
                    .transition(
                        appState.reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .offset(y: 6))
                    )
            }

            if viewModel.showBlockedBanner {
                VStack {
                    BlockedBanner(
                        isVisible: $viewModel.showBlockedBanner,
                        site: blocker.lastBlockedSite
                    )
                    .padding(.top, 20)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if viewModel.showCompletion {
                CompletionOverlay()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(appState.reduceMotion ? nil : .easeOut(duration: 0.22), value: viewModel.mode)
        .animation(appState.reduceMotion ? nil : Anim.appear, value: viewModel.showCompletion)
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
        .onAppear {
            viewModel.onAppear()
#if DEBUG
            if ProcessInfo.processInfo.environment["DRIFT_SNAPSHOT_FOCUS"] == "active",
               viewModel.mode == .idle {
                viewModel.subject = "Finish the launch narrative"
                viewModel.blockDistractingSites = false
                viewModel.startFocus()
            }
#endif
        }
        .onDisappear { viewModel.onDisappear() }
        .focusable()
        .onKeyPress(.space) {
            if viewModel.mode == .idle {
                viewModel.startFocus()
            } else if !viewModel.showResult {
                viewModel.togglePause()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if viewModel.mode != .idle && !viewModel.showResult { viewModel.showStopConfirmation = true }
            return .handled
        }
        .sheet(isPresented: $showBlockingList) {
            ZStack {
                Color.driftCanvas.ignoresSafeArea()
                FocusBlockerSection(blocker: blocker)
                    .frame(maxWidth: 620)
                    .padding(28)
            }
            .frame(width: 680, height: 620)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showBlockingDetails) {
            ZStack {
                Color.driftCanvas.ignoresSafeArea()
                FocusBlockerSection(blocker: blocker)
                    .frame(maxWidth: 620)
                    .padding(28)
            }
            .frame(width: 680, height: 620)
            .preferredColorScheme(.dark)
        }
    }

    private var idleFocusSetup: some View {
        ZStack {
            Color.black.opacity(0.08)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focus")
                            .font(TypeScale.h1)
                            .foregroundStyle(Color.cream)
                        Text("Choose one thing. Drift will keep the rest quiet.")
                            .font(TypeScale.bodyMd)
                            .foregroundStyle(Color.creamMuted)
                    }

                    FunctionalGlassPanel(padding: 28, cornerRadius: DriftSurfaceRadius.major) {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("What do you want to finish?")
                                    .font(TypeScale.heading)
                                    .foregroundStyle(Color.cream)
                                TaskInputField(taskName: $viewModel.subject)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("FOCUS DURATION").sectionLabel()
                                SegmentedControl(
                                    options: [25, 45, 60],
                                    selection: $viewModel.focusDuration,
                                    title: { "\($0)m" }
                                )
                            }

                            VStack(spacing: 0) {
                                SettingsRow(
                                    title: "Add a break",
                                    explanation: "Choose a short reset after this focus block."
                                ) {
                                    Toggle("Add a break", isOn: $viewModel.includeBreak)
                                        .labelsHidden()
                                        .toggleStyle(.switch)
                                        .tint(Color.sand)
                                }

                                if viewModel.includeBreak {
                                    HStack {
                                        Text("BREAK DURATION")
                                            .sectionLabel()
                                        Spacer()
                                        SegmentedControl(
                                            options: [5, 10, 15],
                                            selection: $viewModel.breakDuration,
                                            title: { "\($0)m" }
                                        )
                                    }
                                    .padding(.horizontal, Space.lg)
                                    .padding(.vertical, Space.md)
                                    .transition(.opacity)
                                }

                                SettingsRow(
                                    title: "Block \(blocker.blockedSites.count) distracting sites",
                                    explanation: "Keep the sites in your blocking list quiet."
                                ) {
                                    Toggle("Block distracting sites", isOn: $viewModel.blockDistractingSites)
                                        .labelsHidden()
                                        .toggleStyle(.switch)
                                        .tint(Color.sand)
                                }

                                Button {
                                    showBlockingList = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.system(size: 13, weight: .semibold))
                                            .frame(width: 20)
                                        Text("Customize")
                                            .font(TypeScale.bodyMd)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color.creamMuted)
                                            .offset(x: customizeHovered ? 2 : 0)
                                    }
                                    .foregroundStyle(Color.cream)
                                    .padding(.horizontal, Space.lg)
                                    .frame(height: 56)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(DriftButtonStyle(variant: .ghost))
                                .onHover { customizeHovered = $0 }
                                .animation(Anim.quick, value: customizeHovered)
                                .help("Customize blocked websites")
                                .accessibilityLabel("Customize blocked websites")
                            }
                            .driftInsetSurface()

                            PrimaryPillButton(
                                title: "Begin \(viewModel.focusDuration)-minute focus",
                                icon: "play.fill",
                                isFullWidth: true
                            ) {
                                viewModel.startFocus()
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                    .frame(width: 680)
                }
                .frame(maxWidth: 1180, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, 32)
                .padding(.top, 30)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func durationSetting(
        title: String,
        values: [Int],
        selection: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).sectionLabel()
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { minutes in
                    DurationChip(label: "\(minutes)m", isSelected: selection.wrappedValue == minutes) {
                        selection.wrappedValue = minutes
                    }
                }
            }
        }
    }

    private var activeFocusJourney: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.10)

                if viewModel.showResult {
                    focusResult
                } else {
                    VStack(spacing: 24) {
                        Text(viewModel.subject.isEmpty ? "Focus session" : viewModel.subject)
                            .font(TypeScale.bodyMd)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.cream.opacity(0.82))
                            .lineLimit(1)

                        Text(formatCountdown(viewModel.timeRemaining))
                            .font(PixelFont.font(68))
                            .foregroundStyle(Color.cream)
                            .monospacedDigit()

                        Text("\(formatStudyTime(viewModel.elapsedFocusSeconds)) focused")
                            .font(TypeScale.monoSm)
                            .foregroundStyle(Color.creamMuted)

                        HStack(spacing: 12) {
                            SecondaryPillButton(
                                title: viewModel.isPaused ? "Resume" : "Pause",
                                icon: viewModel.isPaused ? "play.fill" : "pause.fill"
                            ) {
                                viewModel.togglePause()
                            }

                            SecondaryPillButton(title: "Finish", icon: "stop.fill") {
                                viewModel.showStopConfirmation = true
                            }

                            SecondaryPillButton(
                                title: blocker.isBlocking
                                    ? "Blocking \(blocker.blockedSites.count) sites"
                                    : "Blocking off",
                                icon: blocker.isBlocking ? "shield.fill" : "shield.slash"
                            ) {
                                showBlockingDetails = true
                            }
                        }
                    }
                    .padding(.bottom, 92)
                }

                TravelerJourney(
                    progress: viewModel.progress,
                    isPaused: viewModel.isPaused,
                    reduceMotion: appState.reduceMotion
                )
                    .frame(width: min(proxy.size.width - 120, 920), height: 82)
                    .position(x: proxy.size.width / 2, y: proxy.size.height - 72)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Finish focus session?", isPresented: $viewModel.showStopConfirmation) {
            Button("Keep focusing", role: .cancel) {}
            Button("Finish", role: .destructive) { viewModel.finishSession() }
        } message: {
            Text("Your focused time so far will be saved in this result.")
        }
    }

    private var focusResult: some View {
        TactilePanel(padding: 28, density: .popover) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Focus complete")
                    .font(PixelFont.font(15))
                    .foregroundStyle(Color.cream)

                HStack(spacing: 0) {
                    MetricCell(
                        label: "Focused time",
                        value: formatStudyTime(viewModel.resultFocusedSeconds),
                        color: .productive
                    )
                    Rectangle().fill(Color.cream.opacity(0.12)).frame(width: 1, height: 54)
                    MetricCell(
                        label: "Switches",
                        value: "\(viewModel.resultSwitches)",
                        color: .sand
                    )
                    .padding(.leading, 18)
                    Rectangle().fill(Color.cream.opacity(0.12)).frame(width: 1, height: 54)
                    MetricCell(
                        label: "Blocked",
                        value: "\(viewModel.resultBlockedAttempts)",
                        comparison: "distractions",
                        color: .distraction
                    )
                    .padding(.leading, 18)
                }

                HStack(spacing: 12) {
                    PrimaryPillButton(title: "Done", icon: "checkmark") {
                        viewModel.dismissResult()
                    }
                    SecondaryPillButton(title: "Start another", icon: "arrow.clockwise") {
                        viewModel.startAnother()
                    }
                }
            }
            .frame(width: 560, alignment: .leading)
        }
        .padding(.bottom, 70)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus session complete")
    }

    private func focusControl(title: String, icon: String, action: @escaping () -> Void) -> some View {
        SecondaryPillButton(title: title, icon: icon, action: action)
    }

    // MARK: - Main Card (two-column)

    @ViewBuilder
    private var mainCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ringTimerPanel
                .frame(minWidth: 430, maxWidth: 500, minHeight: 430)
                .pixelPanel()

            controlsPanel
                .frame(maxWidth: .infinity, minHeight: 430, alignment: .leading)
                .pixelPanel()
        }
        .alert("End Focus Session?", isPresented: $viewModel.showStopConfirmation) {
            Button("Keep Going", role: .cancel) {}
            Button("End Session", role: .destructive) { viewModel.stopStudy() }
        } message: {
            Text("Ending early means losing your focus streak.")
        }
    }

    // MARK: - Ring Timer Panel (left)

    @ViewBuilder
    private var ringTimerPanel: some View {
        ZStack {
            Rectangle()
                .stroke(Color.accentDeep.opacity(0.46), lineWidth: 1)
                .overlay {
                    Rectangle()
                        .stroke(Color.streak.opacity(0.34), lineWidth: 1)
                        .padding(7)
                }

            VStack(spacing: 12) {
                Image(systemName: "hourglass")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.streak)
                    .padding(.bottom, 18)
                Text(formatCountdown(viewModel.timeRemaining))
                    .font(PixelFont.font(72))
                    .contentTransition(.numericText())
                    .animation(Anim.count, value: viewModel.timeRemaining)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(viewModel.modeLabelDisplay)
                    .font(TypeScale.caption)
                    .foregroundStyle(viewModel.mode == .idle
                        ? Color.secondary.opacity(0.5)
                        : viewModel.ringColor.opacity(0.85))
                    .tracking(0)
                    .textCase(.uppercase)
                    .animation(Anim.quick, value: viewModel.mode)

                HStack(spacing: 5) {
                    ForEach(0..<10, id: \.self) { index in
                        Rectangle()
                            .fill(index < Int((viewModel.progress * 10).rounded(.up)) ? Color.productive : Color.clear)
                            .overlay(Rectangle().strokeBorder(Color.border.opacity(0.6), lineWidth: 1))
                            .frame(width: 13, height: 9)
                    }
                }
                .padding(.top, 28)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.modeLabel) timer. \(viewModel.timeRemaining / 60) minutes and \(viewModel.timeRemaining % 60) seconds remaining")
    }

    // MARK: - Controls Panel (right)

    @ViewBuilder
    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: Space.lg) {

            // Task input
            TaskInputField(taskName: $viewModel.subject)

            // Duration chips
            VStack(alignment: .leading, spacing: Space.sm) {
                // Focus row
                HStack(spacing: Space.xs) {
                    Image(systemName: "timer")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text("FOCUS")
                        .font(TypeScale.tiny)
                        .foregroundStyle(.tertiary)
                        .tracking(0)
                    ForEach([25, 45, 60], id: \.self) { mins in
                        DurationChip(
                            label: "\(mins)m",
                            isSelected: viewModel.focusDuration == mins,
                            disabled: viewModel.mode != .idle
                        ) {
                            withAnimation(Anim.tap) { viewModel.focusDuration = mins }
                        }
                    }
                }
                // Break row
                HStack(spacing: Space.xs) {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text("BREAK")
                        .font(TypeScale.tiny)
                        .foregroundStyle(.tertiary)
                        .tracking(0)
                    ForEach([5, 10, 15], id: \.self) { mins in
                        DurationChip(
                            label: "\(mins)m",
                            isSelected: viewModel.breakDuration == mins,
                            disabled: viewModel.mode != .idle
                        ) {
                            withAnimation(Anim.tap) { viewModel.breakDuration = mins }
                        }
                    }
                }
            }

            // Play / stop controls
            playControls
        }
        .padding(Space.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Play / Stop Controls

    @ViewBuilder
    private var playControls: some View {
        VStack(spacing: Space.xs) {
            if viewModel.mode == .idle {
                // Single play button
                VStack(spacing: Space.xs) {
                    Button {
                        viewModel.togglePlayPause()
                    } label: {
                        Rectangle()
                            .fill(Color.accent)
                            .frame(width: 76, height: 76)
                            .overlay(Rectangle().strokeBorder(Color.driftText.opacity(0.30), lineWidth: 1))
                            .shadow(color: Color.driftShadow, radius: 0, x: 4, y: 4)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .offset(x: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Start focus session")

                    Text("Space starts the session")
                        .font(TypeScale.caption)
                        .foregroundStyle(Color.driftMuted)
                }
            } else {
                // Active: stop + skip
                HStack(spacing: Space.xxl) {
                    // Stop
                    Button {
                        viewModel.showStopConfirmation = true
                    } label: {
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                            .overlay(Rectangle().strokeBorder(Color.sep.opacity(0.28), lineWidth: 1))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            )
                    }
                    .buttonStyle(DriftButtonStyle(variant: .ghost))
                    .accessibilityLabel("Stop session")

                    // Skip
                    Button {
                        viewModel.skipPhase()
                    } label: {
                        Rectangle()
                            .fill(viewModel.mode == .focus ? Color.productive : Color.accent)
                            .frame(width: 64, height: 64)
                            .shadow(
                                color: (viewModel.mode == .focus ? Color.productive : Color.accent).opacity(0.38),
                                radius: 0, x: 6, y: 6
                            )
                            .overlay(
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                    .buttonStyle(DriftButtonStyle(variant: .primary))
                    .accessibilityLabel(viewModel.mode == .focus ? "Skip to break" : "Skip break, start focus")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(Anim.tap, value: viewModel.mode)
    }

    // MARK: - Active Blocker Badge (shown during focus when blocking)

    @ViewBuilder
    private var activeBlockerBadge: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.sm) {
                DriftTag(text: "\(blocker.blockedSites.count) sites blocked", color: Color.distraction)
                Spacer()
                HStack(spacing: Space.xxs) {
                    Rectangle()
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
                                Rectangle().fill(Color.primary.opacity(0.06))
                                    .overlay(Rectangle().strokeBorder(Color.sep.opacity(0.12), lineWidth: 0.5))
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
            Rectangle()
                .fill(Color.distraction.opacity(0.04))
                .overlay(
                    Rectangle()
                        .strokeBorder(Color.distraction.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

private struct TravelerJourney: View {
    let progress: CGFloat
    let isPaused: Bool
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)
            let travelWidth = max(proxy.size.width - 64, 1)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.20))
                    .frame(height: 2)
                    .offset(y: 20)

                HStack(spacing: 4) {
                    ForEach(0..<18, id: \.self) { index in
                        Rectangle()
                            .fill(index < Int(clampedProgress * 18) ? Color.streak : Color.white.opacity(0.18))
                            .frame(maxWidth: .infinity)
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 28)
                .offset(y: 20)

                PixelTraveler()
                    .frame(width: 34, height: 44)
                    .offset(x: clampedProgress * travelWidth)
                    .animation(reduceMotion || isPaused ? nil : .linear(duration: 0.9), value: clampedProgress)

                PixelCampfire()
                    .frame(width: 34, height: 44)
                    .offset(x: proxy.size.width - 34)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Journey \(Int(progress * 100)) percent complete")
    }
}

private struct PixelTraveler: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.34)).frame(width: 28, height: 4)
            Rectangle().fill(Color.streak).frame(width: 12, height: 18).offset(y: -5)
            Rectangle().fill(Color.white).frame(width: 12, height: 10).offset(y: -24)
            Rectangle().fill(Color.accentDeep).frame(width: 5, height: 7).offset(x: -8, y: -10)
        }
    }
}

private struct PixelCampfire: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.34)).frame(width: 32, height: 4)
            Rectangle().fill(Color.distraction).frame(width: 18, height: 10).offset(y: -5)
            Rectangle().fill(Color.streak).frame(width: 10, height: 16).offset(y: -8)
            Rectangle().fill(Color.white.opacity(0.88)).frame(width: 4, height: 7).offset(y: -12)
        }
    }
}

private struct StudyPageIcon: View {
    let color: Color

    var body: some View {
        ZStack {
            Rectangle()
                .fill(color.opacity(0.11))
                .overlay(Rectangle().strokeBorder(color.opacity(0.34), lineWidth: 1))
            Rectangle().stroke(color, lineWidth: 2).frame(width: 16, height: 16)
            Rectangle().fill(color).frame(width: 6, height: 6)
            Rectangle().fill(Color.productive).frame(width: 4, height: 4).offset(x: 9, y: -9)
        }
    }
}

// MARK: - Duration Chip

private struct DurationChip: View {
    let label: String
    let isSelected: Bool
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(TypeScale.bodySm)
                .foregroundStyle(isSelected ? Color.accent : Color.secondary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(
                    Rectangle()
                        .fill(isSelected
                              ? Color.accent.opacity(0.14)
                              : Color.primary.opacity(0.05))
                        .overlay(
                            Rectangle()
                                .strokeBorder(isSelected ? Color.accent : Color.driftBorder.opacity(0.36), lineWidth: 2)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled && !isSelected ? 0.45 : 1)
        .accessibilityLabel("\(label) duration")
    }
}

// MARK: - Task Input Field

private struct TaskInputField: View {
    @Binding var taskName: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "pencil")
                .font(.system(size: 12))
                .foregroundStyle(isFocused ? Color.sand : Color.creamMuted)
                .animation(Anim.quick, value: isFocused)
            TextField("Draft the proposal, finish the edit…", text: $taskName)
                .textFieldStyle(.plain)
                .font(TypeScale.body)
                .foregroundStyle(Color.cream)
                .focused($isFocused)
                .accessibilityLabel("Focus task name")
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .driftInsetSurface()
        .overlay(
            RoundedRectangle(cornerRadius: DriftSurfaceRadius.input, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.cream.opacity(0.78) : Color.clear,
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .animation(Anim.quick, value: isFocused)
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
    @Published var includeBreak = false
    @Published var showStopConfirmation = false
    @Published var showBlockedBanner = false
    @Published var showCompletion = false
    @Published var completionRingFlash = false
    @Published var blockDistractingSites = true
    @Published var isPaused = false
    @Published var showResult = false
    @Published var resultFocusedSeconds = 0
    @Published var resultSwitches = 0
    @Published var resultBlockedAttempts = 0

    private var timerCancellable: AnyCancellable?
    private var phaseEndDate: Date?
    private var phaseTotalSeconds: Int = 0
    private var lastAnnouncedMinute: Int = -1
    private var startingEventCount = 0
    private var startingBlockedAttempts = 0

    var elapsedFocusSeconds: Int {
        if mode == .rest { return resultFocusedSeconds }
        return max(0, focusDuration * 60 - timeRemaining)
    }

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

    /// Uppercase display label for the ring center
    var modeLabelDisplay: String {
        switch mode {
        case .idle:  return "READY"
        case .focus: return "RUNNING"
        case .rest:  return "BREAK"
        }
    }

    func onAppear() {}
    func onDisappear() { stopTimer() }

    func startFocus() {
        mode = .focus
        showResult = false
        isPaused = false
        resultFocusedSeconds = 0
        resultSwitches = 0
        resultBlockedAttempts = 0
        phaseTotalSeconds = focusDuration * 60
        timeRemaining = phaseTotalSeconds
        phaseEndDate = Date().addingTimeInterval(TimeInterval(phaseTotalSeconds))
        startingEventCount = AppState.shared.session.events.count
        startingBlockedAttempts = FocusBlocker.shared.blockedAttempts
        if !WindowTracker.shared.isTracking && AXIsProcessTrusted() {
            WindowTracker.shared.start()
        }
        AppState.shared.focusModeActive = true
        let blocker = FocusBlocker.shared
        if blockDistractingSites && !blocker.isBlocking {
            blocker.startBlocking(durationMinutes: focusDuration, password: nil)
        }
        startTimer()
    }

    func stopStudy() {
        finishSession()
    }

    func finishSession() {
        guard mode != .idle, !showResult else { return }
        if mode == .focus {
            captureFocusResult()
        }
        stopTimer()
        phaseEndDate = nil
        isPaused = false
        showResult = true
        if FocusBlocker.shared.isBlocking {
            _ = FocusBlocker.shared.stopBlocking(password: nil)
        }
        sendNotification(title: "Focus session complete", body: "\(resultFocusedSeconds / 60) focused minutes")
    }

    func dismissResult() {
        mode = .idle
        timeRemaining = focusDuration * 60
        phaseEndDate = nil
        showResult = false
        isPaused = false
        AppState.shared.focusModeActive = false
    }

    func startAnother() {
        dismissResult()
        startFocus()
    }

    func togglePause() {
        guard mode != .idle, !showResult else { return }
        if isPaused {
            phaseEndDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
            isPaused = false
            startTimer()
        } else {
            stopTimer()
            phaseEndDate = nil
            isPaused = true
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
        if mode == .idle { startFocus() } else { togglePause() }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                guard let self else { return }
                self.captureFocusResult()
                if self.includeBreak {
                    self.startBreak()
                } else {
                    self.finishSession()
                }
            }
        } else {
            sendNotification(title: "Break over!", body: "Time to focus again.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.finishSession()
            }
        }
    }

    private func captureFocusResult() {
        guard resultFocusedSeconds == 0 else { return }
        resultFocusedSeconds = elapsedFocusSeconds
        resultSwitches = max(AppState.shared.session.events.count - startingEventCount - 1, 0)
        resultBlockedAttempts = max(FocusBlocker.shared.blockedAttempts - startingBlockedAttempts, 0)
        totalFocusTime += resultFocusedSeconds
        if FocusBlocker.shared.isBlocking {
            _ = FocusBlocker.shared.stopBlocking(password: nil)
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
        case .idle:  return Color.accent
        case .focus: return Color.accent
        case .rest:  return Color.productive
        }
    }

    private var primaryOpacity: Double {
        switch mode {
        case .idle:  return 0.04
        case .focus: return 0.09
        case .rest:  return 0.07
        }
    }

    var body: some View {
        ZStack {
            DriftAmbientBackground(accent: primaryColor, reduceMotion: false)
                .ignoresSafeArea()
                .animation(Anim.appear, value: mode)

            // Secondary ambient — bottom-right drift tint when distraction is high
            if driftFraction > 0.25 {
                Rectangle()
                    .fill(Color.distraction.opacity(0.025 * min(driftFraction * 4, 1)))
                .ignoresSafeArea()
                .animation(Anim.appear, value: driftFraction > 0.25)
            }
        }
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
        .background {
            DriftGlassSurface(density: .popover, cornerRadius: Radius.xl)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .strokeBorder(Color.productive.opacity(0.20), lineWidth: 0.5)
                }
        }
        .shadow(color: Color.productive.opacity(0.20), radius: 16, y: 8)
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
                ZStack {
                    Rectangle()
                        .fill(Color.distraction.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: "shield.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.distraction)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Site Blocked")
                        .font(TypeScale.caption)
                        .foregroundStyle(Color.distraction)
                    Text(site)
                        .font(TypeScale.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    withAnimation(Anim.quick) { isVisible = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .padding(Space.xs)
                        .background(Rectangle().fill(Color.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background {
                DriftGlassSurface(density: .popover, cornerRadius: Radius.md)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(Color.distraction.opacity(0.42), lineWidth: 1)
                    }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(site) was blocked")
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
        VStack(spacing: Space.lg) {
            blockerHeader

            if blocker.isBlocking {
                activeBlockingContent
            } else {
                idleBlockerContent
            }
        }
        .padding(Space.xl)
        .background {
            DriftGlassSurface(density: .popover, cornerRadius: Radius.lg)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(
                            blocker.isBlocking
                                ? Color.distraction.opacity(0.42)
                                : Color.driftBorder,
                            lineWidth: 1
                        )
                }
        }
        .shadow(
            color: blocker.isBlocking ? Color.distraction.opacity(0.16) : Color.clear,
            radius: 16,
            y: 8
        )
        .onAppear { startTick() }
        .onDisappear { tickCancellable?.cancel() }
        .animation(Anim.appear, value: blocker.isBlocking)
        .animation(Anim.appear, value: showSetup)
    }

    // MARK: - Header

    @ViewBuilder
    private var blockerHeader: some View {
        HStack(alignment: .center, spacing: Space.md) {
            ZStack {
                Rectangle()
                    .fill(
                        blocker.isBlocking
                            ? Color.distraction.opacity(0.14)
                            : Color.accent.opacity(0.10)
                    )
                    .frame(width: 38, height: 38)
                Image(systemName: blocker.isBlocking ? "shield.fill" : "shield.checkered")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(blocker.isBlocking ? Color.distraction : Color.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Site Blocker")
                    .font(TypeScale.h2)
                    .foregroundStyle(Color.driftText)
                Text(blocker.isBlocking
                     ? "Protecting \(blocker.blockedSites.count) domains"
                     : "Block distracting sites")
                    .font(TypeScale.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if blocker.isBlocking {
                HStack(spacing: Space.xxs) {
                    StatusDot(status: .tracking)
                    Text("Live")
                        .font(TypeScale.tiny)
                        .foregroundStyle(Color.distraction)
                        .tracking(0.5)
                }
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xxs + 1)
                .background(
                    Rectangle().fill(Color.distraction.opacity(0.10))
                        .overlay(Rectangle().strokeBorder(Color.distraction.opacity(0.18), lineWidth: 0.5))
                )
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Site Blocker. \(blocker.isBlocking ? "Currently blocking sites" : "Inactive")")
    }

    // MARK: - Active Blocking

    @ViewBuilder
    private var activeBlockingContent: some View {
        VStack(spacing: Space.md) {
            BlockerCountdown(blocker: blocker)

            if blocker.blockedAttempts > 0 {
                HStack(spacing: Space.sm) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.distraction)
                    Text("\(blocker.blockedAttempts) attempt\(blocker.blockedAttempts == 1 ? "" : "s") blocked")
                        .font(TypeScale.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.distraction)
                    Spacer()
                    if let last = blocker.lastBlockedSite {
                        Text(last)
                            .font(TypeScale.tiny)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .padding(.horizontal, Space.xs)
                            .padding(.vertical, Space.xxxs)
                            .background(Rectangle().fill(Color.primary.opacity(0.06)))
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.distraction.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(Color.distraction.opacity(0.12), lineWidth: 0.5)
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
                    if blocker.passwordRequired { showStopDialog = true }
                    else { showBlockerStopConfirmation = true }
                } label: {
                    HStack(spacing: Space.sm) {
                        Image(systemName: blocker.passwordRequired ? "lock.fill" : "xmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(blocker.passwordRequired ? "Unlock to Stop" : "Stop Blocking")
                            .font(TypeScale.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Color.distraction.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .strokeBorder(Color.distraction.opacity(0.20), lineWidth: 0.5)
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

    // MARK: - Idle (setup) State

    @ViewBuilder
    private var idleBlockerContent: some View {
        VStack(spacing: Space.md) {
            BlockedSitesList(blocker: blocker, newSite: .constant(""))

            if showSetup {
                blockerSetupPanel
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Button {
                    withAnimation(Anim.appear) { showSetup = true }
                } label: {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Activate Site Blocker")
                            .font(TypeScale.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.md)
                    .background(
                        Rectangle()
                            .fill(Color.accent.opacity(0.10))
                            .overlay(
                                Rectangle()
                                    .strokeBorder(Color.accent.opacity(0.55), lineWidth: 2)
                            )
                    )
                    .foregroundStyle(Color.accent)
                }
                .driftButton(.secondary)
                .accessibilityLabel("Set up site blocker")
            }
        }
    }

    // MARK: - Setup Panel

    @ViewBuilder
    private var blockerSetupPanel: some View {
        VStack(spacing: Space.md) {
            HStack(spacing: Space.md) {
                Label {
                    Text("Duration")
                        .font(TypeScale.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
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
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .strokeBorder(Color.sep.opacity(0.10), lineWidth: 0.5)
                    )
            )

            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    Label {
                        Text("Lock Password")
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text("Optional")
                        .font(TypeScale.tiny)
                        .foregroundStyle(.quaternary)
                }

                SecureField("Password to prevent early stop", text: $blockerPassword)
                    .textFieldStyle(.plain)
                    .font(TypeScale.caption)
                    .padding(Space.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                                    .strokeBorder(Color.sep.opacity(0.12), lineWidth: 0.5)
                            )
                    )
                    .accessibilityLabel("Lock password")

                if !blockerPassword.isEmpty {
                    SecureField("Confirm password", text: $blockerPasswordConfirm)
                        .textFieldStyle(.plain)
                        .font(TypeScale.caption)
                        .padding(Space.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                                        .strokeBorder(
                                            passwordsMatch ? Color.sep.opacity(0.12) : Color.distraction.opacity(0.25),
                                            lineWidth: 0.5
                                        )
                                )
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityLabel("Confirm password")

                    if !blockerPasswordConfirm.isEmpty && !passwordsMatch {
                        Text("Passwords don't match")
                            .font(TypeScale.caption)
                            .foregroundStyle(Color.distraction)
                            .transition(.opacity)
                    }
                }
            }

            HStack(spacing: Space.sm) {
                Button {
                    withAnimation(Anim.quick) {
                        showSetup = false
                        blockerPassword = ""
                        blockerPasswordConfirm = ""
                    }
                } label: {
                    Text("Cancel")
                        .font(TypeScale.caption)
                        .padding(.horizontal, Space.lg)
                        .padding(.vertical, Space.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                        .strokeBorder(Color.sep.opacity(0.12), lineWidth: 0.5)
                                )
                        )
                        .foregroundStyle(.secondary)
                }
                .driftButton(.ghost)
                .accessibilityLabel("Cancel")

                Button(action: startBlocker) {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Start Blocking")
                            .font(TypeScale.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(canStart ? Color.accent : Color.accent.opacity(0.35))
                    )
                    .foregroundStyle(.white)
                }
                .driftButton()
                .disabled(!canStart)
                .accessibilityLabel("Start blocking")
            }
        }
        .padding(Space.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.accent.opacity(0.08), lineWidth: 0.5)
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
                Rectangle()
                    .stroke(Color.distraction.opacity(0.15), lineWidth: 10)
                    .frame(width: 96, height: 96)

                Rectangle()
                    .stroke(Color.distraction.opacity(0.18), lineWidth: 6)
                    .frame(width: 96, height: 96)

                Rectangle()
                    .trim(from: 0, to: min(blocker.progress, 1.0))
                    .stroke(
                        Color.distraction,
                        style: StrokeStyle(lineWidth: 6, lineCap: .butt)
                    )
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: blocker.progress)

                VStack(spacing: 0) {
                    Text(blocker.timeRemainingFormatted)
                        .font(TypeScale.monoSm)
                        .foregroundStyle(Color.distraction)
                        .contentTransition(.numericText())
                        .animation(Anim.count, value: blocker.timeRemainingFormatted)
                    Text("LEFT")
                        .font(TypeScale.tiny)
                        .foregroundStyle(Color.distraction.opacity(0.5))
                        .tracking(1.2)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Blocking timer: \(blocker.timeRemainingFormatted) remaining")

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Shield is active")
                    .font(TypeScale.caption)
                    .foregroundStyle(Color(.labelColor))
                Text("Distracting sites blocked.\nStay in the zone.")
                    .font(TypeScale.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2.5)
            }
            Spacer()
        }
        .padding(Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.distraction.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.distraction.opacity(0.12), lineWidth: 0.5)
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
                                .background(Rectangle().fill(Color.accent))
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
                        Rectangle().fill(
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

private func formatCountdown(_ s: Int) -> String {
    String(format: "%d:%02d", s / 60, s % 60)
}

private func formatStudyTime(_ totalSeconds: Int) -> String {
    if totalSeconds < 60 { return "\(totalSeconds)s" }
    let m = totalSeconds / 60
    if m < 60 { return "\(m)m" }
    return "\(m / 60)h \(m % 60)m"
}
