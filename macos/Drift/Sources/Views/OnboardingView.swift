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
                progressBar
                    .padding(.top, Space.xxxl + Space.xl)
                    .padding(.horizontal, Space.xxxl + Space.page)

                Spacer()

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()

                navigationButtons
                    .padding(.bottom, Space.xxxl + Space.lg)
                    .padding(.horizontal, Space.xxxl + Space.page)
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

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: Space.xs) {
            ForEach(0..<steps.count, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.accent : Color.primary.opacity(0.08))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        if index == currentStep {
                            Capsule()
                                .fill(Color.accent)
                                .matchedGeometryEffect(id: "activeProgress", in: progressNamespace)
                        }
                    }
                    .animation(Anim.page, value: currentStep)
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
                    withAnimation(Anim.page) {
                        onComplete()
                    }
                }) {
                    Text("Skip Tutorial")
                        .font(TypeScale.body)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .driftButton(.ghost)
                .padding(.trailing, Space.lg)
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

// MARK: - Step 0: Welcome

private struct OnboardingWelcomeStep: View {
    @Binding var appeared: Bool

    var body: some View {
        VStack(spacing: Space.xxxl) {
            Image("DriftLogo")
                .resizable()
                .interpolation(.high)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg + 6, style: .continuous))
                .frame(width: 88, height: 88)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 6)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
                .animation(Anim.appear, value: appeared)
                .accessibilityLabel("Drift app icon")

            VStack(spacing: Space.lg) {
                Text("Welcome to Drift")
                    .font(TypeScale.hero)
                    .accessibilityAddTraits(.isHeader)

                Text("Your personal focus companion for macOS.\nTrack your time, stay focused, build streaks.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 420)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(Anim.appear.delay(0.15), value: appeared)

            HStack(spacing: Space.md) {
                OnboardingBadge(icon: "eye.tracking.circle", text: "Auto Tracking", color: .accent)
                OnboardingBadge(icon: "timer", text: "Pomodoro", color: .productive)
                OnboardingBadge(icon: "shield.fill", text: "Focus Blocker", color: .streak)
                OnboardingBadge(icon: "chart.bar.fill", text: "Analytics", color: .purple)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(Anim.appear.delay(0.3), value: appeared)
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
        VStack(spacing: Space.xxxl + Space.xxs) {
            permissionIllustration

            VStack(spacing: Space.lg) {
                Text("Grant Accessibility Access")
                    .font(TypeScale.hero)
                    .accessibilityAddTraits(.isHeader)

                Text("Drift needs accessibility access to detect which app\nyou're using. Your data never leaves your Mac.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 440)
            }

            HStack(spacing: Space.xl) {
                PrivacyBadge(icon: "lock.fill", text: "Local Only")
                PrivacyBadge(icon: "hand.raised.fill", text: "No Keylogging")
                PrivacyBadge(icon: "eye.slash.fill", text: "No Screenshots")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Privacy guarantees: Data stays local, no keylogging, no screenshots")

            if permissionGranted {
                HStack(spacing: Space.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.productive)
                    Text("Accessibility access granted")
                        .font(TypeScale.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.productive)
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

    private var permissionIllustration: some View {
        VStack(spacing: Space.lg) {
            VStack(spacing: Space.md) {
                HStack(spacing: Space.md) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.accent)
                    VStack(alignment: .leading, spacing: Space.xxxs) {
                        Text("Accessibility Access")
                            .font(TypeScale.body)
                            .fontWeight(.semibold)
                        Text("System Settings > Privacy")
                            .font(TypeScale.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack {
                    HStack(spacing: Space.sm) {
                        Image("DriftLogo")
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        Text("Drift")
                            .font(TypeScale.body)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    ZStack {
                        Capsule()
                            .fill(permissionGranted ? Color.productive : Color.primary.opacity(0.1))
                            .frame(width: 36, height: 20)
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                            .offset(x: permissionGranted ? 8 : -8)
                    }
                    .animation(Anim.tap, value: permissionGranted)
                }
                .padding(Space.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.cardBg)
                )
            }
            .padding(Space.lg)
            .driftCard(padding: 0)
            .padding(Space.lg)
            .frame(maxWidth: 260)
        }
        .frame(width: 320, height: 200)
        .accessibilityHidden(true)
    }

    private func requestAccessibility() {
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
        ("Xcode", "Productive", .productive),
        ("Safari - Twitter", "Distraction", .distraction),
        ("Slack", "Productive", .productive),
        ("Spotify", "Distraction", .distraction),
        ("Terminal", "Productive", .productive),
    ]

    var body: some View {
        VStack(spacing: Space.xxxl + Space.xxs) {
            trackingDemoCard

            VStack(spacing: Space.lg) {
                Text("Automatic App Tracking")
                    .font(TypeScale.hero)
                    .accessibilityAddTraits(.isHeader)

                Text("Drift watches which apps you use and classifies them\nautomatically. Productive, neutral, or distraction.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 440)
            }

            HStack(spacing: Space.xxl) {
                CategoryLegend(color: .productive, label: "Productive", examples: "Xcode, VSCode, Figma")
                CategoryLegend(color: .secondary, label: "Neutral", examples: "Finder, System Settings")
                CategoryLegend(color: .distraction, label: "Distraction", examples: "Twitter, YouTube, TikTok")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Categories: Productive apps like Xcode. Neutral apps like Finder. Distractions like Twitter.")
        }
        .onAppear { startDemoAnimation() }
        .onDisappear { animationTask?.cancel() }
    }

    private var trackingDemoCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.xs) {
                Circle().fill(Color.red.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(Color.orange.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(Color.green.opacity(0.8)).frame(width: 8, height: 8)
                Spacer()
                Text("Drift - Session")
                    .font(TypeScale.tiny)
                    .foregroundStyle(.tertiary)
                Spacer()
                Color.clear.frame(width: 30)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Color.primary.opacity(0.03))

            VStack(spacing: Space.sm) {
                ForEach(0..<min(trackingDemoPhase, demoApps.count), id: \.self) { i in
                    let app = demoApps[i]
                    HStack(spacing: Space.md) {
                        Circle()
                            .fill(app.color)
                            .frame(width: 6, height: 6)

                        Text(app.name)
                            .font(TypeScale.body)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Spacer()

                        Text(app.category)
                            .font(TypeScale.tiny)
                            .fontWeight(.medium)
                            .foregroundStyle(app.color)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, Space.xxxs + 1)
                            .background(
                                Capsule().fill(app.color.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if trackingDemoPhase == 0 {
                    HStack {
                        Text("Waiting for activity...")
                            .font(TypeScale.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, Space.xl)
                }
            }
            .padding(Space.md)
            .animation(Anim.appear, value: trackingDemoPhase)
        }
        .driftCard(padding: 0)
        .frame(maxWidth: 340)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Demo showing apps being tracked: Xcode as productive, Safari Twitter as distraction, Slack as productive")
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
    @State private var focusTimerValue: CGFloat = 0

    var body: some View {
        VStack(spacing: Space.xxxl + Space.xxs) {
            HStack(spacing: Space.xxl) {
                focusTimerRing

                blockedSitesPreview
            }
            .frame(maxWidth: 420)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0)) {
                    focusTimerValue = 0.82
                }
            }

            VStack(spacing: Space.lg) {
                Text("Focus Mode & Blocker")
                    .font(TypeScale.hero)
                    .accessibilityAddTraits(.isHeader)

                Text("Pomodoro timer with built-in website blocking.\nSet a password to prevent early stopping.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 440)
            }

            HStack(spacing: Space.md) {
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
                .stroke(Color.sep.opacity(0.3), lineWidth: 6)
                .frame(width: 140, height: 140)

            Circle()
                .trim(from: 0, to: focusTimerValue)
                .stroke(
                    AngularGradient(
                        colors: [Color.accent.opacity(0.5), Color.accent],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))

            VStack(spacing: Space.xxs) {
                Text("24:38")
                    .font(TypeScale.mono)
                    .minimumScaleFactor(0.7)
                Text("FOCUS")
                    .font(TypeScale.tiny)
                    .foregroundStyle(.accent)
                    .tracking(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus timer showing 24 minutes 38 seconds remaining, 82 percent complete")
    }

    private var blockedSitesPreview: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Image(systemName: "shield.fill")
                    .font(TypeScale.caption)
                    .foregroundStyle(.accent)
                Text("BLOCKED SITES")
                    .sectionLabel()
            }

            VStack(spacing: Space.xxs) {
                ForEach(["twitter.com", "reddit.com", "youtube.com", "instagram.com"], id: \.self) { site in
                    HStack(spacing: Space.xs) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.distraction.opacity(0.6))
                        Text(site)
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, Space.xxs)
                    .padding(.horizontal, Space.sm)
                    .background(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).fill(Color.distraction.opacity(0.04)))
                }
            }
        }
        .padding(Space.md + Space.xxxs)
        .driftCard(padding: 0)
        .padding(Space.md + Space.xxxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Blocked sites list: twitter, reddit, youtube, instagram")
    }
}

// MARK: - Step 4: Ready

private struct OnboardingReadyStep: View {
    let onComplete: () -> Void
    let onSignIn: () -> Void

    @State private var checkScale: CGFloat = 0

    var body: some View {
        VStack(spacing: Space.xxxl) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.productive)
                .scaleEffect(checkScale)
                .accessibilityHidden(true)
                .onAppear {
                    withAnimation(Anim.appear.delay(0.2)) {
                        checkScale = 1
                    }
                }

            VStack(spacing: Space.lg) {
                Text("You're All Set")
                    .font(TypeScale.hero)
                    .accessibilityAddTraits(.isHeader)

                Text("Drift is ready to help you focus.\nStart tracking and build your productivity streaks.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 440)
            }

            VStack(spacing: Space.md) {
                Button(action: {
                    withAnimation(Anim.page) {
                        onComplete()
                    }
                }) {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "play.fill")
                            .font(TypeScale.body)
                        Text("Start Your First Session")
                            .font(TypeScale.heading)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Space.xxxl + Space.xxs)
                    .padding(.vertical, Space.md + Space.xxxs)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Color.accent)
                    )
                }
                .driftButton()
                .accessibilityLabel("Start your first focus session")
                .keyboardShortcut(.return, modifiers: [])

                Button(action: {
                    withAnimation(Anim.page) {
                        onSignIn()
                    }
                }) {
                    HStack(spacing: Space.xxs) {
                        Text("Have an account?")
                            .foregroundStyle(.tertiary)
                        Text("Sign in to sync")
                            .foregroundStyle(.accent)
                            .fontWeight(.medium)
                    }
                    .font(TypeScale.body)
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

/// Navigation button used in the onboarding footer.
private struct OnboardingNavButton: View {
    let label: String
    let icon: String
    let iconPosition: IconPosition
    let style: Style
    let action: () -> Void

    enum IconPosition { case leading, trailing }
    enum Style { case primary, secondary }

    var body: some View {
        Button(action: action) {
            HStack(spacing: iconPosition == .leading ? Space.xxs : Space.xs) {
                if iconPosition == .leading {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(style == .primary ? TypeScale.heading : TypeScale.body)
                    .fontWeight(style == .primary ? .semibold : .medium)
                if iconPosition == .trailing {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(style == .primary ? .white : .secondary)
            .padding(.horizontal, style == .primary ? Space.page : Space.lg)
            .padding(.vertical, style == .primary ? Space.md - 1 : Space.md - 2)
            .background {
                if style == .primary {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.accent)
                }
            }
        }
        .driftButton(style == .primary ? .primary : .secondary)
    }
}

/// Inline action button for permission-granting, etc.
private struct OnboardingActionButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Image(systemName: icon)
                    .font(TypeScale.body)
                Text(label)
                    .font(TypeScale.heading)
            }
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
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
                .overlay(Capsule().stroke(color.opacity(0.12), lineWidth: 1))
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
                .foregroundStyle(.productive)
            Text(text)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100)
        .padding(.vertical, Space.md + Space.xxxs)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.productive.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(Color.productive.opacity(0.1), lineWidth: 1)
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
                .foregroundStyle(.accent)
            Text(text)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Space.md + Space.xxxs)
        .padding(.vertical, Space.sm)
        .background(
            Capsule()
                .fill(Color.accent.opacity(0.06))
                .overlay(Capsule().stroke(Color.accent.opacity(0.1), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }
}
