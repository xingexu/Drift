import SwiftUI
import AppKit

private struct DriftSidebarWorld: View {
    @Environment(\.colorScheme) private var colorScheme
    let accent: Color

    var body: some View {
        DriftHomeBackdrop(mode: colorScheme == .dark ? .sidebarDark : .sidebarLight)
        .accessibilityHidden(true)
    }
}

private struct DriftHomeBackdrop: View {
    enum Mode {
        case contentDark
        case contentLight
        case sidebarDark
        case sidebarLight
    }

    let mode: Mode

    var body: some View {
        GeometryReader { proxy in
            Image("drift-home-scene", bundle: .module)
                .resizable()
                .interpolation(.none)
                .antialiased(false)
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(scale)
                .offset(x: xOffset(for: proxy.size), y: yOffset(for: proxy.size))
                .clipped()
                .overlay {
                    Rectangle().fill(overlayColor)
                }
                .overlay {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .allowsHitTesting(false)
    }

    private var scale: CGFloat {
        switch mode {
        case .contentDark, .contentLight: return 1.03
        case .sidebarDark, .sidebarLight: return 1.18
        }
    }

    private func xOffset(for size: CGSize) -> CGFloat {
        switch mode {
        case .contentDark, .contentLight: return 0
        case .sidebarDark, .sidebarLight: return -size.width * 0.12
        }
    }

    private func yOffset(for size: CGSize) -> CGFloat {
        switch mode {
        case .contentDark, .contentLight: return -size.height * 0.03
        case .sidebarDark, .sidebarLight: return -size.height * 0.02
        }
    }

    private var overlayColor: Color {
        switch mode {
        case .contentDark: return Color(red: 0.03, green: 0.02, blue: 0.08).opacity(0.18)
        case .contentLight: return Color.white.opacity(0.38)
        case .sidebarDark: return Color(red: 0.03, green: 0.02, blue: 0.08).opacity(0.38)
        case .sidebarLight: return Color.white.opacity(0.46)
        }
    }

    private var gradientColors: [Color] {
        switch mode {
        case .contentDark, .sidebarDark:
            return [
                Color(red: 0.02, green: 0.01, blue: 0.06).opacity(0.34),
                Color.clear,
                Color.black.opacity(0.22)
            ]
        case .contentLight, .sidebarLight:
            return [
                Color.white.opacity(0.28),
                Color.white.opacity(0.12),
                Color(red: 1.0, green: 0.74, blue: 0.50).opacity(0.18)
            ]
        }
    }
}

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
        switch appState.theme {
        case .light:  return .light
        case .dark:   return .dark
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
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SidebarView()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Navigation sidebar")

                Rectangle()
                    .fill(Color.border.opacity(0.55))
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
                DispatchQueue.main.async { withAnimation(Anim.tap) { appState.currentTab = .tracking } }
                return nil
            case "2":
                DispatchQueue.main.async { withAnimation(Anim.tap) { appState.currentTab = .focus } }
                return nil
            case "3":
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
            if appState.currentTab == .tracking {
                TrackingView()
                    .transition(pageTransition)
            }
            if appState.currentTab == .focus {
                StudyView()
                    .transition(pageTransition)
            }
            if appState.currentTab == .settings {
                SettingsView()
                    .transition(pageTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.driftBackground
                DriftHomeBackdrop(mode: resolvedBackdropMode)
            }
        }
        .animation(.easeOut(duration: 0.22), value: appState.currentTab)
    }

    private var resolvedBackdropMode: DriftHomeBackdrop.Mode {
        switch appState.theme {
        case .light: return .contentLight
        case .dark: return .contentDark
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? .contentDark
                : .contentLight
        }
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
    @EnvironmentObject private var tracker: WindowTracker

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.driftMuted)

            Text(dateString)
                .font(TypeScale.caption)
                .foregroundStyle(Color.driftMuted)
                .monospacedDigit()

            Spacer()

            StatusDot(status: tracker.isTracking ? .tracking : .idle)
            Text(tracker.isTracking ? "Tracking" : "Offline")
                .font(TypeScale.caption)
                .foregroundStyle(Color.driftText)
            Text(tracker.isTracking ? "Local capture" : "Local mode")
                .font(TypeScale.caption)
                .foregroundStyle(Color.driftMuted)
        }
        .padding(.horizontal, 28)
        .frame(height: 58)
        .background(
            Rectangle()
                .fill(Color.driftPanel.opacity(0.76))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.border.opacity(0.44))
                        .frame(height: 1)
                }
        )
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader
            navSection
            Spacer(minLength: 0)
            localOnlySection
        }
        .frame(width: 232)
        .background {
            DriftSidebarWorld(accent: appState.accentColor)
        }
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack(spacing: Space.md) {
            PixelDLogo(size: 42, background: appState.accentColor)

            Text("Drift")
                .font(PixelFont.font(18))
                .foregroundStyle(Color.driftText)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
        .padding(.top, 22)
        .padding(.bottom, 32)
    }

    // MARK: - Navigation

    private var navSection: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text("DRIFT")
                .font(TypeScale.tiny)
                .tracking(0)
                .foregroundStyle(Color.driftMuted.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.top, 0)
                .padding(.bottom, 10)

            VStack(spacing: 4) {
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
            .padding(.horizontal, Space.sm)
            .padding(.bottom, Space.xs)
        }
    }

    // MARK: - Local State

    private var localOnlySection: some View {
        HStack(spacing: Space.sm) {
            Rectangle()
                .fill(Color.productive)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text("LOCAL MODE")
                    .font(TypeScale.tiny)
                    .tracking(0)
                    .foregroundStyle(Color.driftText)
                Text("Your activity stays on this Mac")
                    .font(TypeScale.tiny)
                    .foregroundStyle(Color.driftMuted)
            }
            Spacer()
            SidebarMiniCactus()
                .frame(width: 24, height: 34)
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.driftPanel.opacity(0.78))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.border.opacity(0.42), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.22), radius: 0, x: 3, y: 3)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Local mode. Your activity stays on this Mac")
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
                Image(systemName: pixelGlyph)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                            ? appState.accentColor
                            : (isHovered ? Color.driftText.opacity(0.82) : Color.driftMuted.opacity(0.82))
                    )
                    .frame(width: 24)

                Text(label)
                    .font(TypeScale.caption)
                    .tracking(0)
                    .foregroundStyle(
                        isSelected
                            ? Color.driftText
                            : (isHovered ? Color.driftText.opacity(0.82) : Color.driftMuted)
                    )

            Spacer()

            Rectangle()
                .fill(appState.accentColor)
                    .frame(width: 7, height: 7)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? appState.accentColor.opacity(0.11)
                            : (isHovered ? Color.driftPanelRaised.opacity(0.28) : Color.clear)
                    )
                    .background {
                        if isSelected || isHovered {
                            Rectangle().fill(Color.driftPanel.opacity(0.50))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isSelected ? appState.accentColor.opacity(0.38) : Color.clear,
                                lineWidth: 1
                            )
                    }
                    .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isSelected)
                    .animation(Anim.hover, value: isHovered)
            }
            // Left accent bar — matches handoff `inset 2px 0 0 accent`
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(appState.accentColor)
                    .frame(width: 2)
                    .padding(.vertical, 0)
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

    private var pixelGlyph: String {
        switch label {
        case "Tracking": return "waveform.path.ecg"
        case "Focus + Blocking": return "scope"
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
    var iconSelected: String {
        switch self {
        case .tracking: return "dot.radiowaves.left.and.right"
        case .focus:    return "shield.lefthalf.filled"
        case .settings: return "gearshape.fill"
        }
    }

    var shortcutKey: String {
        switch self {
        case .tracking: return "1"
        case .focus:    return "2"
        case .settings: return "3"
        }
    }
}
