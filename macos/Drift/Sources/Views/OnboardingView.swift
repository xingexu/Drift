import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    let onComplete: () -> Void
    let onSignIn: () -> Void

    @State private var currentStep = 0
    @State private var appeared = false
    @State private var navigationDirection: NavigationDirection = .forward
    @Namespace private var progressNamespace

    private let steps = OnboardingStep.allSteps

    enum NavigationDirection {
        case forward, backward
    }

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 52)
                    .padding(.horizontal, 60)

                Spacer()

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()

                navigationButtons
                    .padding(.bottom, 48)
                    .padding(.horizontal, 60)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding, step \(currentStep + 1) of \(steps.count)")
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.drift : Color.primary.opacity(0.08))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        if index == currentStep {
                            Capsule()
                                .fill(Color.drift)
                                .matchedGeometryEffect(id: "activeProgress", in: progressNamespace)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep + 1) of \(steps.count): \(steps[currentStep].title)")
        .accessibilityValue("\(Int(Double(currentStep + 1) / Double(steps.count) * 100)) percent complete")
    }

    // MARK: - Step Content

    private var stepContent: some View {
        ZStack {
            switch currentStep {
            case 0: OnboardingWelcomeStep(appeared: $appeared)
            case 1: OnboardingPermissionsStep()
            case 2: OnboardingTrackingStep()
            case 3: OnboardingFocusModeStep()
            case 4: OnboardingReadyStep(onComplete: onComplete, onSignIn: onSignIn)
            default: OnboardingReadyStep(onComplete: onComplete, onSignIn: onSignIn)
            }
        }
        .transition(currentTransition)
        .id(currentStep)
        .accessibilityElement(children: .contain)
    }

    private var currentTransition: AnyTransition {
        switch navigationDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                OnboardingNavButton(
                    label: "Back",
                    icon: "chevron.left",
                    iconPosition: .leading,
                    style: .secondary
                ) {
                    goBack()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .accessibilityLabel("Go back to \(steps[max(0, currentStep - 1)].title)")
            }

            Spacer()

            if currentStep < steps.count - 1 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        onComplete()
                    }
                }) {
                    Text("Skip Tutorial")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .accessibilityLabel("Skip tutorial and start using Drift")
                .accessibilityHint("Skips the remaining onboarding steps")
            }

            if currentStep < steps.count - 1 {
                OnboardingNavButton(
                    label: "Next",
                    icon: "chevron.right",
                    iconPosition: .trailing,
                    style: .primary
                ) {
                    goForward()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .accessibilityLabel("Continue to \(steps[min(steps.count - 1, currentStep + 1)].title)")
            }
        }
    }

    // MARK: - Navigation Actions

    private func goForward() {
        guard currentStep < steps.count - 1 else { return }
        navigationDirection = .forward
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentStep += 1
        }
    }

    private func goBack() {
        guard currentStep > 0 else { return }
        navigationDirection = .backward
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentStep -= 1
        }
    }
}

// MARK: - Animated Background

private struct OnboardingBackground: View {
    @State private var gradientPhase: CGFloat = 0

    var body: some View {
        ZStack {
            Color("Background")

            Circle()
                .fill(RadialGradient(
                    colors: [Color.drift.opacity(0.15), .clear],
                    center: .center, startRadius: 0, endRadius: 250
                ))
                .frame(width: 500, height: 500)
                .offset(x: -180, y: gradientPhase * -60 - 80)
                .blur(radius: 40)

            Circle()
                .fill(RadialGradient(
                    colors: [Color("Green").opacity(0.08), .clear],
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 400, height: 400)
                .offset(x: 200, y: gradientPhase * 50 + 150)
                .blur(radius: 35)

            Circle()
                .fill(RadialGradient(
                    colors: [Color.orange.opacity(0.06), .clear],
                    center: .center, startRadius: 0, endRadius: 180
                ))
                .frame(width: 360, height: 360)
                .offset(x: 100, y: gradientPhase * -40 - 200)
                .blur(radius: 30)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: true)) {
                gradientPhase = 1
            }
        }
    }
}

// MARK: - Step 0: Welcome

private struct OnboardingWelcomeStep: View {
    @Binding var appeared: Bool
    @State private var ringsVisible = false

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.drift.opacity(0.08 - Double(i) * 0.02), lineWidth: 2)
                        .frame(width: CGFloat(120 + i * 40), height: CGFloat(120 + i * 40))
                        .scaleEffect(ringsVisible ? 1 : 0.5)
                        .opacity(ringsVisible ? 1 : 0)
                        .animation(
                            .spring(response: 0.8, dampingFraction: 0.6)
                                .delay(Double(i) * 0.15),
                            value: ringsVisible
                        )
                }

                Image("DriftLogo")
                    .resizable()
                    .interpolation(.high)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.drift.opacity(0.4), radius: 30, y: 10)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .rotationEffect(.degrees(appeared ? 0 : -10))
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: appeared)
                    .accessibilityLabel("Drift app icon")
            }
            .onAppear {
                withAnimation {
                    ringsVisible = true
                }
            }

            VStack(spacing: 16) {
                Text("Welcome to Drift")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-1)
                    .accessibilityAddTraits(.isHeader)

                Text("Your personal focus companion for macOS.\nTrack your time, stay focused, build streaks.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 420)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.easeOut(duration: 0.6).delay(0.3), value: appeared)

            HStack(spacing: 12) {
                OnboardingBadge(icon: "eye.tracking.circle", text: "Auto Tracking", color: Color.drift)
                OnboardingBadge(icon: "timer", text: "Pomodoro", color: Color("Green"))
                OnboardingBadge(icon: "shield.fill", text: "Focus Blocker", color: .orange)
                OnboardingBadge(icon: "chart.bar.fill", text: "Analytics", color: .purple)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.easeOut(duration: 0.6).delay(0.5), value: appeared)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Features: Auto Tracking, Pomodoro, Focus Blocker, Analytics")
        }
    }
}

// MARK: - Step 1: Permissions

private struct OnboardingPermissionsStep: View {
    @State private var permissionGranted = false
    @State private var permissionCheckTimer: Timer?
    @State private var hasCheckedOnce = false

    var body: some View {
        VStack(spacing: 36) {
            permissionIllustration

            VStack(spacing: 16) {
                Text("Grant Accessibility Access")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)

                Text("Drift needs accessibility access to detect which app\nyou're using. Your data never leaves your Mac.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 440)
            }

            HStack(spacing: 20) {
                PrivacyBadge(icon: "lock.fill", text: "Local Only")
                PrivacyBadge(icon: "hand.raised.fill", text: "No Keylogging")
                PrivacyBadge(icon: "eye.slash.fill", text: "No Screenshots")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Privacy guarantees: Data stays local, no keylogging, no screenshots")

            if permissionGranted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color("Green"))
                    Text("Accessibility access granted")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color("Green"))
                }
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Accessibility access has been granted")
            } else {
                OnboardingActionButton(
                    label: "Open System Settings",
                    icon: "gear",
                    action: requestAccessibility
                )
                .accessibilityHint("Opens System Settings to the Privacy and Security section")
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: permissionGranted)
        .onAppear {
            checkAccessibilityStatus()
            startPollingPermission()
        }
        .onDisappear {
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
        }
    }

    private var permissionIllustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primary.opacity(0.03))
                .frame(width: 320, height: 200)

            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.drift)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility Access")
                                .font(.system(size: 14, weight: .semibold))
                            Text("System Settings > Privacy")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    HStack {
                        HStack(spacing: 8) {
                            Image("DriftLogo")
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 20, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text("Drift")
                                .font(.system(size: 12, weight: .medium))
                        }
                        Spacer()
                        ZStack {
                            Capsule()
                                .fill(permissionGranted ? Color("Green") : Color.primary.opacity(0.1))
                                .frame(width: 36, height: 20)
                            Circle()
                                .fill(.white)
                                .frame(width: 16, height: 16)
                                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                                .offset(x: permissionGranted ? 8 : -8)
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: permissionGranted)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.controlBackgroundColor))
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                )
                .frame(maxWidth: 260)
            }
        }
        .accessibilityHidden(true)
    }

    private func requestAccessibility() {
        // Use takeUnretainedValue for the constant key -- it is not an owned reference
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        hasCheckedOnce = true
    }

    private func checkAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        if trusted != permissionGranted {
            withAnimation {
                permissionGranted = trusted
            }
        }
    }

    private func startPollingPermission() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            Task { @MainActor in
                checkAccessibilityStatus()
            }
        }
    }
}

// MARK: - Step 2: Tracking Demo

private struct OnboardingTrackingStep: View {
    @State private var trackingDemoPhase: Int = 0
    @State private var animationTask: Task<Void, Never>?

    private let demoApps: [(name: String, category: String, color: Color)] = [
        ("Xcode", "Productive", Color("Green")),
        ("Safari - Twitter", "Distraction", Color("Red")),
        ("Slack", "Productive", Color("Green")),
        ("Spotify", "Distraction", Color("Red")),
        ("Terminal", "Productive", Color("Green")),
    ]

    var body: some View {
        VStack(spacing: 36) {
            trackingDemoCard

            VStack(spacing: 16) {
                Text("Automatic App Tracking")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)

                Text("Drift watches which apps you use and classifies them\nautomatically. Productive, neutral, or distraction.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 440)
            }

            HStack(spacing: 24) {
                CategoryLegend(color: Color("Green"), label: "Productive", examples: "Xcode, VSCode, Figma")
                CategoryLegend(color: .secondary, label: "Neutral", examples: "Finder, System Settings")
                CategoryLegend(color: Color("Red"), label: "Distraction", examples: "Twitter, YouTube, TikTok")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Categories: Productive apps like Xcode. Neutral apps like Finder. Distractions like Twitter.")
        }
        .onAppear { startDemoAnimation() }
        .onDisappear { animationTask?.cancel() }
    }

    private var trackingDemoCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(Color.red.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(Color.orange.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(Color.green.opacity(0.8)).frame(width: 8, height: 8)
                Spacer()
                Text("Drift - Session")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer()
                Color.clear.frame(width: 30)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))

            VStack(spacing: 8) {
                ForEach(0..<min(trackingDemoPhase, demoApps.count), id: \.self) { i in
                    let app = demoApps[i]
                    HStack(spacing: 10) {
                        Circle()
                            .fill(app.color)
                            .frame(width: 6, height: 6)
                            .shadow(color: app.color.opacity(0.5), radius: 3)

                        Text(app.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)

                        Spacer()

                        Text(app.category)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(app.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(app.color.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if trackingDemoPhase == 0 {
                    HStack {
                        Text("Waiting for activity...")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 20)
                }
            }
            .padding(12)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: trackingDemoPhase)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .frame(maxWidth: 340)
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Demo showing apps being tracked: Xcode as productive, Safari Twitter as distraction, Slack as productive")
    }

    private func startDemoAnimation() {
        trackingDemoPhase = 0
        animationTask = Task { @MainActor in
            for i in 1...5 {
                try? await Task.sleep(nanoseconds: UInt64(i) * 600_000_000)
                guard !Task.isCancelled else { return }
                withAnimation {
                    trackingDemoPhase = i
                }
            }
        }
    }
}

// MARK: - Step 3: Focus Mode

private struct OnboardingFocusModeStep: View {
    @State private var focusTimerValue: CGFloat = 0

    var body: some View {
        VStack(spacing: 36) {
            HStack(spacing: 24) {
                focusTimerRing

                blockedSitesPreview
            }
            .frame(maxWidth: 420)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0)) {
                    focusTimerValue = 0.82
                }
            }

            VStack(spacing: 16) {
                Text("Focus Mode & Blocker")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)

                Text("Pomodoro timer with built-in website blocking.\nSet a password to prevent early stopping.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 440)
            }

            HStack(spacing: 12) {
                FeaturePill(icon: "timer", text: "Customizable Intervals")
                FeaturePill(icon: "lock.fill", text: "Password Lock")
                FeaturePill(icon: "bell.fill", text: "Notifications")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Features: Customizable intervals, password lock, and notifications")
        }
    }

    private var focusTimerRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.separatorColor).opacity(0.3), lineWidth: 6)
                .frame(width: 140, height: 140)

            Circle()
                .trim(from: 0, to: focusTimerValue)
                .stroke(
                    AngularGradient(
                        colors: [Color.drift.opacity(0.5), Color.drift],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text("24:38")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                Text("FOCUS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.drift)
                    .tracking(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus timer showing 24 minutes 38 seconds remaining, 82 percent complete")
    }

    private var blockedSitesPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.drift)
                Text("Blocked Sites")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                ForEach(["twitter.com", "reddit.com", "youtube.com", "instagram.com"], id: \.self) { site in
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color("Red").opacity(0.6))
                        Text(site)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color("Red").opacity(0.04)))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Blocked sites list: twitter, reddit, youtube, instagram")
    }
}

// MARK: - Step 4: Ready

private struct OnboardingReadyStep: View {
    let onComplete: () -> Void
    let onSignIn: () -> Void

    @State private var confettiVisible = false
    @State private var checkScale: CGFloat = 0

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                if confettiVisible {
                    ForEach(0..<20, id: \.self) { i in
                        ConfettiParticle(index: i)
                    }
                }

                ZStack {
                    Circle()
                        .fill(Color("Green").opacity(0.1))
                        .frame(width: 100, height: 100)

                    Circle()
                        .fill(Color("Green").opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color("Green"))
                        .scaleEffect(checkScale)
                }
            }
            .frame(height: 140)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2)) {
                    checkScale = 1
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    withAnimation { confettiVisible = true }
                }
            }

            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-1)
                    .accessibilityAddTraits(.isHeader)

                Text("Drift is ready to help you focus.\nStart tracking and build your productivity streaks.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 440)
            }

            VStack(spacing: 14) {
                PressableButton(action: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        onComplete()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Start Your First Session")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.drift)
                    )
                    .shadow(color: Color.drift.opacity(0.3), radius: 16, y: 6)
                }
                .accessibilityLabel("Start your first focus session")
                .keyboardShortcut(.return, modifiers: [])

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        onSignIn()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Have an account?")
                            .foregroundStyle(.tertiary)
                        Text("Sign in to sync")
                            .foregroundStyle(Color.drift)
                            .fontWeight(.medium)
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sign in to sync your data across devices")
            }
        }
    }
}

// MARK: - Data Model

struct OnboardingStep {
    let title: String
    let icon: String

    static let allSteps: [OnboardingStep] = [
        OnboardingStep(title: "Welcome", icon: "hand.wave"),
        OnboardingStep(title: "Permissions", icon: "lock.shield"),
        OnboardingStep(title: "Tracking", icon: "eye.tracking.circle"),
        OnboardingStep(title: "Focus Mode", icon: "shield.fill"),
        OnboardingStep(title: "Ready", icon: "checkmark.circle"),
    ]
}

// MARK: - Reusable Components

/// A button with a satisfying press-scale effect.
private struct PressableButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            label()
                .scaleEffect(isPressed ? 0.96 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// Navigation button used in the onboarding footer.
private struct OnboardingNavButton: View {
    let label: String
    let icon: String
    let iconPosition: IconPosition
    let style: Style
    let action: () -> Void

    @State private var isPressed = false

    enum IconPosition { case leading, trailing }
    enum Style { case primary, secondary }

    var body: some View {
        Button(action: action) {
            HStack(spacing: iconPosition == .leading ? 4 : 6) {
                if iconPosition == .leading {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: style == .primary ? 14 : 13, weight: style == .primary ? .semibold : .medium))
                if iconPosition == .trailing {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(style == .primary ? .white : .secondary)
            .padding(.horizontal, style == .primary ? 28 : 16)
            .padding(.vertical, style == .primary ? 11 : 10)
            .background {
                if style == .primary {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.drift)
                        .shadow(color: Color.drift.opacity(0.25), radius: 8, y: 4)
                }
            }
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// Inline action button for permission-granting, etc.
private struct OnboardingActionButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.06))
            )
            .foregroundStyle(.primary)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

private struct OnboardingBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(color.opacity(0.08))
                .overlay(Capsule().stroke(color.opacity(0.12), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }
}

private struct PrivacyBadge: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color("Green"))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 100)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color("Green").opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color("Green").opacity(0.1), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

private struct CategoryLegend: View {
    let color: Color
    let label: String
    let examples: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(examples)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.drift)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.drift.opacity(0.06))
                .overlay(Capsule().stroke(Color.drift.opacity(0.1), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }
}

/// Confetti particle with deterministic initial values to avoid re-randomizing on redraws.
private struct ConfettiParticle: View {
    let index: Int

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 1
    @State private var rotation: Double = 0

    private static let colors: [Color] = [Color.drift, Color("Green"), .orange, .purple, .pink, .yellow]

    // Pre-computed deterministic values based on index to avoid body-level randomness
    private var particleColor: Color {
        Self.colors[index % Self.colors.count]
    }

    private var particleSize: CGFloat {
        CGFloat(4 + (index * 3) % 5)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particleColor)
            .frame(width: particleSize, height: particleSize)
            .rotationEffect(.degrees(rotation))
            .offset(x: position.x, y: position.y)
            .opacity(opacity)
            .accessibilityHidden(true)
            .onAppear {
                // Seeded pseudo-random from index for deterministic but varied output
                let seed = Double(index)
                let angle = (seed * 137.508).truncatingRemainder(dividingBy: 360) * .pi / 180
                let distance = CGFloat(60 + (index * 17) % 80)
                let duration = 1.0 + Double((index * 7) % 10) / 10.0

                withAnimation(.easeOut(duration: duration)) {
                    position = CGPoint(
                        x: cos(angle) * distance,
                        y: sin(angle) * distance - 40
                    )
                    rotation = Double((index * 47) % 720) - 360
                    opacity = 0
                }
            }
    }
}
