import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetConfirmation = false
    @State private var showResetSuccess = false
    @State private var expandedSections: Set<SettingsSectionID> = Set(SettingsSectionID.allCases)
    @State private var checkoutError: String?
    @State private var showCheckoutError = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                ForEach(SettingsSectionID.allCases) { section in
                    sectionView(for: section)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(28)
        }
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will permanently erase all local data including session history, preferences, and sign-in state. This action cannot be undone.")
        }
        .alert("Data Reset Complete", isPresented: $showResetSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("All local data has been cleared and settings restored to defaults.")
        }
        .alert("Checkout Error", isPresented: $showCheckoutError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(checkoutError ?? "An unexpected error occurred. Please try again.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
            Text("Customize your Drift experience")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Section Router

    @ViewBuilder
    private func sectionView(for section: SettingsSectionID) -> some View {
        switch section {
        case .appearance:
            appearanceSection
        case .tracking:
            trackingSection
        case .shortcuts:
            shortcutsSection
        case .account:
            accountSection
        case .about:
            aboutSection
        case .dangerZone:
            dangerZoneSection
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        CollapsibleSettingsSection(
            id: .appearance,
            title: "Appearance",
            icon: "paintbrush",
            expandedSections: $expandedSections
        ) {
            SettingsRow(icon: "paintbrush", label: "Theme", hint: "Choose light, dark, or follow system") {
                Picker("Theme", selection: Binding(
                    get: { appState.theme },
                    set: { appState.setTheme($0) }
                )) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Label(theme.label, systemImage: theme.icon).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .accessibilityLabel("Theme selector")
                .accessibilityValue(appState.theme.label)
                .accessibilityHint("Choose between light, dark, or system theme")
            }
        }
    }

    // MARK: - Tracking

    private var trackingSection: some View {
        CollapsibleSettingsSection(
            id: .tracking,
            title: "Tracking",
            icon: "scope",
            expandedSections: $expandedSections
        ) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    label: "Launch at Login",
                    hint: "Start Drift automatically when you log in",
                    icon: "power",
                    isOn: Binding(
                        get: { appState.launchAtLogin },
                        set: { newValue in
                            appState.launchAtLogin = newValue
                            UserDefaults.standard.set(newValue, forKey: "drift_launch_login")
                        }
                    )
                )

                SettingsDivider()

                SettingsToggleRow(
                    label: "Desktop Notifications",
                    hint: "Get notified about drift events",
                    icon: "bell",
                    isOn: Binding(
                        get: { appState.notificationsEnabled },
                        set: { newValue in
                            appState.notificationsEnabled = newValue
                            UserDefaults.standard.set(newValue, forKey: "drift_notifications")
                        }
                    )
                )

                SettingsDivider()

                SettingsRow(icon: "moon.zzz", label: "Idle Timeout", hint: "Pause tracking after inactivity") {
                    Picker("Idle Timeout", selection: Binding(
                        get: { appState.idleTimeout },
                        set: { newValue in
                            appState.idleTimeout = newValue
                            UserDefaults.standard.set(newValue, forKey: "drift_idle_timeout")
                        }
                    )) {
                        Text("2 min").tag(120)
                        Text("5 min").tag(300)
                        Text("10 min").tag(600)
                        Text("15 min").tag(900)
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    .accessibilityLabel("Idle timeout duration")
                    .accessibilityValue(idleTimeoutLabel)
                    .accessibilityHint("Select how long before tracking pauses due to inactivity")
                }
            }
        }
    }

    private var idleTimeoutLabel: String {
        switch appState.idleTimeout {
        case 120: return "2 minutes"
        case 300: return "5 minutes"
        case 600: return "10 minutes"
        case 900: return "15 minutes"
        default: return "\(appState.idleTimeout / 60) minutes"
        }
    }

    // MARK: - Keyboard Shortcuts

    private var shortcutsSection: some View {
        CollapsibleSettingsSection(
            id: .shortcuts,
            title: "Keyboard Shortcuts",
            icon: "command",
            expandedSections: $expandedSections
        ) {
            VStack(spacing: 0) {
                KeyboardShortcutRow(label: "Toggle Tracking", keys: ["\u{2318}", "\u{21E7}", "D"])
                SettingsDivider()
                KeyboardShortcutRow(label: "Reset Session", keys: ["\u{2318}", "\u{21E7}", "R"])
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        CollapsibleSettingsSection(
            id: .account,
            title: "Account",
            icon: "person.circle",
            expandedSections: $expandedSections
        ) {
            if let user = appState.user {
                signedInAccountContent(user: user)
            } else {
                signedOutAccountContent
            }
        }
    }

    private func signedInAccountContent(user: User) -> some View {
        VStack(spacing: 0) {
            SettingsRow(icon: "envelope", label: "Email") {
                Text(user.email)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel("Email address")
                    .accessibilityValue(user.email)
            }

            SettingsDivider()

            SettingsRow(icon: "crown", label: "Plan") {
                PlanBadge(plan: user.plan)
            }

            SettingsDivider()

            if user.plan == "free" {
                SettingsActionButton(
                    title: "Upgrade to Pro",
                    icon: "sparkles",
                    style: .accent
                ) {
                    upgradeToPro()
                }
            } else {
                SettingsActionButton(
                    title: "Manage Subscription",
                    icon: "creditcard",
                    style: .secondary
                ) {
                    Task { await openBillingPortal() }
                }
            }

            SettingsDivider()

            SettingsActionButton(
                title: "Sign Out",
                icon: "rectangle.portrait.and.arrow.right",
                style: .destructive
            ) {
                appState.logout()
            }
        }
    }

    private var signedOutAccountContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.drift.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Not signed in")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Sign in to sync your data across devices.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Not signed in. Sign in to sync your data across devices.")

            SettingsActionButton(
                title: "Sign In",
                icon: "person.crop.circle",
                style: .accent
            ) {
                appState.showSignIn = true
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        CollapsibleSettingsSection(
            id: .about,
            title: "About",
            icon: "info.circle",
            expandedSections: $expandedSections
        ) {
            VStack(spacing: 0) {
                SettingsRow(icon: "number", label: "Version") {
                    Text(appVersionString)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("App version")
                        .accessibilityValue(appVersionString)
                }

                SettingsDivider()

                SettingsRow(icon: "globe", label: "Website") {
                    SettingsExternalLink(title: "Visit drift.app") {
                        if let url = URL(string: "https://drift.app") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let build, !build.isEmpty, build != version {
            return "\(version) (\(build))"
        }
        return version
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        CollapsibleSettingsSection(
            id: .dangerZone,
            title: "Danger Zone",
            icon: "exclamationmark.triangle",
            expandedSections: $expandedSections
        ) {
            SettingsActionButton(
                title: "Reset All Data",
                icon: "trash",
                style: .destructive
            ) {
                showResetConfirmation = true
            }
            .accessibilityHint("Opens a confirmation dialog before erasing all data")
        }
    }

    // MARK: - Computed Properties

    private var planColor: Color {
        switch appState.user?.plan {
        case "pro": return Color.drift
        case "team": return .purple
        default: return .secondary
        }
    }

    // MARK: - Actions

    private func upgradeToPro() {
        Task {
            do {
                let response = try await APIClient.shared.startCheckout(plan: "pro", interval: "month")
                if let url = URL(string: response.url) {
                    NSWorkspace.shared.open(url)
                } else {
                    checkoutError = "Received an invalid checkout URL. Please try again."
                    showCheckoutError = true
                }
            } catch {
                checkoutError = "Could not start checkout: \(error.localizedDescription)"
                showCheckoutError = true
            }
        }
    }

    private func openBillingPortal() async {
        do {
            let response = try await APIClient.shared.openBillingPortal()
            if let url = URL(string: response.url) {
                NSWorkspace.shared.open(url)
            } else {
                checkoutError = "Received an invalid portal URL. Please try again."
                showCheckoutError = true
            }
        } catch {
            checkoutError = "Could not open billing portal: \(error.localizedDescription)"
            showCheckoutError = true
        }
    }

    private func resetAllData() {
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "com.drift.app"
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        appState.logout()
        appState.session.reset()
        appState.pastSessions.removeAll()
        appState.currentStreak = 0
        appState.totalTrackedMs = 0
        appState.theme = .system
        appState.idleTimeout = 300
        appState.notificationsEnabled = true
        appState.launchAtLogin = true
        showResetSuccess = true
    }
}

// MARK: - Section Identifier

enum SettingsSectionID: String, CaseIterable, Identifiable {
    case appearance
    case tracking
    case shortcuts
    case account
    case about
    case dangerZone

    var id: String { rawValue }
}

// MARK: - Collapsible Settings Section

struct CollapsibleSettingsSection<Content: View>: View {
    let id: SettingsSectionID
    let title: String
    let icon: String
    @Binding var expandedSections: Set<SettingsSectionID>
    @ViewBuilder let content: () -> Content

    private var isExpanded: Bool {
        expandedSections.contains(id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header (tappable to collapse/expand)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isExpanded {
                        expandedSections.remove(id)
                    } else {
                        expandedSections.insert(id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) section")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Double-tap to \(isExpanded ? "collapse" : "expand") this section")
            .padding(.bottom, isExpanded ? 10 : 0)

            // Collapsible content
            if isExpanded {
                VStack(spacing: 0) {
                    content()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                        )
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                    )
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }
}

// MARK: - Reusable Settings Row

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let label: String
    var hint: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 20, alignment: .center)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                    if let hint {
                        Text(hint)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            trailing()
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let label: String
    let hint: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn.animation(.easeInOut(duration: 0.2))) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 20, alignment: .center)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "Enabled" : "Disabled")
        .accessibilityHint(hint)
    }
}

// MARK: - Settings Divider

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}

// MARK: - Keyboard Shortcut Row

struct KeyboardShortcutRow: View {
    let label: String
    let keys: [String]

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            HStack(spacing: 3) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    Text(key)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .frame(minWidth: 22, minHeight: 22)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(.controlBackgroundColor))
                                .shadow(color: .black.opacity(0.06), radius: 0.5, y: 0.5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(keys.joined(separator: " "))")
    }
}

// MARK: - Plan Badge

private struct PlanBadge: View {
    let plan: String

    private var color: Color {
        switch plan {
        case "pro": return Color.drift
        case "team": return .purple
        default: return .secondary
        }
    }

    var body: some View {
        Text(plan.capitalized)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .accessibilityLabel("Current plan")
            .accessibilityValue(plan.capitalized)
    }
}

// MARK: - Settings Action Button

enum SettingsButtonStyle {
    case accent, secondary, destructive
}

struct SettingsActionButton: View {
    let title: String
    let icon: String
    let style: SettingsButtonStyle
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    private var foregroundColor: Color {
        switch style {
        case .accent: return .white
        case .secondary: return .primary
        case .destructive: return Color("Red")
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .accent:
            return isPressed ? Color.drift.opacity(0.8) : Color.drift
        case .secondary:
            return Color.primary.opacity(isPressed ? 0.1 : (isHovered ? 0.08 : 0.05))
        case .destructive:
            return Color("Red").opacity(isPressed ? 0.16 : (isHovered ? 0.12 : 0.06))
        }
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.1)) {
                    isPressed = false
                }
                action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.01 : 1))
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.08), value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(accessibilityHintText)
    }

    private var accessibilityHintText: String {
        switch style {
        case .accent: return "Double-tap to activate"
        case .secondary: return "Double-tap to activate"
        case .destructive: return "Double-tap to perform this destructive action"
        }
    }
}

// MARK: - Settings External Link

struct SettingsExternalLink: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isHovered ? Color.drift : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("\(title), opens in browser")
        .accessibilityAddTraits(.isLink)
    }
}
