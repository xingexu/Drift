import SwiftUI
import AppKit

// MARK: - Root Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentScreen: AppState.AppScreen = .welcome

    var body: some View {
        ZStack {
            switch currentScreen {
            case .welcome:
                WelcomeView(
                    onGetStarted: { navigateTo(.onboarding) }
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
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            case .main:
                MainAppView()
                    .ignoresSafeArea(.container, edges: .top)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
            }
        }
        .preferredColorScheme(colorScheme)
        .font(TypeScale.bodyMd)
        .foregroundStyle(Color.driftText)
        .onAppear {
            currentScreen = appState.hasOnboarded ? .main : .welcome
        }
    }

    private func navigateTo(_ screen: AppState.AppScreen) {
        withAnimation(Anim.page) { currentScreen = screen }
    }

    private var colorScheme: ColorScheme? {
        guard currentScreen == .main else { return .dark }
        switch appState.theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

}

// MARK: - Main App (Sidebar + Topbar + Content)

struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tracker: WindowTracker
    @StateObject private var blocker = FocusBlocker.shared
    @State private var lastDetectedApp: String = ""
    @State private var windowSwitchSignal: String?
    @State private var statusBarFlash = false
    @State private var statusBarBlockedFlash = false
    @State private var keyEventMonitor: Any?

    private var showStatusBar: Bool {
        appState.focusModeActive || blocker.isBlocking
    }

    var body: some View {
        ZStack {
            DesertBackdrop(
                imageName: appState.currentTab.backgroundImageName,
                washOpacity: appState.currentTab.backgroundWashOpacity
            )
            .id(appState.currentTab.backgroundImageName)
            .transition(.opacity)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    if !isImmersiveFocus {
                        SidebarView()
                            .environment(\.colorScheme, .dark)
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Navigation sidebar")
                    }

                    VStack(spacing: 0) {
                        if !isImmersiveFocus {
                            TopbarView()
                                .environment(\.colorScheme, .dark)
                        }

                        mainContent
                    }
                }

                if showStatusBar && !isImmersiveFocus {
                    globalFocusStatusBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(appState.reduceMotion ? nil : Anim.page, value: appState.currentTab)
        .animation(appState.reduceMotion ? nil : Anim.tap, value: showStatusBar)
        .background(Color.driftBackground)
        .clipped()
        .tint(Color.sand)
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

    // MARK: - Global Keyboard Navigation

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
                DispatchQueue.main.async { appState.currentTab = .tracking }
                return nil
            case "2":
                DispatchQueue.main.async { appState.currentTab = .focus }
                return nil
            case "3":
                DispatchQueue.main.async { appState.currentTab = .history }
                return nil
            case "4":
                DispatchQueue.main.async { appState.currentTab = .settings }
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
            if appState.currentTab == .tracking {
                TrackingView()
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
        .clipped()
        .animation(appState.reduceMotion ? nil : Anim.page, value: appState.currentTab)
    }

    private var pageTransition: AnyTransition {
        appState.reduceMotion
            ? .opacity
            : .opacity.combined(with: .offset(y: 6))
    }

    private var isImmersiveFocus: Bool {
        appState.currentTab == .focus && appState.focusModeActive
    }

    // MARK: - Global Focus Status Bar

    private var globalFocusStatusBar: some View {
        HStack(spacing: Space.sm) {
            Rectangle()
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
                .background(Rectangle().fill(Color.productive.opacity(0.08)))
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
        return Color.driftPanel
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
    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.desertMutedText)

            Text(dateString)
                .font(TypeScale.caption)
                .foregroundStyle(Color.desertMutedText)
                .monospacedDigit()

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(height: 54)
        .background { DriftShellSurface(layer: .toolbar) }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.desertCreamText.opacity(0.12))
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
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

// MARK: - Sidebar View

private struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Namespace private var selectionNamespace
    @State private var brandAppeared = false
    @State private var brandHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader
            navSection
            Spacer(minLength: 0)
        }
        .frame(width: 220)
        .background { DriftShellSurface(layer: .sidebar) }
        .overlay(alignment: .trailing) {
            ZStack(alignment: .trailing) {
                Rectangle()
                    .fill(Color.desertCreamText.opacity(0.13))
                    .frame(width: 1)
                Rectangle()
                    .fill(Color.white.opacity(0.035))
                    .frame(width: 1)
                    .offset(x: -1)
            }
        }
        .onAppear {
            withAnimation(appState.reduceMotion ? nil : .easeOut(duration: 0.20)) {
                brandAppeared = true
            }
        }
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            PixelDLogo(size: 40, background: .sand, isHighlighted: brandHovered)

            Text("Drift")
                .font(PixelFont.font(22))
                .foregroundStyle(Color.desertCreamText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        }
        .padding(20)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(brandAppeared ? 1 : 0)
        .offset(y: brandAppeared || appState.reduceMotion ? 0 : 4)
        .contentShape(Rectangle())
        .onHover { brandHovered = $0 }
    }

    // MARK: - Navigation

    private var navSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 8) {
                ForEach(Tab.allCases) { tab in
                    SidebarNavItem(
                        icon: tab.icon,
                        iconSelected: tab.iconSelected,
                        label: tab.rawValue,
                        shortcutKey: tab.shortcutKey,
                        isSelected: appState.currentTab == tab,
                        selectionNamespace: selectionNamespace
                    ) {
                        appState.currentTab = tab
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, Space.xs)
        }
    }
}

// MARK: - Sidebar Nav Item

struct SidebarNavItem: View {
    let icon: String
    let iconSelected: String
    let label: String
    let shortcutKey: String
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let action: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false
    @FocusState private var isKeyboardFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                Image(systemName: pixelGlyph)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                            ? Color.sand
                            : (isHovered ? Color.desertCreamText.opacity(0.86) : Color.desertMutedText)
                    )
                    .frame(width: 24)

                Text(label)
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(
                        isSelected
                            ? Color.desertCreamText
                            : (isHovered ? Color.desertCreamText.opacity(0.86) : Color.desertMutedText)
                    )

                Spacer()

            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.sand.opacity(0.16))
                        .matchedGeometryEffect(id: "sidebar-selection", in: selectionNamespace)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.desertCreamText.opacity(0.055))
                }
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(Color.sand)
                        .frame(width: 3, height: 26)
                        .matchedGeometryEffect(id: "sidebar-indicator", in: selectionNamespace)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        Color.desertCreamText.opacity(isKeyboardFocused ? 0.58 : 0),
                        lineWidth: 1.5
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DriftResponsivePressStyle(reduceMotion: appState.reduceMotion))
        .focused($isKeyboardFocused)
        .onHover { isHovered = $0 }
        .animation(Anim.quick, value: isHovered)
        .animation(
            appState.reduceMotion ? nil : .spring(duration: 0.22, bounce: 0.08),
            value: isSelected
        )
        .accessibilityLabel("\(label), tab")
        .accessibilityValue(isSelected ? "selected" : "")
    }

    private var pixelGlyph: String {
        switch label {
        case "Today": return "sun.max"
        case "Focus": return "scope"
        case "History": return "clock.arrow.circlepath"
        default: return "gearshape"
        }
    }
}

private struct SidebarMiniCactus: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color.productive.opacity(0.32)).frame(width: 20, height: 3)
            Rectangle().fill(Color.productive.opacity(0.72)).frame(width: 6, height: 25).offset(y: -2)
            Rectangle().fill(Color.productive.opacity(0.38)).frame(width: 2, height: 25).offset(x: -2, y: -2)
            Rectangle().fill(Color.productive.opacity(0.80)).frame(width: 7, height: 4).offset(x: -6, y: -15)
            Rectangle().fill(Color.productive.opacity(0.70)).frame(width: 4, height: 11).offset(x: -9, y: -18)
            Rectangle().fill(Color.productive.opacity(0.76)).frame(width: 8, height: 4).offset(x: 7, y: -18)
            Rectangle().fill(Color.productive.opacity(0.66)).frame(width: 4, height: 12).offset(x: 10, y: -22)
        }
    }
}

// MARK: - Tab Extensions

extension Tab {
    var backgroundImageName: String {
        switch self {
        case .tracking: return "drift-tab-tracking"
        case .focus:    return "drift-tab-focus"
        case .history:  return "drift-tab-tracking"
        case .settings: return "drift-tab-settings"
        }
    }

    var backgroundWashOpacity: Double {
        switch self {
        case .tracking: return 0.34
        case .focus:    return 0.32
        case .history:  return 0.34
        case .settings: return 0.34
        }
    }

    var iconSelected: String {
        switch self {
        case .tracking: return "dot.radiowaves.left.and.right"
        case .focus:    return "shield.lefthalf.filled"
        case .history:  return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }

    var shortcutKey: String {
        switch self {
        case .tracking: return "1"
        case .focus:    return "2"
        case .history:  return "3"
        case .settings: return "4"
        }
    }
}
