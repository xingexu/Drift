import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker
    @State private var currentScreen: AppState.AppScreen = .welcome

    var body: some View {
        ZStack {
            switch currentScreen {
            case .welcome:
                WelcomeView(
                    onGetStarted: { navigateTo(.onboarding) },
                    onSignIn: { navigateTo(.auth) }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            case .onboarding:
                OnboardingView(
                    onComplete: {
                        appState.completeOnboarding()
                        navigateTo(.main)
                    },
                    onSignIn: { navigateTo(.auth) }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            case .auth:
                AuthView(
                    onBack: {
                        navigateTo(appState.hasOnboarded ? .main : .welcome)
                    },
                    onSuccess: {
                        appState.completeOnboarding()
                        navigateTo(.main)
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                    removal: .opacity.combined(with: .scale(scale: 0.96))
                ))
            case .main:
                MainAppView(
                    onSignIn: { navigateTo(.auth) }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .trailing))
                ))
            }
        }
        .preferredColorScheme(colorScheme)
        .onAppear {
            currentScreen = appState.hasOnboarded ? .main : .welcome
        }
    }

    private func navigateTo(_ screen: AppState.AppScreen) {
        withAnimation(Anim.page) {
            currentScreen = screen
        }
    }

    private var colorScheme: ColorScheme? {
        switch appState.theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Main App (Sidebar + Content)

struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker
    @StateObject private var blocker = FocusBlocker.shared
    let onSignIn: () -> Void

    // Status bar state
    @State private var lastDetectedApp: String = ""
    @State private var windowSwitchSignal: String?
    @State private var statusBarFlash = false
    @State private var statusBarBlockedFlash = false

    private var showStatusBar: Bool {
        appState.focusModeActive || blocker.isBlocking
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                Divider().opacity(0.3)
                mainContent
            }

            // Global focus status bar -- visible on every page
            if showStatusBar {
                globalFocusStatusBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Anim.tap, value: showStatusBar)
        .onChange(of: tracker.activeApp) { _, newApp in
            guard showStatusBar, !newApp.isEmpty, newApp != lastDetectedApp else { return }
            lastDetectedApp = newApp
            withAnimation(Anim.quick) {
                windowSwitchSignal = newApp
                statusBarFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(Anim.quick) {
                    if windowSwitchSignal == newApp { windowSwitchSignal = nil }
                    statusBarFlash = false
                }
            }
        }
        .onChange(of: blocker.blockedAttempts) { _, _ in
            withAnimation(Anim.quick) { statusBarBlockedFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(Anim.quick) { statusBarBlockedFlash = false }
            }
        }
    }

    // MARK: - Global Focus Status Bar (sleek, 28px)

    private var globalFocusStatusBar: some View {
        HStack(spacing: Space.sm) {
            // Pulsing dot
            Circle()
                .fill(blocker.isBlocking ? Color.productive : Color.accent)
                .frame(width: 6, height: 6)

            // Label
            Text(blocker.isBlocking ? "BLOCKING" : "FOCUS")
                .font(TypeScale.tiny)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(0.8)

            // Mini timer
            if blocker.isBlocking {
                Text(blocker.timeRemainingFormatted)
                    .font(TypeScale.monoSm)
                    .foregroundStyle(.accent)
                    .contentTransition(.numericText())
                    .animation(Anim.count, value: blocker.timeRemainingFormatted)
            }

            Spacer()

            // Window switch signal
            if let app = windowSwitchSignal {
                HStack(spacing: Space.xxs) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.streak.opacity(0.8))
                    Text(app)
                        .font(TypeScale.tiny)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            // Blocked count
            if blocker.isBlocking && blocker.blockedAttempts > 0 {
                HStack(spacing: Space.xxxs) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.productive.opacity(0.7))
                    Text("\(blocker.blockedAttempts)")
                        .font(TypeScale.tiny)
                        .fontDesign(.monospaced)
                        .fontWeight(.bold)
                        .foregroundStyle(.productive)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, Space.xs)
                .padding(.vertical, Space.xxxs)
                .background(Capsule().fill(Color.productive.opacity(0.06)))
            }
        }
        .padding(.horizontal, Space.lg)
        .frame(height: 28)
        .background(
            Rectangle()
                .fill(statusBarBGColor)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.sep.opacity(0.15))
                        .frame(height: 0.5)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusBarAccessibilityLabel)
    }

    private var statusBarBGColor: Color {
        if statusBarBlockedFlash {
            return Color.distraction.opacity(0.06)
        }
        if statusBarFlash {
            return Color.streak.opacity(0.04)
        }
        return Color(.windowBackgroundColor).opacity(0.6)
    }

    private var statusBarAccessibilityLabel: String {
        var parts: [String] = []
        parts.append(blocker.isBlocking ? "Blocking mode active" : "Focus mode active")
        if blocker.isBlocking {
            parts.append(blocker.timeRemainingFormatted + " remaining")
            if blocker.blockedAttempts > 0 {
                parts.append("\(blocker.blockedAttempts) blocked attempts")
            }
        }
        return parts.joined(separator: ". ")
    }

    // MARK: - Sidebar (Native macOS styling)

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo header
            HStack(spacing: Space.md) {
                Image("DriftLogo")
                    .resizable()
                    .interpolation(.high)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    .frame(width: 28, height: 28)
                Text("Drift")
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.3)
                Spacer()
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.page)

            // Nav items -- simple text + SF Symbol, native selection style
            List(selection: Binding(
                get: { appState.currentTab },
                set: { newTab in
                    withAnimation(Anim.tap) { appState.currentTab = newTab }
                }
            )) {
                ForEach(Tab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)

            Spacer(minLength: 0)

            // Live tracking indicator
            if tracker.isTracking {
                HStack(spacing: Space.sm) {
                    Circle()
                        .fill(tracker.isPaused ? .streak : .productive)
                        .frame(width: 6, height: 6)
                    Text(formatDuration(appState.session.totalMs))
                        .font(TypeScale.monoSm)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    Spacer()
                    Text(tracker.isPaused ? "Paused" : "Tracking")
                        .font(TypeScale.tiny)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .padding(.horizontal, Space.md)
                .padding(.bottom, Space.md)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tracking session: \(formatDuration(appState.session.totalMs)). \(tracker.isPaused ? "Paused" : "Active")")
            }

            // Pro CTA -- subtle, not in-your-face
            if appState.user?.plan != "pro" {
                Button(action: { appState.currentTab = .settings }) {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "sparkles")
                            .font(TypeScale.caption)
                            .foregroundStyle(.streak)
                        Text("Drift Pro")
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.quaternary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.sm)
                .padding(.horizontal, Space.md)
                .padding(.bottom, Space.sm)
                .accessibilityLabel("Upgrade to Drift Pro")
            }

            Divider().padding(.horizontal, Space.lg).padding(.bottom, Space.md)

            // User
            HStack(spacing: Space.md) {
                if let user = appState.user {
                    Circle()
                        .fill(Color.accent.opacity(0.12))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(user.initials)
                                .font(TypeScale.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.accent)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(user.displayName)
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(user.plan.capitalized)
                            .font(TypeScale.tiny)
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(user.displayName), \(user.plan) plan")
                } else {
                    Button(action: onSignIn) {
                        HStack(spacing: Space.sm) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 22))
                                .foregroundStyle(.quaternary)
                            Text("Sign In")
                                .font(TypeScale.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sign in to your account")
                }
                Spacer()
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
        }
        .frame(width: 210)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation sidebar")
    }

    // MARK: - Content

    private var mainContent: some View {
        ZStack {
            tabContent
                .id(appState.currentTab)
                .transition(.opacity.animation(Anim.quick))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
        .animation(Anim.quick, value: appState.currentTab)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch appState.currentTab {
        case .home:     HomeView()
        case .session:  SessionView()
        case .focus:    StudyView()
        case .history:  HistoryView()
        case .settings: SettingsView()
        }
    }
}
