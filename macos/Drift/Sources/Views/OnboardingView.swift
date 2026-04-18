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
            Color("Background")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top progress area
                VStack(spacing: Space.md) {
                    stepDots
                    progressCapsule
                }
                .padding(.top, Space.xxxl + Space.xl)
                .padding(.horizontal, Space.xxxl + Space.page)

                Spacer()

                // Centered step card column
                stepContent
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)

                Spacer()
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding, step \(currentStep + 1) of \(steps.count)")
        .onAppear {
            withAnimation(Anim.appear) {
                appeared = true
            }
        }
    }

    // MARK: - Step Dots

    private var stepDots: some View {
        HStack(spacing: Space.sm) {
            ForEach(0..<steps.count, id: \.self) { index in
                let isActive = index == currentStep
                let isPast = index < currentStep
                ZStack {
                    Circle()
                        .fill(isActive ? Color.accent : (isPast ? Color.accent.opacity(0.4) : Color.primary.opacity(0.08)))
                        .frame(width: isActive ? 8 : 6, height: isActive ? 8 : 6)
                    if isActive {
                        Circle()
                            .stroke(Color.accent.opacity(0.25), lineWidth: 2)
                            .frame(width: 14, height: 14)
                            .matchedGeometryEffect(id: "activeDotRing", in: progressNamespace)
                    }
                }
                .animation(Anim.page, value: currentStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep + 1) of \(steps.count)")
    }

    // MARK: - Progress Capsule

    private var progressCapsule: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 3)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.accent.opacity(0.7), Color.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(steps.count),
                        height: 3
                    )
                    .animation(Anim.page, value: currentStep)
            }
        }
        .frame(height: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int(Double(currentStep + 1) / Double(steps.count) * 100)) percent complete")
    }

    // MARK: - Step Content

    private var stepContent: some View {
        ZStack {
            switch currentStep {
            case 0: OnboardingWelcomeStep(
                appeared: $appeared,
                onContinue: goForward,
                onSkip: { withAnimation(Anim.page) { onComplete() } }
            )
            case 1: OnboardingPermissionsStep(
                onContinue: goForward,
                onBack: goBack,
                onSkip: { withAnimation(Anim.page) { onComplete() } }
            )
            case 2: OnboardingTrackingStep(
                onContinue: goForward,
                onBack: goBack,
                onSkip: { withAnimation(Anim.page) { onComplete() } }
            )
            case 3: OnboardingFocusModeStep(
                onContinue: goForward,
                onBack: goBack,
                onSkip: { withAnimation(Anim.page) { onComplete() } }
            )
            case 4: OnboardingReadyStep(
                onComplete: onComplete,
                onSignIn: onSignIn,
                onBack: goBack
            )
            default: OnboardingReadyStep(
                onComplete: onComplete,
                onSignIn: onSignIn,
                onBack: goBack
            )
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

    // MARK: - Navigation Actions

    private func goForward() {
        guard currentStep < steps.count - 1 else { return }
        navigationDirection = .forward
        withAnimation(Anim.page) {
            currentStep += 1
        }
    }

    private func goBack() {
        guard currentStep > 0 else { return }
        navigationDirection = .backward
        withAnimation(Anim.page) {
            currentStep -= 1
        }
    }
}

// MARK: - Step Card Shell

/// Shared chrome: icon badge + title/description + step-specific content + nav buttons.
private struct StepCard<Content: View>: View {
    let stepIndex: Int
    let totalSteps: Int
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isLastStep: Bool
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    let onSkip: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @State private var iconPulsing = false

    var body: some View {
        VStack(spacing: Space.xxxl) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.10))
                    .frame(width: 80, height: 80)
                Circle()
                    .stroke(iconColor.opacity(iconPulsing ? 0.0 : 0.18), lineWidth: 1)
                    .frame(width: 80, height: 80)
                    .scaleEffect(iconPulsing ? 1.25 : 1.0)
                    .opacity(iconPulsing ? 0 : 1)
                    .animation(Anim.breathe, value: iconPulsing)
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(iconColor)
            }
            .shadow(color: iconColor.opacity(0.22), radius: 20, x: 0, y: 6)
            .onAppear { iconPulsing = true }
            .accessibilityHidden(true)

            // Title + description
            VStack(spacing: Space.md) {
                Text(title)
                    .font(TypeScale.h2)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(description)
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 400)
            }

            // Step-specific content
            content()

            // Navigation buttons
            VStack(spacing: Space.sm) {
                HStack(spacing: Space.md) {
                    if let onBack = onBack {
                        SecondaryButton("Back", icon: "chevron.left") {
                            onBack()
                        }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                        .accessibilityLabel("Go back to previous step")
                    }

                    PrimaryButton(
                        isLastStep ? "Get Started" : "Continue",
                        icon: isLastStep ? "play.fill" : "chevron.right",
                        isFullWidth: true
                    ) {
                        onContinue()
                    }
                    .keyboardShortcut(isLastStep ? .return : .rightArrow, modifiers: [])
                }

                if let onSkip = onSkip {
                    Button(action: onSkip) {
                        Text("Skip Tutorial")
                            .font(TypeScale.bodyMd)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skip tutorial and start using Drift")
                    .accessibilityHint("Skips remaining onboarding steps")
                }
            }
        }
        .padding(.horizontal, Space.xxxl)
        .padding(.bottom, Space.xxxl + Space.lg)
    }
}

// MARK: - Step 0: Welcome

private struct OnboardingWelcomeStep: View {
    @Binding var appeared: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: Space.xxxl) {
            // App icon with glow
            ZStack {
                Circle()
                    .fill(Color.accent.opacity(0.12))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                Image("DriftLogo")
                    .resizable()
                    .interpolation(.high)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg + 6, style: .continuous))
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.accent.opacity(0.25), radius: 20, y: 6)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            }
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
            .animation(Anim.appear, value: appeared)
            .accessibilityLabel("Drift app icon")

            VStack(spacing: Space.md) {
                Text("Welcome to Drift")
                    .font(TypeScale.h1)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Your personal focus companion for macOS.\nTrack your time, stay focused, build streaks.")
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 400)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(Anim.appear.delay(0.12), value: appeared)

            // Feature badges
            HStack(spacing: Space.sm) {
                OnboardingBadge(icon: "eye.tracking.circle", text: "Auto Tracking", color: Color.accent)
                OnboardingBadge(icon: "timer", text: "Pomodoro", color: Color.productive)
                OnboardingBadge(icon: "shield.fill", text: "Focus Blocker", color: Color.streak)
                OnboardingBadge(icon: "chart.bar.fill", text: "Analytics", color: .purple)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(Anim.appear.delay(0.25), value: appeared)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Features: Auto Tracking, Pomodoro, Focus Blocker, Analytics")

            // Navigation
            VStack(spacing: Space.sm) {
                PrimaryButton("Continue", icon: "chevron.right", isFullWidth: true) {
                    onContinue()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .opacity(appeared ? 1 : 0)
                .animation(Anim.appear.delay(0.38), value: appeared)

                Button(action: onSkip) {
                    Text("Skip Tutorial")
                        .font(TypeScale.bodyMd)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .animation(Anim.appear.delay(0.45), value: appeared)
                .accessibilityLabel("Skip tutorial and start using Drift")
            }
        }
        .padding(.horizontal, Space.xxxl)
        .padding(.bottom, Space.xxxl + Space.lg)
    }
}

// MARK: - Step 1: Permissions

private struct OnboardingPermissionsStep: View {
    let onContinue: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    @State private var permissionGranted = false
    @State private var permissionCheckTimer: Timer?
    @State private var hasCheckedOnce = false
    @State private var privacyExpanded = false

    var body: some View {
        StepCard(
            stepIndex: 1,
            totalSteps: 5,
            icon: "lock.shield.fill",
            iconColor: Color.accent,
            title: "Grant Accessibility Access",
            description: "Drift needs accessibility access to detect which app you're using. Your data never leaves your Mac.",
            isLastStep: false,
            onContinue: onContinue,
            onBack: onBack,
            onSkip: onSkip
        ) {
            VStack(spacing: Space.lg) {
                // Permission toggle mock card
                permissionCard

                // Privacy guarantees
                HStack(spacing: Space.md) {
                    PrivacyBadge(icon: "lock.fill", text: "Local Only")
                    PrivacyBadge(icon: "hand.raised.fill", text: "No Keylogging")
                    PrivacyBadge(icon: "eye.slash.fill", text: "No Screenshots")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Privacy: local only, no keylogging, no screenshots")

                // Grant / granted button
                if permissionGranted {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.productive)
                        Text("Accessibility access granted")
                            .font(TypeScale.bodyMd)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.productive)
                    }
                    .padding(.vertical, Space.sm)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .accessibilityLabel("Accessibility access has been granted")
                } else {
                    OnboardingActionButton(
                        label: "Open System Settings",
                        icon: "gear",
                        action: requestAccessibility
                    )
                    .transition(.opacity)
                    .accessibilityHint("Opens System Settings to the Privacy and Security section")
                }

                // Why we need this — expandable
                DisclosureGroup(isExpanded: $privacyExpanded) {
                    Text("Drift uses accessibility APIs to observe the frontmost application name only — never your keystrokes, screen content, or file data. This is the same API used by productivity tools like Timing and RescueTime.")
                        .font(TypeScale.bodySm)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .padding(.top, Space.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("Why we need this")
                        .font(TypeScale.bodyMd)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accent)
                }
                .frame(maxWidth: 380)
            }
        }
        .animation(Anim.page, value: permissionGranted)
        .onAppear {
            checkAccessibilityStatus()
            startPollingPermission()
        }
        .onDisappear {
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
        }
    }

    private var permissionCard: some View {
        VStack(spacing: Space.sm) {
            HStack(spacing: Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.accent.opacity(0.10))
                        .frame(width: 34, height: 34)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.accent)
                }
                VStack(alignment: .leading, spacing: Space.xxxs) {
                    Text("Accessibility Access")
                        .font(TypeScale.bodyMd)
                        .fontWeight(.semibold)
                    Text("System Settings > Privacy & Security")
                        .font(TypeScale.bodySm)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            DriftDivider()

            HStack {
                HStack(spacing: Space.sm) {
                    Image("DriftLogo")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
                    Text("Drift")
                        .font(TypeScale.bodyMd)
                        .fontWeight(.medium)
                }
                Spacer()
                // Toggle visualization
                ZStack {
                    Capsule()
                        .fill(permissionGranted ? Color.productive : Color.primary.opacity(0.10))
                        .frame(width: 38, height: 22)
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                        .offset(x: permissionGranted ? 8 : -8)
                        .animation(Anim.tap, value: permissionGranted)
                }
                .accessibilityLabel(permissionGranted ? "Access granted" : "Access not granted")
            }
        }
        .driftCard()
        .frame(maxWidth: 380)
        .accessibilityElement(children: .contain)
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        hasCheckedOnce = true
    }

    private func checkAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        if trusted != permissionGranted {
            withAnimation(Anim.appear) {
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
    let onContinue: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    @State private var trackingDemoPhase: Int = 0
    @State private var animationTask: Task<Void, Never>?

    private let demoApps: [(name: String, category: String, color: Color)] = [
        ("Xcode", "Productive", Color.productive),
        ("Safari — Twitter", "Distraction", Color.distraction),
        ("Slack", "Productive", Color.productive),
        ("Spotify", "Distraction", Color.distraction),
        ("Terminal", "Productive", Color.productive),
    ]

    var body: some View {
        StepCard(
            stepIndex: 2,
            totalSteps: 5,
            icon: "eye.tracking.circle",
            iconColor: Color.accent,
            title: "Automatic App Tracking",
            description: "Drift watches which apps you use and classifies them automatically — productive, neutral, or distraction.",
            isLastStep: false,
            onContinue: onContinue,
            onBack: onBack,
            onSkip: onSkip
        ) {
            VStack(spacing: Space.lg) {
                trackingDemoCard

                HStack(spacing: Space.xxl) {
                    CategoryLegend(color: Color.productive, label: "Productive", examples: "Xcode, VSCode, Figma")
                    CategoryLegend(color: .secondary, label: "Neutral", examples: "Finder, Settings")
                    CategoryLegend(color: Color.distraction, label: "Distraction", examples: "Twitter, YouTube")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Categories: Productive apps like Xcode. Neutral apps like Finder. Distractions like Twitter.")
            }
        }
        .onAppear { startDemoAnimation() }
        .onDisappear { animationTask?.cancel() }
    }

    private var trackingDemoCard: some View {
        VStack(spacing: 0) {
            // Mock window chrome
            HStack(spacing: Space.xs) {
                Circle().fill(Color.red.opacity(0.75)).frame(width: 8, height: 8)
                Circle().fill(Color.orange.opacity(0.75)).frame(width: 8, height: 8)
                Circle().fill(Color.green.opacity(0.75)).frame(width: 8, height: 8)
                Spacer()
                HStack(spacing: Space.xxs) {
                    StatusDot(status: trackingDemoPhase > 0 ? .tracking : .idle)
                    Text("Drift — Live Session")
                        .font(TypeScale.tiny)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Color.clear.frame(width: 30)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Color.primary.opacity(0.03))

            DriftDivider()

            VStack(spacing: Space.xs) {
                if trackingDemoPhase == 0 {
                    HStack {
                        Image(systemName: "clock")
                            .font(TypeScale.bodySm)
                            .foregroundStyle(.tertiary)
                        Text("Waiting for activity…")
                            .font(TypeScale.bodySm)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, Space.xl)
                    .transition(.opacity)
                }

                ForEach(0..<min(trackingDemoPhase, demoApps.count), id: \.self) { i in
                    let app = demoApps[i]
                    HStack(spacing: Space.md) {
                        Circle()
                            .fill(app.color)
                            .frame(width: 6, height: 6)

                        Text(app.name)
                            .font(TypeScale.bodyMd)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Spacer()

                        DriftTag(text: app.category, color: app.color)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.xs)
                    .background(
                        i == min(trackingDemoPhase, demoApps.count) - 1
                            ? app.color.opacity(0.05)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.vertical, Space.sm)
            .animation(Anim.appear, value: trackingDemoPhase)
        }
        .driftCard(padding: 0)
        .frame(maxWidth: 360)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Demo: Xcode is productive, Safari Twitter is distraction, Slack is productive")
    }

    private func startDemoAnimation() {
        trackingDemoPhase = 0
        animationTask = Task { @MainActor in
            for i in 1...5 {
                try? await Task.sleep(nanoseconds: UInt64(i) * 600_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(Anim.appear) {
                    trackingDemoPhase = i
                }
            }
        }
    }
}

// MARK: - Step 3: Focus Mode

private struct OnboardingFocusModeStep: View {
    let onContinue: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    @State private var focusTimerValue: CGFloat = 0

    var body: some View {
        StepCard(
            stepIndex: 3,
            totalSteps: 5,
            icon: "shield.fill",
            iconColor: Color.streak,
            title: "Focus Mode & Blocker",
            description: "Pomodoro timer with built-in website blocking. Set a password to prevent early stopping.",
            isLastStep: false,
            onContinue: onContinue,
            onBack: onBack,
            onSkip: onSkip
        ) {
            VStack(spacing: Space.xl) {
                HStack(alignment: .top, spacing: Space.xxl) {
                    focusTimerRing
                    blockedSitesPreview
                }
                .frame(maxWidth: 400)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0)) {
                        focusTimerValue = 0.82
                    }
                }

                HStack(spacing: Space.md) {
                    FeaturePill(icon: "timer", text: "Custom Intervals")
                    FeaturePill(icon: "lock.fill", text: "Password Lock")
                    FeaturePill(icon: "bell.fill", text: "Notifications")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Features: custom intervals, password lock, notifications")
            }
        }
    }

    private var focusTimerRing: some View {
        ZStack {
            Circle()
                .stroke(Color.sep.opacity(0.25), lineWidth: 6)
                .frame(width: 130, height: 130)

            Circle()
                .trim(from: 0, to: focusTimerValue)
                .stroke(
                    AngularGradient(
                        colors: [Color.streak.opacity(0.5), Color.streak],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(-90))

            VStack(spacing: Space.xxxs) {
                Text("24:38")
                    .font(TypeScale.monoLg)
                    .minimumScaleFactor(0.7)
                Text("FOCUS")
                    .font(TypeScale.tiny)
                    .foregroundStyle(Color.streak)
                    .tracking(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus timer: 24 minutes 38 seconds remaining, 82 percent complete")
    }

    private var blockedSitesPreview: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accent)
                Text("BLOCKED")
                    .sectionLabel()
            }

            VStack(alignment: .leading, spacing: Space.xxs) {
                ForEach(["twitter.com", "reddit.com", "youtube.com", "instagram.com"], id: \.self) { site in
                    HStack(spacing: Space.xs) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.distraction.opacity(0.55))
                        Text(site)
                            .font(TypeScale.bodySm)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, Space.xxs)
                    .padding(.horizontal, Space.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                            .fill(Color.distraction.opacity(0.04))
                    )
                }
            }
        }
        .driftCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Blocked sites: twitter, reddit, youtube, instagram")
    }
}

// MARK: - Step 4: Ready

private struct OnboardingReadyStep: View {
    let onComplete: () -> Void
    let onSignIn: () -> Void
    let onBack: () -> Void

    @State private var checkScale: CGFloat = 0
    @State private var glowPulsing = false
    @State private var statsAppeared = false

    var body: some View {
        VStack(spacing: Space.xxxl) {
            // Celebration icon with glow
            ZStack {
                Circle()
                    .fill(Color.productive.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .scaleEffect(glowPulsing ? 1.12 : 1.0)
                    .opacity(glowPulsing ? 0.6 : 1.0)
                    .animation(Anim.breathe, value: glowPulsing)

                Circle()
                    .fill(Color.productive.opacity(0.12))
                    .frame(width: 90, height: 90)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(Color.productive)
                    .scaleEffect(checkScale)
                    .animation(Anim.appear.delay(0.15), value: checkScale)
            }
            .shadow(color: Color.productive.opacity(0.25), radius: 24, y: 8)
            .accessibilityHidden(true)
            .onAppear {
                checkScale = 1
                glowPulsing = true
                withAnimation(Anim.appear.delay(0.4)) {
                    statsAppeared = true
                }
            }

            VStack(spacing: Space.md) {
                Text("You're All Set!")
                    .font(TypeScale.h1)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Drift is ready to help you focus.\nStart tracking and build your productivity streaks.")
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 400)
            }

            // Quick preview stats card
            quickPreviewCard

            // CTA buttons
            VStack(spacing: Space.sm) {
                // Back
                HStack(spacing: Space.md) {
                    SecondaryButton("Back", icon: "chevron.left") {
                        onBack()
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])

                    PrimaryButton("Start Tracking", icon: "play.fill", color: Color.productive, isFullWidth: true) {
                        withAnimation(Anim.page) {
                            onComplete()
                        }
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .accessibilityLabel("Start your first focus session")
                }

                Button(action: {
                    withAnimation(Anim.page) {
                        onSignIn()
                    }
                }) {
                    HStack(spacing: Space.xxs) {
                        Text("Have an account?")
                            .foregroundStyle(.tertiary)
                        Text("Sign in to sync")
                            .foregroundStyle(Color.accent)
                            .fontWeight(.medium)
                    }
                    .font(TypeScale.bodyMd)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sign in to sync your data across devices")
            }
        }
        .padding(.horizontal, Space.xxxl)
        .padding(.bottom, Space.xxxl + Space.lg)
    }

    private var quickPreviewCard: some View {
        HStack(spacing: 0) {
            previewStat(
                icon: "timer",
                iconColor: Color.accent,
                value: "25 min",
                label: "Focus session"
            )

            DriftDivider()
                .frame(width: 0.5, height: 44)

            previewStat(
                icon: "flame.fill",
                iconColor: Color.streak,
                value: "0 day",
                label: "Streak"
            )

            DriftDivider()
                .frame(width: 0.5, height: 44)

            previewStat(
                icon: "chart.bar.fill",
                iconColor: Color.productive,
                value: "0%",
                label: "Focus score"
            )
        }
        .driftCard()
        .frame(maxWidth: 380)
        .opacity(statsAppeared ? 1 : 0)
        .offset(y: statsAppeared ? 0 : 10)
        .animation(Anim.appear.delay(0.4), value: statsAppeared)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Starting stats: 25 minute focus session, 0 day streak, 0 percent focus score")
    }

    @ViewBuilder
    private func previewStat(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: Space.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
            Text(value)
                .font(TypeScale.monoMd)
                .fontWeight(.semibold)
            Text(label)
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Data Model

struct OnboardingStep {
    let title: String
    let icon: String

    static let allSteps: [OnboardingStep] = [
        OnboardingStep(title: "Welcome",     icon: "hand.wave"),
        OnboardingStep(title: "Permissions", icon: "lock.shield"),
        OnboardingStep(title: "Tracking",    icon: "eye.tracking.circle"),
        OnboardingStep(title: "Focus Mode",  icon: "shield.fill"),
        OnboardingStep(title: "Ready",       icon: "checkmark.circle"),
    ]
}

// MARK: - Reusable Components

/// Inline action button for permission-granting, etc.
private struct OnboardingActionButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Image(systemName: icon)
                    .font(TypeScale.bodyMd)
                Text(label)
                    .font(TypeScale.heading)
            }
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(Color.border, lineWidth: 0.75)
                    )
            )
            .foregroundStyle(.primary)
        }
        .driftButton(.secondary)
    }
}

private struct OnboardingBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: icon)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
            Text(text)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs + 1)
        .background(
            Capsule()
                .fill(color.opacity(0.08))
                .overlay(Capsule().stroke(color.opacity(0.14), lineWidth: 0.75))
        )
        .accessibilityElement(children: .combine)
    }
}

private struct PrivacyBadge: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.productive)
            Text(text)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.productive.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.productive.opacity(0.10), lineWidth: 0.75)
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
        VStack(spacing: Space.xs) {
            HStack(spacing: Space.xxs + 1) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(TypeScale.caption)
                    .fontWeight(.semibold)
            }
            Text(examples)
                .font(TypeScale.tiny)
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
        HStack(spacing: Space.xs) {
            Image(systemName: icon)
                .font(TypeScale.tiny)
                .fontWeight(.medium)
                .foregroundStyle(Color.accent)
            Text(text)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(
            Capsule()
                .fill(Color.accent.opacity(0.06))
                .overlay(Capsule().stroke(Color.accent.opacity(0.10), lineWidth: 0.75))
        )
        .accessibilityElement(children: .combine)
    }
}
