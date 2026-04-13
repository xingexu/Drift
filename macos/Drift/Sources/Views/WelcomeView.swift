import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void

    @State private var appeared = false
    @State private var demoPhase: Int = 0
    @State private var demoAnimationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: Space.xxxl + Space.lg)

                    heroSection
                        .padding(.bottom, Space.xxxl * 2 + Space.sm)

                    liveDemo
                        .padding(.bottom, Space.xxxl * 2 + Space.sm)

                    featuresSection
                        .padding(.bottom, Space.xxxl * 2 + Space.sm)

                    stepsSection
                        .padding(.bottom, Space.xxxl * 2 + Space.sm)

                    bottomCTA
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
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: Space.xxl) {
            Image("DriftLogo")
                .resizable()
                .interpolation(.high)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg + 2, style: .continuous))
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .accessibilityLabel("Drift app icon")

            VStack(spacing: Space.md) {
                Text("Know where your\ntime goes.")
                    .font(TypeScale.hero)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)

                Text("AI-powered focus tracking that lives in your menu bar.\nUnderstand your habits. Stay productive. Build streaks.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 480)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
            }

            VStack(spacing: Space.md) {
                Button(action: onGetStarted) {
                    Text("Get Started for Free")
                        .font(TypeScale.heading)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Space.xxxl + Space.xxs)
                        .padding(.vertical, Space.md + Space.xxxs)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(Color.accent)
                        )
                }
                .driftButton()
                .keyboardShortcut(.return, modifiers: [])
                .opacity(appeared ? 1 : 0)
                .accessibilityLabel("Get started for free")
                .accessibilityHint("Begins the Drift onboarding experience")

                Button(action: onSignIn) {
                    HStack(spacing: Space.xxs) {
                        Text("Already have an account?")
                            .foregroundStyle(.tertiary)
                        Text("Sign in")
                            .foregroundStyle(.accent)
                            .fontWeight(.medium)
                    }
                    .font(TypeScale.body)
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .accessibilityLabel("Sign in to existing account")
            }
        }
        .padding(.horizontal, Space.xxxl + Space.sm)
    }

    // MARK: - Live Demo (Animated)

    private var liveDemo: some View {
        VStack(spacing: 0) {
            // Window chrome
            HStack(spacing: Space.sm) {
                Circle().fill(Color(red: 1, green: 0.373, blue: 0.341)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 0.996, green: 0.741, blue: 0.180)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 0.157, green: 0.784, blue: 0.251)).frame(width: 12, height: 12)
                Spacer()
                Text("Drift")
                    .font(TypeScale.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.tertiary)
                Spacer()
                Color.clear.frame(width: 52)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md - 2)
            .background(Color.primary.opacity(0.03))

            Divider().opacity(0.3)

            HStack(spacing: 0) {
                // Mini sidebar
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.xs) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color.accent.opacity(0.3)).frame(width: 14, height: 14)
                        Text("Drift").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, Space.xxs)
                    ForEach(["Home", "Session", "Focus", "History"], id: \.self) { label in
                        let isHome = label == "Home"
                        HStack(spacing: Space.xxs + 1) {
                            Circle().fill(isHome ? Color.accent.opacity(0.3) : Color.clear).frame(width: 4, height: 4)
                            Text(label)
                                .font(.system(size: 9, weight: isHome ? .semibold : .regular))
                                .foregroundStyle(isHome ? Color.accent : Color.secondary)
                        }
                    }
                    Spacer()
                }
                .frame(width: 70)
                .padding(Space.md - 2)
                .background(Color.primary.opacity(0.02))

                Divider().opacity(0.2)

                // Main content
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Welcome back")
                        .font(TypeScale.body)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)

                    HStack(spacing: Space.sm) {
                        WelcomeMockStat(value: "4h 32m", label: "Tracked", color: .accent)
                        WelcomeMockStat(value: "78%", label: "Focus", color: .productive)
                        WelcomeMockStat(value: "5", label: "Streak", color: .streak)
                    }

                    // Animated focus bar
                    VStack(alignment: .leading, spacing: Space.xxxs + 1) {
                        Text("TODAY'S FOCUS")
                            .sectionLabel()
                        GeometryReader { geo in
                            HStack(spacing: 1) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Color.productive)
                                    .frame(width: demoPhase >= 1 ? geo.size.width * 0.72 : 0)
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Color.distraction)
                                    .frame(width: demoPhase >= 2 ? geo.size.width * 0.15 : 0)
                                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Color.primary.opacity(0.08))
                            }
                            .animation(Anim.count, value: demoPhase)
                        }
                        .frame(height: 5)
                        .clipShape(Capsule())
                    }

                    // Animated activity rows
                    ForEach(Array(zip(["Xcode", "Safari", "Slack"], [0, 1, 2])), id: \.1) { app, index in
                        if demoPhase >= index + 1 {
                            HStack(spacing: Space.xs) {
                                Circle()
                                    .fill(app == "Safari" ? Color.distraction : Color.productive)
                                    .frame(width: 4, height: 4)
                                Text(app)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(app == "Xcode" ? "2h 15m" : app == "Safari" ? "45m" : "1h 12m")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                }
                .padding(Space.md + Space.xxxs)
            }
        }
        .driftCard(padding: 0)
        .frame(maxWidth: 480)
        .padding(.horizontal, Space.xxxl + Space.sm)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live demo showing Drift tracking 4 hours 32 minutes with 78 percent focus score and a 5 day streak")
        .onAppear { startDemoAnimation() }
        .onDisappear { demoAnimationTask?.cancel() }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: Space.xxxl) {
            VStack(spacing: Space.sm) {
                Text("Everything you need")
                    .font(TypeScale.title)
                    .accessibilityAddTraits(.isHeader)
                Text("Powerful focus tools built natively for macOS")
                    .font(TypeScale.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: Space.lg), GridItem(.flexible(), spacing: Space.lg)],
                spacing: Space.lg
            ) {
                WelcomeFeatureCard(
                    icon: "eye.tracking.circle.fill",
                    title: "Smart App Tracking",
                    description: "Detects your active app & window using macOS Accessibility. Zero configuration.",
                    accent: .accent
                )
                WelcomeFeatureCard(
                    icon: "chart.bar.xaxis.ascending",
                    title: "Real-Time Focus Score",
                    description: "Live focus percentage and drift score. Know instantly when you're losing focus.",
                    accent: .productive
                )
                WelcomeFeatureCard(
                    icon: "timer.circle.fill",
                    title: "Pomodoro Timer",
                    description: "Customizable focus and break intervals. Desktop notifications when sessions end.",
                    accent: .streak
                )
                WelcomeFeatureCard(
                    icon: "shield.checkered",
                    title: "Website Blocker",
                    description: "Block distracting sites with password-protected timer. Stay focused effortlessly.",
                    accent: .purple
                )
            }
        }
        .frame(maxWidth: 580)
        .padding(.horizontal, Space.xxxl + Space.sm)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(spacing: Space.xxxl) {
            Text("How it works")
                .font(TypeScale.title)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: Space.xxl) {
                WelcomeStepCard(number: "1", title: "Launch Drift", description: "Lives in your menu bar. Starts tracking the moment you open it.", icon: "power.circle.fill")
                WelcomeStepCard(number: "2", title: "Stay Focused", description: "Classifies every app automatically. See your focus score update live.", icon: "bolt.circle.fill")
                WelcomeStepCard(number: "3", title: "Review & Improve", description: "Check session history, build streaks, and develop better habits.", icon: "chart.line.uptrend.xyaxis.circle.fill")
            }
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, Space.xxxl + Space.sm)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: Space.xl) {
            Text("Ready to take control?")
                .font(TypeScale.hero)
                .accessibilityAddTraits(.isHeader)

            Button(action: onGetStarted) {
                Text("Get Started -- It's Free")
                    .font(TypeScale.heading)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Space.xxxl + Space.xxs)
                    .padding(.vertical, Space.md + Space.xxxs)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Color.accent)
                    )
            }
            .driftButton()
            .accessibilityLabel("Get started for free")

            Text("No account required  \u{2022}  Works offline  \u{2022}  Native macOS")
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Space.xxxl + Space.sm)
        .opacity(appeared ? 1 : 0)
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

// MARK: - Components

private struct WelcomeFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md + Space.xxxs) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(accent.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(accent)
            }
            .accessibilityHidden(true)

            Text(title)
                .font(TypeScale.body)
                .fontWeight(.semibold)

            Text(description)
                .font(TypeScale.caption)
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

private struct WelcomeStepCard: View {
    let number: String
    let title: String
    let description: String
    let icon: String

    var body: some View {
        VStack(spacing: Space.md + Space.xxxs) {
            ZStack {
                Circle()
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

            Text(title)
                .font(TypeScale.body)
                .fontWeight(.semibold)

            Text(description)
                .font(TypeScale.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .driftCard()
        .hoverLift()
        .accessibilityElement(children: .combine)
    }
}

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
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xs)
        .background(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).fill(Color.primary.opacity(0.03)))
        .accessibilityElement(children: .combine)
    }
}
