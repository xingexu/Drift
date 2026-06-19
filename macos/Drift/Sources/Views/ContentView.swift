import SwiftUI
import AppKit

// MARK: - Sidebar Dark Background

/// Deep dark navy used as the solid sidebar background.
/// Consistent across light and dark mode — the sidebar always looks dark.
private let sidebarBackgroundColor = Color(red: 0.035, green: 0.044, blue: 0.067) // #090B11

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
                MainAppView(onSignIn: { navigateTo(.auth) })
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
            }
        }
        .preferredColorScheme(colorScheme)
        .fontDesign(typographyDesign)
        .onAppear {
            currentScreen = appState.hasOnboarded ? .main : .welcome
        }
    }

    private func navigateTo(_ screen: AppState.AppScreen) {
        withAnimation(Anim.page) { currentScreen = screen }
    }

    private var colorScheme: ColorScheme? {
        switch appState.theme {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }

    /// Maps the Typography preference to a SwiftUI font design so the
    /// Customize → Typography control actually changes the app's type.
    /// Fonts that opt into an explicit design (e.g. `.monospaced` numerals)
    /// keep theirs; everything else inherits this.
    private var typographyDesign: Font.Design {
        switch appState.typography {
        case "Serif": return .serif
        case "Mono":  return .monospaced
        default:      return .default   // "Sora" / system sans
        }
    }
}

// MARK: - Main App (Sidebar + Topbar + Content)

struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker
    @StateObject private var blocker = FocusBlocker.shared
    let onSignIn: () -> Void

    @State private var lastDetectedApp: String = ""
    @State private var windowSwitchSignal: String?
    @State private var statusBarFlash = false
    @State private var statusBarBlockedFlash = false
    @State private var keyEventMonitor: Any?

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
                    .fill(Color.black.opacity(0.30))
                    .frame(width: 1)

                VStack(spacing: 0) {
                    // Sticky topbar
                    TopbarView()

                    // Tab content with smooth page transitions
                    mainContent
                }
            }

            if showStatusBar {
                globalFocusStatusBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            if appState.showCustomizePanel {
                CustomizePanel { appState.showCustomizePanel = false }
                    .environmentObject(appState)
                    .padding(.top, 50)
                    .padding(.trailing, 12)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 20, y: -8)),
                        removal: .opacity.combined(with: .offset(x: 20, y: -8))
                    ))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: appState.showCustomizePanel)
        .animation(Anim.tap, value: showStatusBar)
        .onAppear  { setupKeyboardNavigation() }
        .onDisappear { teardownKeyboardNavigation() }
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

    // MARK: - Global Keyboard Navigation (1–5 bare keys)

    /// Intercepts bare number-key presses and routes them to tabs.
    /// Immediately returns the event unchanged when any text input is focused
    /// so typing in text fields is never interrupted.
    private func setupKeyboardNavigation() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak appState] event in
            // Pass through if any modifier key is held (let ⌘1–5 go through AppKit commands)
            guard event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty else {
                return event
            }
            // Pass through when a text-input field has focus (NSText is the field-editor base class)
            if let fr = NSApp.keyWindow?.firstResponder, fr is NSText {
                return event
            }
            guard let appState else { return event }
            switch event.charactersIgnoringModifiers {
            case "1":
                DispatchQueue.main.async { withAnimation(Anim.tap) { appState.currentTab = .home } }
                return nil
            case "2":
                DispatchQueue.main.async { withAnimation(Anim.tap) { appState.currentTab = .session } }
                return nil
            case "3":
                DispatchQueue.main.async { withAnimation(Anim.tap) { appState.currentTab = .focus } }
                return nil
            case "4":
                DispatchQueue.main.async { withAnimation(Anim.tap) { appState.currentTab = .history } }
                return nil
            case "5":
                DispatchQueue.main.async { withAnimation(Anim.tap) { appState.currentTab = .settings } }
                return nil
            default:
                return event
            }
        }
    }

    private func teardownKeyboardNavigation() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    // MARK: - Tab Content with Transitions

    /// Explicit if-conditions guarantee SwiftUI sees each tab as a distinct view,
    /// which makes insertion / removal transitions fire reliably.
    private var mainContent: some View {
        ZStack(alignment: .topLeading) {
            if appState.currentTab == .home {
                HomeView()
                    .transition(pageTransition)
            }
            if appState.currentTab == .session {
                SessionView()
                    .transition(pageTransition)
            }
            if appState.currentTab == .focus {
                StudyView()
                    .transition(pageTransition)
            }
            if appState.currentTab == .history {
                HistoryView()
                    .transition(pageTransition)
            }
            if appState.currentTab == .settings {
                SettingsView()
                    .transition(pageTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
        .animation(.easeOut(duration: 0.22), value: appState.currentTab)
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 0, y: 14)),
            removal:   .opacity.combined(with: .offset(x: 0, y: -6))
        )
    }

    // MARK: - Global Focus Status Bar

    private var globalFocusStatusBar: some View {
        HStack(spacing: Space.sm) {
            Circle()
                .fill(blocker.isBlocking ? Color.productive : appState.accentColor)
                .frame(width: 6, height: 6)

            Text(blocker.isBlocking ? "BLOCKING" : "FOCUS")
                .font(TypeScale.tiny)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(0.8)

            if blocker.isBlocking {
                Text(blocker.timeRemainingFormatted)
                    .font(TypeScale.monoSm)
                    .foregroundStyle(appState.accentColor)
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
}

// MARK: - Topbar

struct TopbarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker

    @State private var buttonHovered: String? = nil

    var body: some View {
        HStack(spacing: Space.md) {
            // Calendar + date
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)

            Text(dateString)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            // Tracking status pill
            trackingPill

            Spacer()

            // Icon buttons
            topbarIconButton(
                icon: appState.theme == .dark ? "sun.min" : "moon",
                id: "theme",
                label: appState.theme == .dark ? "Switch to light mode" : "Switch to dark mode"
            ) {
                appState.setTheme(appState.theme == .dark ? .light : .dark)
            }
            topbarIconButton(icon: "bell", id: "bell", label: "Notification settings") {
                withAnimation(Anim.tap) { appState.currentTab = .settings }
            }
            topbarIconButton(icon: "slider.horizontal.3", id: "sliders", label: "Customize appearance") {
                appState.showCustomizePanel.toggle()
            }
        }
        .padding(.horizontal, Space.xl)
        .frame(height: 44)
        .background(
            Color(.windowBackgroundColor).opacity(0.88)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.sep.opacity(0.12))
                        .frame(height: 0.5)
                }
        )
        .accessibilityElement(children: .contain)
    }

    private var trackingPill: some View {
        HStack(spacing: Space.xs) {
            // Live dot
            ZStack {
                if tracker.isTracking && !tracker.isPaused {
                    Circle()
                        .fill(Color.productive.opacity(0.35))
                        .frame(width: 7, height: 7)
                        .modifier(TopbarPulseRing())
                }
                Circle()
                    .fill(tracker.isTracking && !tracker.isPaused ? Color.productive : Color(.tertiaryLabelColor))
                    .frame(width: 7, height: 7)
            }
            .frame(width: 12, height: 12)

            Text(tracker.isTracking && !tracker.isPaused ? "Tracking" : "Idle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tracker.isTracking && !tracker.isPaused ? .primary : .secondary)
        }
        .padding(.horizontal, Space.sm + 2)
        .padding(.vertical, Space.xxs + 2)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.05))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5))
        )
        .animation(Anim.quick, value: tracker.isTracking)
        .accessibilityLabel(tracker.isTracking ? "Tracking active" : "Tracking idle")
    }

    private func topbarIconButton(icon: String, id: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13.5, weight: .regular))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(buttonHovered == id ? Color.primary.opacity(0.07) : Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(Color.border, lineWidth: 0.5)
                        )
                )
                .foregroundStyle(buttonHovered == id ? Color.primary : Color.secondary)
                .animation(Anim.hover, value: buttonHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in buttonHovered = hovering ? id : nil }
        .accessibilityLabel(label)
        .help(label)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    private var dateString: String {
        Self.dateFormatter.string(from: Date())
    }
}

// MARK: - Topbar Pulse Ring

private struct TopbarPulseRing: ViewModifier {
    @State private var pulsing = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 2.6 : 1)
            .opacity(pulsing ? 0 : 0.7)
            .animation(Anim.breathe, value: pulsing)
            .onAppear { pulsing = true }
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
        .background(sidebarBackgroundColor)
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack(spacing: Space.sm) {
            Image("DriftLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)

            Text("Drift")
                .font(.system(size: 15, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Color.white)

            Spacer()
        }
        .padding(.horizontal, Space.md)
        .frame(height: 52)
        .padding(.top, Space.xxs)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.white.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Navigation

    private var navSection: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            // WORKSPACE section label (matches handoff)
            Text("WORKSPACE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Color.white.opacity(0.30))
                .padding(.horizontal, Space.md)
                .padding(.top, Space.xs)
                .padding(.bottom, Space.xxs)

            VStack(spacing: Space.xxxs) {
                ForEach(Tab.allCases) { tab in
                    SidebarNavItem(
                        icon: tab.icon,
                        iconSelected: tab.iconSelected,
                        label: tab.rawValue,
                        shortcutKey: tab.shortcutKey,
                        isSelected: appState.currentTab == tab
                    ) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            appState.currentTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, Space.xs)
            .padding(.bottom, Space.xs)
        }
    }

    // MARK: - Live Tracking Widget

    @ViewBuilder
    private var trackingStatusSection: some View {
        if tracker.isTracking {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.5)
                    .padding(.horizontal, Space.md)
                    .padding(.bottom, Space.xs)

                VStack(alignment: .leading, spacing: Space.xxs) {
                    HStack(spacing: Space.xs) {
                        StatusDot(status: tracker.isPaused ? .paused : .tracking)

                        Text(tracker.isPaused ? "Paused" : "Live")
                            .font(TypeScale.tiny)
                            .fontWeight(.bold)
                            .foregroundStyle(tracker.isPaused ? Color.streak : Color.productive)
                            .tracking(0.6)
                            .textCase(.uppercase)

                        Spacer()

                        Text(formatDuration(appState.session.totalMs))
                            .font(TypeScale.monoXs)
                            .foregroundStyle(tracker.isPaused ? Color.streak : Color.productive)
                            .contentTransition(.numericText())
                            .animation(Anim.count, value: appState.session.totalMs)
                    }

                    if !tracker.activeApp.isEmpty {
                        Text(tracker.activeApp)
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.white.opacity(0.70))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(
                            tracker.isPaused
                                ? Color.streak.opacity(0.10)
                                : Color.productive.opacity(0.10)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(
                                    tracker.isPaused
                                        ? Color.streak.opacity(0.22)
                                        : Color.productive.opacity(0.22),
                                    lineWidth: 0.5
                                )
                        }
                }
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
                        .foregroundStyle(appState.accentColor)

                    VStack(alignment: .leading, spacing: Space.xxxs) {
                        Text("Drift Pro")
                            .font(TypeScale.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.white.opacity(0.88))
                        Text("Unlock advanced reports")
                            .font(TypeScale.tiny)
                            .foregroundStyle(Color.white.opacity(0.40))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(appState.accentColor.opacity(0.5))
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Space.xs)
            .padding(.bottom, Space.sm)
            .accessibilityLabel("Upgrade to Drift Pro — unlock advanced reports")
        }
    }

    // MARK: - Divider

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
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
                            .fill(appState.accentColor.opacity(0.18))
                            .frame(width: 24, height: 24)
                        Text(user.initials)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(appState.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(user.displayName)
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                        Text(user.plan.capitalized)
                            .font(TypeScale.tiny)
                            .foregroundStyle(Color.white.opacity(0.38))
                    }

                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(user.displayName), \(user.plan) plan")
            } else {
                Button(action: onSignIn) {
                    HStack(spacing: Space.sm) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 24, height: 24)
                            Image(systemName: "person")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                        Text("Sign in")
                            .font(TypeScale.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.white.opacity(0.45))
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
    let shortcutKey: String
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Image(systemName: isSelected ? iconSelected : icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? appState.accentColor
                            : (isHovered ? Color.white.opacity(0.70) : Color.white.opacity(0.38))
                    )
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isSelected
                            ? Color.white
                            : (isHovered ? Color.white.opacity(0.72) : Color.white.opacity(0.55))
                    )

                Spacer()

                // Keyboard shortcut hint
                Text(shortcutKey)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(
                        isSelected
                            ? appState.accentColor.opacity(0.6)
                            : Color.white.opacity(0.18)
                    )
                    .padding(.horizontal, Space.xxs + 1)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.white.opacity(isSelected ? 0.06 : 0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                    )
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs + 1)
            .background {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(
                        isSelected
                            ? appState.accentColor.opacity(0.12)
                            : (isHovered ? Color.white.opacity(0.06) : Color.clear)
                    )
                    .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isSelected)
                    .animation(Anim.hover, value: isHovered)
            }
            // Left accent bar — matches handoff `inset 2px 0 0 accent`
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(appState.accentColor)
                    .frame(width: 2.5)
                    .padding(.leading, -Space.md + 0.5)
                    .padding(.vertical, Space.xs)
                    .opacity(isSelected ? 1 : 0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isSelected)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(label), tab")
        .accessibilityValue(isSelected ? "selected" : "")
    }
}

// MARK: - Tab Extensions

extension Tab {
    var iconSelected: String {
        switch self {
        case .home:     return "house.fill"
        case .session:  return "chart.bar.fill"
        case .focus:    return "timer"
        case .history:  return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }

    var shortcutKey: String {
        switch self {
        case .home:     return "1"
        case .session:  return "2"
        case .focus:    return "3"
        case .history:  return "4"
        case .settings: return "5"
        }
    }
}

// MARK: - Customize Panel

struct CustomizePanel: View {
    @EnvironmentObject var appState: AppState
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Customize")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            // APPEARANCE
            customizeSection("APPEARANCE") {
                segmentedRow(
                    selection: Binding(
                        get: { appState.theme.rawValue == "dark" ? "Dark" : "Light" },
                        set: { appState.setTheme($0 == "Dark" ? .dark : .light) }
                    ),
                    options: ["Light", "Dark"]
                )
            }

            // DENSITY
            customizeSection("DENSITY") {
                segmentedRow(
                    selection: Binding(
                        get: { appState.density },
                        set: { appState.setDensity($0) }
                    ),
                    options: ["Compact", "Comfortable", "Spacious"]
                )
            }

            // TYPOGRAPHY
            customizeSection("TYPOGRAPHY") {
                segmentedRow(
                    selection: Binding(
                        get: { appState.typography },
                        set: { appState.setTypography($0) }
                    ),
                    options: ["Sora", "Serif", "Mono"]
                )
            }

            // HOME LAYOUT
            customizeSection("HOME LAYOUT") {
                segmentedRow(
                    selection: Binding(
                        get: { appState.homeLayout },
                        set: { appState.setHomeLayout($0) }
                    ),
                    options: ["Hero", "Bento", "Stack"]
                )
            }
        }
        .padding(20)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 6)
    }

    private func customizeSection<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
            content()
        }
    }

    private func segmentedRow(selection: Binding<String>, options: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { opt in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection.wrappedValue = opt }
                } label: {
                    Text(opt)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(selection.wrappedValue == opt ? .primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if selection.wrappedValue == opt {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.primary.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
