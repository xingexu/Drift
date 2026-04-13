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
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
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
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showStatusBar)
        .onChange(of: tracker.activeApp) { _, newApp in
            guard showStatusBar, !newApp.isEmpty, newApp != lastDetectedApp else { return }
            lastDetectedApp = newApp
            withAnimation(.easeOut(duration: 0.12)) {
                windowSwitchSignal = newApp
                statusBarFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.25)) {
                    if windowSwitchSignal == newApp { windowSwitchSignal = nil }
                    statusBarFlash = false
                }
            }
        }
        .onChange(of: blocker.blockedAttempts) { _, _ in
            withAnimation(.easeOut(duration: 0.1)) { statusBarBlockedFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.2)) { statusBarBlockedFlash = false }
            }
        }
    }

    // MARK: - Global Focus Status Bar (sleek, 28px)

    private var globalFocusStatusBar: some View {
        HStack(spacing: 8) {
            // Pulsing dot
            Circle()
                .fill(blocker.isBlocking ? Color("Green") : Color.drift)
                .frame(width: 6, height: 6)
                .shadow(color: (blocker.isBlocking ? Color("Green") : Color.drift).opacity(0.5), radius: 2)

            // Label
            Text(blocker.isBlocking ? "BLOCKING" : "FOCUS")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            // Mini timer
            if blocker.isBlocking {
                Text(blocker.timeRemainingFormatted)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.drift)
                    .contentTransition(.numericText())
                    .animation(.default, value: blocker.timeRemainingFormatted)
            }

            Spacer()

            // Window switch signal
            if let app = windowSwitchSignal {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.orange.opacity(0.8))
                    Text(app)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            // Blocked count
            if blocker.isBlocking && blocker.blockedAttempts > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color("Green").opacity(0.7))
                    Text("\(blocker.blockedAttempts)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color("Green"))
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color("Green").opacity(0.06)))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(
            Rectangle()
                .fill(statusBarBGColor)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(.separatorColor).opacity(0.15))
                        .frame(height: 0.5)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusBarAccessibilityLabel)
    }

    private var statusBarBGColor: Color {
        if statusBarBlockedFlash {
            return Color("Red").opacity(0.06)
        }
        if statusBarFlash {
            return Color.orange.opacity(0.04)
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

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo header
            HStack(spacing: 10) {
                Image("DriftLogo")
                    .resizable()
                    .interpolation(.high)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(width: 28, height: 28)
                    .shadow(color: Color.drift.opacity(0.2), radius: 4, y: 1)
                Text("Drift")
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.3)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)

            // Nav items
            VStack(spacing: 2) {
                ForEach(Tab.allCases) { tab in
                    SidebarItem(tab: tab, isActive: appState.currentTab == tab) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            appState.currentTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Live tracking indicator
            if tracker.isTracking {
                HStack(spacing: 8) {
                    Circle()
                        .fill(tracker.isPaused ? .orange : Color("Green"))
                        .frame(width: 6, height: 6)
                        .shadow(color: (tracker.isPaused ? Color.orange : Color("Green")).opacity(0.6), radius: 4)
                    Text(formatDuration(appState.session.totalMs))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    Spacer()
                    Text(tracker.isPaused ? "Paused" : "Tracking")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.03))
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tracking session: \(formatDuration(appState.session.totalMs)). \(tracker.isPaused ? "Paused" : "Active")")
            }

            // Pro CTA
            if appState.user?.plan != "pro" {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                        Text("Drift Pro")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text("AI focus coaching & unlimited history")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Button(action: { appState.currentTab = .settings }) {
                        Text("Upgrade")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                LinearGradient(
                                    colors: [Color.drift, Color.drift.opacity(0.8)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Upgrade to Drift Pro")
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            Divider().padding(.horizontal, 16).padding(.bottom, 10)

            // User
            HStack(spacing: 10) {
                if let user = appState.user {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.drift.opacity(0.2), Color.drift.opacity(0.08)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(user.initials)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.drift)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(user.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(user.plan.capitalized)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(user.displayName), \(user.plan) plan")
                } else {
                    Button(action: onSignIn) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 22))
                                .foregroundStyle(.quaternary)
                            Text("Sign In")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sign in to your account")
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 210)
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation sidebar")
    }

    // MARK: - Content

    private var mainContent: some View {
        ZStack {
            tabContent
                .id(appState.currentTab)
                .transition(.opacity.animation(.easeInOut(duration: 0.15)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
        .animation(.easeInOut(duration: 0.15), value: appState.currentTab)
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

// MARK: - Sidebar Item

struct SidebarItem: View {
    let tab: Tab
    let isActive: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                    .frame(width: 20)
                    .foregroundStyle(isActive ? Color.drift : (isHovered ? .primary : .secondary))
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .primary : (isHovered ? .primary : .secondary))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isActive ? Color.drift.opacity(0.1)
                        : (isHovered ? Color.primary.opacity(0.04) : .clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
