import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void

    @State private var appeared = false
    @State private var demoPhase: Int = 0
    @State private var demoAnimationTask: Task<Void, Never>?
    @State private var logoPulse = false
    @State private var avatarPulse = false

    var body: some View {
        ZStack {
            // Full-bleed ambient background
            ambientBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: Space.xxxl + Space.xl)

                    heroSection
                        .padding(.bottom, Space.xxxl + Space.sm)

                    liveDemo
                        .padding(.bottom, Space.xxxl + Space.lg)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to Drift")
        .onAppear {
            withAnimation(Anim.appear) {
                appeared = true
            }
            withAnimation(Anim.breathe.delay(0.6)) {
                logoPulse = true
            }
            withAnimation(Anim.breathe.delay(1.2)) {
                avatarPulse = true
            }
        }
    }

    // MARK: - Ambient Background

    @ViewBuilder
    private var ambientBackground: some View {
        DriftAmbientBackground(accent: Color.accent, reduceMotion: false)
        .ignoresSafeArea()
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: Space.xxxl) {
            // Animated logo with accent glow
            logoMark

            // Eyebrow + headline + subhead
            VStack(spacing: Space.lg) {
                DriftTag(text: "Focus tracker for Mac", color: Color.accent)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 6)
                    .animation(Anim.appear.delay(0.05), value: appeared)

                // Split headline: "Your focus," + "amplified."
                VStack(spacing: 0) {
                    Text("Your focus,")
                        .foregroundStyle(Color.driftText)
                    Text("amplified.")
                        .foregroundStyle(Color.accent)
                }
                .font(TypeScale.display)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Your focus, amplified.")
                .accessibilityAddTraits(.isHeader)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(Anim.appear.delay(0.10), value: appeared)

                Text("Track attention, protect focus time, and review the day without extra ceremony.")
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 400)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(Anim.appear.delay(0.15), value: appeared)
            }

            PrimaryButton("Start Setup", icon: "arrow.right", action: onGetStarted)
                .keyboardShortcut(.return, modifiers: [])
                .opacity(appeared ? 1 : 0)
                .animation(Anim.appear.delay(0.20), value: appeared)
                .accessibilityHint("Open the Drift setup guide")

            featureTrio
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(Anim.appear.delay(0.35), value: appeared)
        }
        .padding(.horizontal, Space.xxxl + Space.sm)
    }

    // MARK: - Logo Mark

    @ViewBuilder
    private var logoMark: some View {
        ZStack {
            Rectangle()
                .fill(Color.accent.opacity(logoPulse ? 0.20 : 0.09))
                .frame(width: 72, height: 72)
                .offset(x: logoPulse ? 7 : 4, y: logoPulse ? 7 : 4)

            Image("DriftLogo")
                .resizable()
                .interpolation(.none)
                .clipShape(Rectangle())
                .frame(width: 60, height: 60)
                .overlay(Rectangle().strokeBorder(Color.primary.opacity(0.55), lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 0, x: 6, y: 6)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(Anim.appear, value: appeared)
        .accessibilityLabel("Drift app icon")
    }

    // MARK: - Feature Trio

    @ViewBuilder
    private var featureTrio: some View {
        let chips: [(icon: String, label: String)] = [
            ("brain.head.profile", "Deep Focus"),
            ("chart.bar.fill",     "Live Stats"),
            ("shield.fill",        "Site Blocker")
        ]

        HStack(spacing: Space.sm) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                HStack(spacing: Space.xxs + 2) {
                    Image(systemName: chip.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accent)
                    Text(chip.label)
                        .font(TypeScale.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xxs + 2)
                .background {
                    Rectangle()
                        .fill(Color.driftPanel)
                        .overlay(Rectangle().strokeBorder(Color.border, lineWidth: 1))
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Live Demo (Animated)

    @ViewBuilder
    private var liveDemo: some View {
        VStack(spacing: Space.md) {
            Text("SEE IT IN ACTION")
                .sectionLabel()
                .opacity(appeared ? 1 : 0)
                .animation(Anim.appear.delay(0.10), value: appeared)

            demoChromeWindow
                .frame(maxWidth: 480)
                .padding(.horizontal, Space.xxxl + Space.sm)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(Anim.appear.delay(0.15), value: appeared)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Live demo showing Drift tracking 4 hours 32 minutes with 78 percent focus score and a 5 day streak")
                .onAppear { startDemoAnimation() }
                .onDisappear { demoAnimationTask?.cancel() }
        }
    }

    @ViewBuilder
    private var demoChromeWindow: some View {
        VStack(spacing: 0) {
            // macOS window chrome
            HStack(spacing: Space.xs) {
                HStack(spacing: Space.xxs + 2) {
                    Rectangle()
                        .fill(Color(red: 1.0, green: 0.373, blue: 0.341))
                        .frame(width: 12, height: 12)
                    Rectangle()
                        .fill(Color(red: 0.996, green: 0.741, blue: 0.180))
                        .frame(width: 12, height: 12)
                    Rectangle()
                        .fill(Color(red: 0.157, green: 0.784, blue: 0.251))
                        .frame(width: 12, height: 12)
                }

                Spacer()

                Text("Drift")
                    .font(TypeScale.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.tertiary)

                Spacer()

                Color.clear
                    .frame(width: 52, height: 12)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm + 2)
            .background(Color.driftPanel)

            Rectangle()
                .fill(Color.border)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                demoSidebar

                Rectangle()
                    .fill(Color.border.opacity(0.6))
                    .frame(width: 0.5)

                demoMainContent
            }
        }
        .background {
            Rectangle()
                .fill(Color.driftPanel)
                .overlay {
                    Rectangle()
                        .inset(by: 1)
                        .strokeBorder(Color.driftBorder, lineWidth: 2)
                }
        }
        .clipShape(Rectangle())
        .elevate(.md)
    }

    @ViewBuilder
    private var demoSidebar: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                    .fill(Color.accent.opacity(0.3))
                    .frame(width: 14, height: 14)
                Text("Drift")
                    .font(TypeScale.bodySm)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, Space.xxs)

            ForEach(["Home", "Session", "Focus", "History"], id: \.self) { label in
                let isActive = label == "Home"
                HStack(spacing: Space.xxs + 1) {
                    Rectangle()
                        .fill(isActive ? Color.accent.opacity(0.8) : Color.clear)
                        .frame(width: 4, height: 4)
                    Text(label)
                        .font(TypeScale.tiny)
                        .foregroundStyle(isActive ? Color.accent : Color(.secondaryLabelColor))
                }
            }

            Spacer()
        }
        .frame(width: 72)
        .padding(Space.md)
        .background(Color.primary.opacity(0.02))
    }

    @ViewBuilder
    private var demoMainContent: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Welcome back")
                .font(TypeScale.bodyMd)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            HStack(spacing: Space.sm) {
                WelcomeMockStat(value: "4h 32m", label: "Tracked", color: Color.accent)
                WelcomeMockStat(value: "78%",    label: "Focus",   color: Color.productive)
                WelcomeMockStat(value: "5",      label: "Streak",  color: Color.streak)
            }

            VStack(alignment: .leading, spacing: Space.xxxs + 1) {
                Text("TODAY'S FOCUS")
                    .sectionLabel()

                GeometryReader { geo in
                    HStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                            .fill(Color.productive)
                            .frame(width: demoPhase >= 1 ? geo.size.width * 0.72 : 0)
                        RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                            .fill(Color.distraction)
                            .frame(width: demoPhase >= 2 ? geo.size.width * 0.15 : 0)
                        RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    }
                    .animation(Anim.count, value: demoPhase)
                }
                .frame(height: 5)
                .clipShape(Rectangle())
            }

            VStack(spacing: Space.xxs) {
                ForEach(Array(zip(demoApps, [1, 2, 3])), id: \.1) { item, phase in
                    if demoPhase >= phase {
                        demoAppRow(name: item.name, duration: item.duration, isDistraction: item.isDistraction)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
            }
        }
        .padding(Space.md + Space.xxxs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct DemoApp {
        let name: String
        let duration: String
        let isDistraction: Bool
    }

    private let demoApps: [DemoApp] = [
        DemoApp(name: "Xcode",  duration: "2h 15m", isDistraction: false),
        DemoApp(name: "Safari", duration: "45m",    isDistraction: true),
        DemoApp(name: "Slack",  duration: "1h 12m", isDistraction: false)
    ]

    @ViewBuilder
    private func demoAppRow(name: String, duration: String, isDistraction: Bool) -> some View {
        HStack(spacing: Space.xs) {
            Rectangle()
                .fill(isDistraction ? Color.distraction : Color.productive)
                .frame(width: 4, height: 4)
            Text(name)
                .font(TypeScale.tiny)
                .foregroundStyle(.secondary)
            Spacer()
            Text(duration)
                .font(TypeScale.tiny)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Features Grid

    private let features: [WelcomeFeatureDef] = [
        WelcomeFeatureDef(
            icon: "eye.tracking.circle.fill",
            title: "Smart App Tracking",
            description: "Detects your active app & window using macOS Accessibility. Zero configuration.",
            color: Color.accent
        ),
        WelcomeFeatureDef(
            icon: "chart.bar.xaxis.ascending",
            title: "Real-Time Focus Score",
            description: "Live focus percentage and drift score. Know instantly when you're losing focus.",
            color: Color.productive
        ),
        WelcomeFeatureDef(
            icon: "timer.circle.fill",
            title: "Pomodoro Timer",
            description: "Customizable focus and break intervals. Desktop notifications when sessions end.",
            color: Color.streak
        ),
        WelcomeFeatureDef(
            icon: "shield.checkered",
            title: "Website Blocker",
            description: "Block distracting sites with password-protected timer. Stay focused effortlessly.",
            color: Color.purple
        )
    ]

    @ViewBuilder
    private var featuresSection: some View {
        VStack(spacing: Space.xxxl) {
            VStack(spacing: Space.sm) {
                DriftTag(text: "Features", color: Color.accent)
                Text("Everything you need")
                    .font(TypeScale.h2)
                    .accessibilityAddTraits(.isHeader)
                Text("Powerful focus tools built natively for macOS")
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Space.lg),
                    GridItem(.flexible(), spacing: Space.lg)
                ],
                spacing: Space.lg
            ) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    WelcomeFeatureCard(
                        icon: feature.icon,
                        title: feature.title,
                        description: feature.description,
                        accent: feature.color
                    )
                    .staggerAppear(index: index, appeared: appeared, yOffset: 12, baseDelay: 0.06)
                }
            }
        }
        .frame(maxWidth: 580)
        .padding(.horizontal, Space.xxxl + Space.sm)
        .opacity(appeared ? 1 : 0)
        .animation(Anim.appear.delay(0.15), value: appeared)
    }

    // MARK: - Steps (How it works)

    private let steps: [WelcomeStepDef] = [
        WelcomeStepDef(number: "1", title: "Launch Drift",    description: "Lives in your menu bar. Starts tracking the moment you open it.",             icon: "power.circle.fill"),
        WelcomeStepDef(number: "2", title: "Stay Focused",    description: "Classifies every app automatically. See your focus score update live.",        icon: "bolt.circle.fill"),
        WelcomeStepDef(number: "3", title: "Review & Improve",description: "Check session history, build streaks, and develop better habits.",             icon: "chart.line.uptrend.xyaxis.circle.fill")
    ]

    @ViewBuilder
    private var stepsSection: some View {
        VStack(spacing: Space.xxxl) {
            VStack(spacing: Space.sm) {
                DriftTag(text: "How it works", color: Color.accent)
                Text("Up and running in seconds")
                    .font(TypeScale.h2)
                    .accessibilityAddTraits(.isHeader)
            }
            .multilineTextAlignment(.center)

            ZStack(alignment: .top) {
                GeometryReader { geo in
                    let thirdW = geo.size.width / 3.0
                    let circleRadius: CGFloat = 18
                    let lineY: CGFloat = circleRadius
                    Path { path in
                        path.move(to: CGPoint(x: thirdW * 0.5 + circleRadius, y: lineY))
                        path.addLine(to: CGPoint(x: thirdW * 1.5 - circleRadius, y: lineY))
                        path.move(to: CGPoint(x: thirdW * 1.5 + circleRadius, y: lineY))
                        path.addLine(to: CGPoint(x: thirdW * 2.5 - circleRadius, y: lineY))
                    }
                    .stroke(
                        Color.accent.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
                }
                .frame(height: 36)
                .padding(.horizontal, Space.xxxl)

                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        WelcomeStepCard(
                            number: step.number,
                            title: step.title,
                            description: step.description,
                            icon: step.icon
                        )
                        .staggerAppear(index: index, appeared: appeared, yOffset: 10, baseDelay: 0.08)
                    }
                }
            }
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, Space.xxxl + Space.sm)
        .opacity(appeared ? 1 : 0)
        .animation(Anim.appear.delay(0.20), value: appeared)
    }

    // MARK: - Bottom CTA

    @ViewBuilder
    private var bottomCTA: some View {
        VStack(spacing: Space.xl) {
            Text("Ready to focus?")
                .font(TypeScale.h1)
                .tracking(-0.4)
                .accessibilityAddTraits(.isHeader)

            Text("Build a personal focus baseline from real activity on this Mac.")
                .font(TypeScale.bodyMd)
                .foregroundStyle(.secondary)

            PrimaryButton("Start Locally", icon: "bolt.fill", isFullWidth: true, action: onGetStarted)
                .accessibilityLabel("Start Drift locally")

            Text("Private by design  \u{2022}  Works offline  \u{2022}  Native macOS")
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Space.xxxl + Space.sm)
        .accentCard(color: Color.accent, padding: Space.xxxl, radius: Radius.xl)
        .frame(maxWidth: 520)
        .opacity(appeared ? 1 : 0)
        .animation(Anim.appear.delay(0.25), value: appeared)
    }

    // MARK: - Demo Animation

    private func startDemoAnimation() {
        demoPhase = 0
        demoAnimationTask = Task { @MainActor in
            for i in 1...3 {
                try? await Task.sleep(nanoseconds: UInt64(i) * 500_000_000 + 1_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(Anim.appear) {
                    demoPhase = i
                }
            }
        }
    }
}

// MARK: - Data Models

private struct WelcomeFeatureDef {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

private struct WelcomeStepDef {
    let number: String
    let title: String
    let description: String
    let icon: String
}

// MARK: - Feature Card

private struct WelcomeFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                IconBadge(systemName: icon, color: accent, size: 40)
                    .accessibilityHidden(true)
                Spacer()
            }

            Text(title)
                .font(TypeScale.heading)

            Text(description)
                .font(TypeScale.bodyMd)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
        .hoverLift()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Step Card

private struct WelcomeStepCard: View {
    let number: String
    let title: String
    let description: String
    let icon: String

    var body: some View {
        VStack(spacing: Space.md) {
            ZStack {
                Rectangle()
                    .fill(Color.accent)
                    .frame(width: 36, height: 36)
                Text(number)
                    .font(TypeScale.heading)
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Step \(number)")

            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Color.accent.opacity(0.6))
                .accessibilityHidden(true)

            VStack(spacing: Space.xxs) {
                Text(title)
                    .font(TypeScale.heading)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .driftCard()
        .hoverLift()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Mock Stat Pill (demo only)

private struct WelcomeMockStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Space.xxxs) {
            Text(value)
                .font(TypeScale.monoSm)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(TypeScale.tiny)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xs)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .accessibilityElement(children: .combine)
    }
}
