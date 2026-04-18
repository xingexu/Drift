import SwiftUI

// MARK: - Root Content View

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
        case .light:  return .light
        case .dark:   return .dark
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
                SidebarView(onSignIn: onSignIn)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Navigation sidebar")

                Rectangle()
                    .fill(Color.sep.opacity(0.3))
                    .frame(width: 0.5)

                mainContent
            }

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

    // MARK: - Global Focus Status Bar

    private var globalFocusStatusBar: some View {
        HStack(spacing: Space.sm) {
            Circle()
                .fill(blocker.isBlocking ? Color.productive : Color.accent)
                .frame(width: 6, height: 6)

            Text(blocker.isBlocking ? "BLOCKING" : "FOCUS")
                .font(TypeScale.tiny)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(0.8)

            if blocker.isBlocking {
                Text(blocker.timeRemainingFormatted)
                    .font(TypeScale.monoSm)
                    .foregroundStyle(Color.accent)
                    .contentTransition(.numericText())
                    .animation(Anim.count, value: blocker.timeRemainingFormatted)
            }

            Spacer()

            if let app = windowSwitchSignal {
                HStack(spacing: Space.xxs) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.streak.opacity(0.8))
                    Text(app)
                        .font(TypeScale.tiny)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            if blocker.isBlocking && blocker.blockedAttempts > 0 {
                HStack(spacing: Space.xxxs) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.productive.opacity(0.7))
                    Text("\(blocker.blockedAttempts)")
                        .font(TypeScale.tiny)
                        .fontDesign(.monospaced)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.productive)
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
        if statusBarBlockedFlash { return Color.distraction.opacity(0.06) }
        if statusBarFlash        { return Color.streak.opacity(0.04) }
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

    // MARK: - Main Content Area

    private var mainContent: some View {
        ZStack {
            tabContent
                .id(appState.currentTab)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 6, y: 0)),
                        removal:   .opacity.combined(with: .offset(x: -6, y: 0))
                    )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
        .animation(Anim.appear, value: appState.currentTab)
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

// MARK: - Sidebar View

private struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader
            navSection
            Spacer(minLength: 0)
            trackingStatusSection
            proCTASection
            sidebarDivider
            userSection
        }
        .frame(width: 210)
        .background(Color(.windowBackgroundColor).opacity(0.95))
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack(spacing: Space.sm) {
            Image("DriftLogo")
                .resizable()
                .interpolation(.high)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .frame(width: 22, height: 22)
            Text("Drift")
                .font(.system(size: 15, weight: .bold, design: .default))
                .tracking(-0.3)
                .foregroundStyle(Color(.labelColor))
            Spacer()
        }
        .padding(.horizontal, Space.md)
        .frame(height: 52)
        .padding(.top, Space.xxs)
    }

    // MARK: - Navigation Items

    private var navSection: some View {
        VStack(spacing: Space.xxxs) {
            ForEach(Tab.allCases) { tab in
                SidebarNavItem(
                    icon: tab.icon,
                    iconSelected: tab.iconSelected,
                    label: tab.rawValue,
                    isSelected: appState.currentTab == tab
                ) {
                    withAnimation(Anim.tap) { appState.currentTab = tab }
                }
            }
        }
        .padding(.horizontal, Space.xs)
        .padding(.bottom, Space.xs)
    }

    // MARK: - Live Tracking Status

    @ViewBuilder
    private var trackingStatusSection: some View {
        if tracker.isTracking {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.sep.opacity(0.25))
                    .frame(height: 0.5)
                    .padding(.horizontal, Space.md)
                    .padding(.bottom, Space.sm)

                HStack(spacing: Space.xs) {
                    StatusDot(status: tracker.isPaused ? .paused : .tracking)

                    VStack(alignment: .leading, spacing: Space.xxxs) {
                        Text(tracker.isPaused ? "Paused" : "Tracking")
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(tracker.isPaused ? Color.streak : Color.productive)
                        Text(formatDuration(appState.session.totalMs))
                            .font(TypeScale.monoXs)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(Anim.count, value: appState.session.totalMs)
                    }

                    Spacer()
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .padding(.horizontal, Space.xs)
                .padding(.bottom, Space.sm)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Session \(tracker.isPaused ? "paused" : "active"): \(formatDuration(appState.session.totalMs))"
                )
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Pro CTA

    @ViewBuilder
    private var proCTASection: some View {
        if appState.user?.plan != "pro" {
            Button(action: { withAnimation(Anim.tap) { appState.currentTab = .settings } }) {
                HStack(spacing: Space.xs) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accent)

                    VStack(alignment: .leading, spacing: Space.xxxs) {
                        Text("Upgrade to Pro")
                            .font(TypeScale.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accent)
                        Text("Unlock all features")
                            .font(TypeScale.tiny)
                            .foregroundStyle(Color.accent.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.accent.opacity(0.4))
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.accent.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(Color.accent.opacity(0.18), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Space.xs)
            .padding(.bottom, Space.sm)
            .accessibilityLabel("Upgrade to Drift Pro")
        }
    }

    // MARK: - Divider

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Color.sep.opacity(0.3))
            .frame(height: 0.5)
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.sm)
    }

    // MARK: - User Row

    private var userSection: some View {
        Group {
            if let user = appState.user {
                HStack(spacing: Space.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.accent.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Text(user.initials)
                            .font(TypeScale.tiny)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.accent)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(user.displayName)
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(.labelColor))
                            .lineLimit(1)
                        Text(user.plan.capitalized)
                            .font(TypeScale.tiny)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(user.displayName), \(user.plan) plan")
            } else {
                Button(action: onSignIn) {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(.quaternaryLabelColor))
                        Text("Sign In")
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sign in to your account")
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.lg)
    }
}

// MARK: - Sidebar Nav Item

struct SidebarNavItem: View {
    let icon: String
    let iconSelected: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Image(systemName: isSelected ? iconSelected : icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? Color.accent
                            : (isHovered ? Color(.labelColor) : Color(.secondaryLabelColor))
                    )
                    .frame(width: 16)

                Text(label)
                    .font(isSelected ? TypeScale.heading : TypeScale.bodyMd)
                    .foregroundStyle(
                        isSelected
                            ? Color.accent
                            : (isHovered ? Color(.labelColor) : Color(.secondaryLabelColor))
                    )

                Spacer()
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.accent.opacity(0.08))
                }
                if isHovered && !isSelected {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                }
            }
            // Accent left-edge indicator bar (3pt)
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.accent)
                        .frame(width: 3)
                        .padding(.leading, -Space.md)
                }
            }
            .contentShape(Rectangle())
            .animation(Anim.hover, value: isHovered)
            .animation(Anim.tap,   value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Tab: Selected Icon Mapping

private extension Tab {
    /// Filled SF Symbol variant used when this tab is selected.
    var iconSelected: String {
        switch self {
        case .home:     return "house.fill"
        case .session:  return "chart.bar.fill"
        case .focus:    return "timer"
        case .history:  return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
}
