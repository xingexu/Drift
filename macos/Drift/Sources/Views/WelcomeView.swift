import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void

    @State private var appeared = false
    @State private var gradientPhase: CGFloat = 0
    @State private var demoPhase: Int = 0
    @State private var demoAnimationTask: Task<Void, Never>?

    // Staggered appearance flags for scroll-based reveal
    @State private var heroVisible = false
    @State private var demoVisible = false
    @State private var featuresVisible = false
    @State private var stepsVisible = false
    @State private var ctaVisible = false

    var body: some View {
        ZStack {
            WelcomeBackground(gradientPhase: $gradientPhase)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 48)

                    heroSection
                        .padding(.bottom, 72)
                        .onAppear { withAnimation(.easeOut(duration: 0.7)) { heroVisible = true } }

                    liveDemo
                        .padding(.bottom, 72)
                        .onAppear { withAnimation(.easeOut(duration: 0.7).delay(0.15)) { demoVisible = true } }

                    featuresSection
                        .padding(.bottom, 72)
                        .onAppear { withAnimation(.easeOut(duration: 0.7).delay(0.1)) { featuresVisible = true } }

                    stepsSection
                        .padding(.bottom, 72)
                        .onAppear { withAnimation(.easeOut(duration: 0.7).delay(0.1)) { stepsVisible = true } }

                    bottomCTA
                        .padding(.bottom, 48)
                        .onAppear { withAnimation(.easeOut(duration: 0.7).delay(0.1)) { ctaVisible = true } }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to Drift")
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                appeared = true
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                gradientPhase = 1
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.drift.opacity(0.15))
                    .frame(width: 110, height: 110)
                    .blur(radius: 20)

                Image("DriftLogo")
                    .resizable()
                    .interpolation(.high)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.drift.opacity(0.4), radius: 24, y: 8)
                    .accessibilityLabel("Drift app icon")
            }
            .opacity(heroVisible ? 1 : 0)
            .offset(y: heroVisible ? 0 : 20)

            VStack(spacing: 14) {
                Text("Know where your\ntime goes.")
                    .font(.system(size: 42, weight: .heavy))
                    .tracking(-1)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .accessibilityAddTraits(.isHeader)
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 16)

                Text("AI-powered focus tracking that lives in your menu bar.\nUnderstand your habits. Stay productive. Build streaks.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 480)
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 12)
            }

            VStack(spacing: 14) {
                WelcomePrimaryButton(label: "Get Started for Free", action: onGetStarted)
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 8)
                    .keyboardShortcut(.return, modifiers: [])
                    .accessibilityLabel("Get started for free")
                    .accessibilityHint("Begins the Drift onboarding experience")

                Button(action: onSignIn) {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(.tertiary)
                        Text("Sign in")
                            .foregroundStyle(Color.drift)
                            .fontWeight(.medium)
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .opacity(heroVisible ? 1 : 0)
                .accessibilityLabel("Sign in to existing account")
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Live Demo (Animated)

    private var liveDemo: some View {
        VStack(spacing: 0) {
            // Window chrome
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1, green: 0.373, blue: 0.341)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 0.996, green: 0.741, blue: 0.180)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 0.157, green: 0.784, blue: 0.251)).frame(width: 12, height: 12)
                Spacer()
                Text("Drift")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer()
                Color.clear.frame(width: 52)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.03))

            Divider().opacity(0.3)

            HStack(spacing: 0) {
                // Mini sidebar
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.drift.opacity(0.3)).frame(width: 14, height: 14)
                        Text("Drift").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 4)
                    ForEach(["Home", "Session", "Focus", "History"], id: \.self) { label in
                        let isHome = label == "Home"
                        HStack(spacing: 5) {
                            Circle().fill(isHome ? Color.drift.opacity(0.3) : Color.clear).frame(width: 4, height: 4)
                            Text(label)
                                .font(.system(size: 9, weight: isHome ? .semibold : .regular))
                                .foregroundStyle(isHome ? Color.drift : Color.secondary)
                        }
                    }
                    Spacer()
                }
                .frame(width: 70)
                .padding(10)
                .background(Color.primary.opacity(0.02))

                Divider().opacity(0.2)

                // Main content
                VStack(alignment: .leading, spacing: 12) {
                    Text("Welcome back")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        WelcomeMockStat(value: "4h 32m", label: "Tracked", color: Color.drift)
                        WelcomeMockStat(value: "78%", label: "Focus", color: Color("Green"))
                        WelcomeMockStat(value: "5", label: "Streak", color: .orange)
                    }

                    // Animated focus bar
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Today's Focus").font(.system(size: 8, weight: .medium)).foregroundStyle(.tertiary)
                        GeometryReader { geo in
                            HStack(spacing: 1) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color("Green"))
                                    .frame(width: demoPhase >= 1 ? geo.size.width * 0.72 : 0)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color("Red"))
                                    .frame(width: demoPhase >= 2 ? geo.size.width * 0.15 : 0)
                                RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.08))
                            }
                            .animation(.easeInOut(duration: 1.0), value: demoPhase)
                        }
                        .frame(height: 5)
                        .clipShape(Capsule())
                    }

                    // Animated activity rows
                    ForEach(Array(zip(["Xcode", "Safari", "Slack"], [0, 1, 2])), id: \.1) { app, index in
                        if demoPhase >= index + 1 {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(app == "Safari" ? Color("Red") : Color("Green"))
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
                .padding(14)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 30, y: 12)
        .frame(maxWidth: 480)
        .padding(.horizontal, 40)
        .opacity(demoVisible ? 1 : 0)
        .offset(y: demoVisible ? 0 : 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live demo showing Drift tracking 4 hours 32 minutes with 78 percent focus score and a 5 day streak")
        .onAppear { startDemoAnimation() }
        .onDisappear { demoAnimationTask?.cancel() }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Everything you need")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.3)
                    .accessibilityAddTraits(.isHeader)
                Text("Powerful focus tools built natively for macOS")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                spacing: 16
            ) {
                WelcomeFeatureCard(
                    icon: "eye.tracking.circle.fill",
                    title: "Smart App Tracking",
                    description: "Detects your active app & window using macOS Accessibility. Zero configuration.",
                    accent: Color.drift
                )
                WelcomeFeatureCard(
                    icon: "chart.bar.xaxis.ascending",
                    title: "Real-Time Focus Score",
                    description: "Live focus percentage and drift score. Know instantly when you're losing focus.",
                    accent: Color("Green")
                )
                WelcomeFeatureCard(
                    icon: "timer.circle.fill",
                    title: "Pomodoro Timer",
                    description: "Customizable focus and break intervals. Desktop notifications when sessions end.",
                    accent: .orange
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
        .padding(.horizontal, 40)
        .opacity(featuresVisible ? 1 : 0)
        .offset(y: featuresVisible ? 0 : 20)
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(spacing: 32) {
            Text("How it works")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.3)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: 24) {
                WelcomeStepCard(number: "1", title: "Launch Drift", description: "Lives in your menu bar. Starts tracking the moment you open it.", icon: "power.circle.fill")
                WelcomeStepCard(number: "2", title: "Stay Focused", description: "Classifies every app automatically. See your focus score update live.", icon: "bolt.circle.fill")
                WelcomeStepCard(number: "3", title: "Review & Improve", description: "Check session history, build streaks, and develop better habits.", icon: "chart.line.uptrend.xyaxis.circle.fill")
            }
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, 40)
        .opacity(stepsVisible ? 1 : 0)
        .offset(y: stepsVisible ? 0 : 20)
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 20) {
            Text("Ready to take control?")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.3)
                .accessibilityAddTraits(.isHeader)

            WelcomePrimaryButton(label: "Get Started -- It's Free", action: onGetStarted)
                .accessibilityLabel("Get started for free")

            Text("No account required  \u{2022}  Works offline  \u{2022}  Native macOS")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 40)
        .opacity(ctaVisible ? 1 : 0)
    }

    // MARK: - Demo Animation

    private func startDemoAnimation() {
        demoPhase = 0
        demoAnimationTask = Task { @MainActor in
            for i in 1...3 {
                try? await Task.sleep(nanoseconds: UInt64(i) * 500_000_000 + 1_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    demoPhase = i
                }
            }
        }
    }
}

// MARK: - Background

private struct WelcomeBackground: View {
    @Binding var gradientPhase: CGFloat

    var body: some View {
        ZStack {
            Color("Background")

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.drift.opacity(0.12), .clear],
                        center: .center, startRadius: 0, endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: -200, y: gradientPhase * -80 - 100)
                .blur(radius: 60)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color("Green").opacity(0.08), .clear],
                        center: .center, startRadius: 0, endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: 250, y: gradientPhase * 60 + 200)
                .blur(radius: 50)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.orange.opacity(0.06), .clear],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 100, y: gradientPhase * -50 + 400)
                .blur(radius: 40)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Components

private struct WelcomePrimaryButton: View {
    let label: String
    let action: () -> Void
    @State private var hovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.drift)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(hovering ? 0.15 : 0.1), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }
                )
                .shadow(color: Color.drift.opacity(hovering ? 0.5 : 0.25), radius: hovering ? 20 : 10, y: hovering ? 6 : 4)
                .scaleEffect(isPressed ? 0.96 : hovering ? 1.03 : 1)
                .animation(.easeOut(duration: 0.2), value: hovering)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { h in
            hovering = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

private struct WelcomeFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let accent: Color
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accent.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(accent)
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Text(description)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(hovering ? 0.08 : 0.04), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(hovering ? 0.08 : 0.03), radius: hovering ? 16 : 8, y: hovering ? 6 : 3)
        .scaleEffect(hovering ? 1.02 : 1)
        .animation(.easeOut(duration: 0.2), value: hovering)
        .onHover { h in hovering = h }
        .accessibilityElement(children: .combine)
    }
}

private struct WelcomeStepCard: View {
    let number: String
    let title: String
    let description: String
    let icon: String
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.drift)
                    .frame(width: 36, height: 36)
                Text(number)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Step \(number)")

            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Color.drift.opacity(0.6))
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(hovering ? 0.06 : 0.03), lineWidth: 1)
                )
        )
        .scaleEffect(hovering ? 1.02 : 1)
        .animation(.easeOut(duration: 0.2), value: hovering)
        .onHover { h in hovering = h }
        .accessibilityElement(children: .combine)
    }
}

private struct WelcomeMockStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.03)))
        .accessibilityElement(children: .combine)
    }
}
