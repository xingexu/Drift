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
            VStack(alignment: .leading, spacing: Space.xxl) {
                headerSection
                    .padding(.bottom, Space.xs)

                ForEach(SettingsSectionID.allCases) { section in
                    sectionView(for: section)
                }
            }
            .padding(Space.page)
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
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text("Settings")
                .font(TypeScale.title)
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
            Text("Customize your Drift experience")
                .font(TypeScale.body)
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
            iconColor: Color.accent,
            expandedSections: $expandedSections
        ) {
            SettingsPickerRow(
                icon: "paintbrush",
                iconColor: Color.accent,
                title: "Theme",
                subtitle: "Light, dark, or follow system"
            ) {
                Picker("Theme", selection: Binding(
                    get: { appState.theme },
                    set: { appState.setTheme($0) }
                )) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Label(theme.label, systemImage: theme.icon).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
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
            iconColor: Color.productive,
            expandedSections: $expandedSections
        ) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "power",
                    iconColor: Color.productive,
                    title: "Launch at Login",
                    subtitle: "Start Drift automatically when you log in",
                    isOn: Binding(
                        get: { appState.launchAtLogin },
                        set: { newValue in
                            appState.launchAtLogin = newValue
                            UserDefaults.standard.set(newValue, forKey: "drift_launch_login")
                        }
                    )
                )

                DriftDivider()
                    .padding(.horizontal, Space.lg)

                SettingsToggleRow(
                    icon: "bell",
                    iconColor: Color.streak,
                    title: "Desktop Notifications",
                    subtitle: "Get notified about drift events",
                    isOn: Binding(
                        get: { appState.notificationsEnabled },
                        set: { newValue in
                            appState.notificationsEnabled = newValue
                            UserDefaults.standard.set(newValue, forKey: "drift_notifications")
                        }
                    )
                )

                DriftDivider()
                    .padding(.horizontal, Space.lg)

                SettingsPickerRow(
                    icon: "moon.zzz",
                    iconColor: .secondary,
                    title: "Idle Timeout",
                    subtitle: "Pause tracking after inactivity"
                ) {
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
            iconColor: Color.accent,
            expandedSections: $expandedSections
        ) {
            VStack(spacing: 0) {
                PremiumKeyboardShortcutRow(label: "Toggle Tracking", keys: ["\u{2318}", "\u{21E7}", "D"])
                DriftDivider()
                    .padding(.horizontal, Space.lg)
                PremiumKeyboardShortcutRow(label: "Reset Session", keys: ["\u{2318}", "\u{21E7}", "R"])
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        CollapsibleSettingsSection(
            id: .account,
            title: "Account",
            icon: "person.circle",
            iconColor: Color.accent,
            expandedSections: $expandedSections
        ) {
            if let user = appState.user {
                signedInAccountContent(user: user)
            } else {
                signedOutAccountContent
            }
        }
    }

    @ViewBuilder
    private func signedInAccountContent(user: User) -> some View {
        VStack(spacing: 0) {
            // Avatar + email header card
            accountAvatarRow(user: user)

            DriftDivider()
                .padding(.horizontal, Space.lg)

            // Plan row
            SettingsInfoRow(
                icon: "crown",
                iconColor: planColor(for: user.plan),
                title: "Plan"
            ) {
                PremiumPlanBadge(plan: user.plan)
            }

            DriftDivider()
                .padding(.horizontal, Space.lg)

            // Plan action
            if user.plan == "free" {
                upgradeProRow
            } else {
                manageSubscriptionRow
            }

            DriftDivider()
                .padding(.horizontal, Space.lg)

            signOutRow
        }
    }

    @ViewBuilder
    private func accountAvatarRow(user: User) -> some View {
        HStack(spacing: Space.md) {
            // Avatar circle with initials
            ZStack {
                Circle()
                    .fill(Color.accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text(user.initials)
                    .font(TypeScale.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.xxxs) {
                Text(user.displayName)
                    .font(TypeScale.bodyMd)
                    .fontWeight(.medium)
                Text(user.email)
                    .font(TypeScale.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Signed in as \(user.displayName), \(user.email)")
    }

    private var upgradeProRow: some View {
        HStack {
            Spacer()
            PrimaryButton("Upgrade to Pro", icon: "sparkles", color: Color.accent, isFullWidth: true) {
                upgradeToPro()
            }
            Spacer()
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    private var manageSubscriptionRow: some View {
        SettingsActionRow(
            icon: "creditcard",
            iconColor: .secondary,
            title: "Manage Subscription"
        ) {
            Task { await openBillingPortal() }
        }
    }

    private var signOutRow: some View {
        SettingsActionRow(
            icon: "rectangle.portrait.and.arrow.right",
            iconColor: Color.distraction,
            title: "Sign Out",
            titleColor: Color.distraction
        ) {
            appState.logout()
        }
    }

    private var signedOutAccountContent: some View {
        VStack(spacing: Space.md) {
            HStack(spacing: Space.md) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Space.xxxs) {
                    Text("Not signed in")
                        .font(TypeScale.bodyMd)
                        .fontWeight(.semibold)
                    Text("Sign in to sync your data across devices.")
                        .font(TypeScale.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.sm)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Not signed in. Sign in to sync your data across devices.")

            HStack {
                PrimaryButton("Sign In", icon: "person.crop.circle", color: Color.accent, isFullWidth: true) {
                    appState.showSignIn = true
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.md)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        CollapsibleSettingsSection(
            id: .about,
            title: "About",
            icon: "info.circle",
            iconColor: Color.accent,
            expandedSections: $expandedSections
        ) {
            VStack(spacing: 0) {
                SettingsInfoRow(
                    icon: "number",
                    iconColor: .secondary,
                    title: "Version"
                ) {
                    Text(appVersionString)
                        .font(TypeScale.monoSm)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("App version")
                        .accessibilityValue(appVersionString)
                }

                DriftDivider()
                    .padding(.horizontal, Space.lg)

                SettingsInfoRow(
                    icon: "globe",
                    iconColor: Color.accent,
                    title: "Website"
                ) {
                    PremiumExternalLink(title: "drift.app") {
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
            iconColor: Color.distraction,
            expandedSections: $expandedSections
        ) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.md) {
                    IconBadge(systemName: "trash", color: Color.distraction, size: 28)

                    VStack(alignment: .leading, spacing: Space.xxxs) {
                        Text("Reset All Data")
                            .font(TypeScale.bodyMd)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.distraction)
                        Text("Permanently erase all sessions, preferences, and sign-in state.")
                            .font(TypeScale.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        showResetConfirmation = true
                    } label: {
                        Text("Reset")
                            .font(TypeScale.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.distraction)
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, Space.xxs + 1)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(Color.distraction.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                            .strokeBorder(Color.distraction.opacity(0.22), lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset All Data")
                    .accessibilityHint("Opens a confirmation dialog before erasing all data")
                }
                .padding(Space.md)
            }
            .accentCard(color: Color.distraction, padding: 0, radius: Radius.md)
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
        }
    }

    // MARK: - Helpers

    private func planColor(for plan: String) -> Color {
        switch plan {
        case "pro": return Color.accent
        case "team": return .purple
        default: return Color(.secondaryLabelColor)
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
    var iconColor: Color = Color.accent
    @Binding var expandedSections: Set<SettingsSectionID>
    @ViewBuilder let content: () -> Content

    @State private var headerHovered = false

    private var isExpanded: Bool {
        expandedSections.contains(id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header — tappable to collapse/expand
            Button {
                withAnimation(Anim.appear) {
                    if isExpanded {
                        expandedSections.remove(id)
                    } else {
                        expandedSections.insert(id)
                    }
                }
            } label: {
                HStack(spacing: Space.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(iconColor.opacity(0.7))
                    Text(title)
                        .sectionLabel()
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(Anim.tap, value: isExpanded)
                }
                .padding(.vertical, Space.xs)
                .padding(.horizontal, Space.xxxs)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                        .fill(headerHovered ? Color.primary.opacity(0.04) : .clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { headerHovered = $0 }
            .accessibilityLabel("\(title) section")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Double-tap to \(isExpanded ? "collapse" : "expand") this section")

            // Collapsible content card
            if isExpanded {
                VStack(spacing: 0) {
                    content()
                }
                .driftCard(padding: 0)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.top, Space.sm)
            }
        }
        .animation(Anim.appear, value: isExpanded)
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    @State private var isHovered = false

    init(
        icon: String,
        iconColor: Color = Color.accent,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: Space.md) {
            IconBadge(systemName: icon, color: iconColor, size: 28)

            VStack(alignment: .leading, spacing: Space.xxxs) {
                Text(title)
                    .font(TypeScale.bodyMd)
                if let sub = subtitle {
                    Text(sub)
                        .font(TypeScale.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn.animation(Anim.quick))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel(title)
                .accessibilityValue(isOn ? "Enabled" : "Disabled")
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm + 2)
        .background(isHovered ? Color.primary.opacity(0.03) : .clear)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Settings Picker Row (icon + label + trailing control)

struct SettingsPickerRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing
    @State private var isHovered = false

    init(
        icon: String,
        iconColor: Color = Color.accent,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Space.md) {
            IconBadge(systemName: icon, color: iconColor, size: 28)

            VStack(alignment: .leading, spacing: Space.xxxs) {
                Text(title)
                    .font(TypeScale.bodyMd)
                if let sub = subtitle {
                    Text(sub)
                        .font(TypeScale.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm + 2)
        .background(isHovered ? Color.primary.opacity(0.03) : .clear)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Settings Info Row (read-only label + trailing value)

struct SettingsInfoRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let trailing: () -> Trailing
    @State private var isHovered = false

    init(
        icon: String,
        iconColor: Color = .secondary,
        title: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Space.md) {
            IconBadge(systemName: icon, color: iconColor, size: 28)

            Text(title)
                .font(TypeScale.bodyMd)

            Spacer()

            trailing()
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm + 2)
        .background(isHovered ? Color.primary.opacity(0.03) : .clear)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Settings Action Row (tappable row with disclosure arrow)

struct SettingsActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var titleColor: Color = .primary
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                IconBadge(systemName: icon, color: iconColor, size: 28)

                Text(title)
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(titleColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm + 2)
            .background(isHovered ? Color.primary.opacity(0.03) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Premium Keyboard Shortcut Row

struct PremiumKeyboardShortcutRow: View {
    let label: String
    let keys: [String]
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Space.md) {
            IconBadge(systemName: "keyboard", color: Color.accent, size: 28)

            Text(label)
                .font(TypeScale.bodyMd)

            Spacer()

            HStack(spacing: Space.xxxs + 1) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    KeyBadge(key: key)
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm + 2)
        .background(isHovered ? Color.primary.opacity(0.03) : .clear)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(keys.joined(separator: " "))")
    }
}

// MARK: - Premium Plan Badge

private struct PremiumPlanBadge: View {
    let plan: String

    private var color: Color {
        switch plan {
        case "pro": return Color.accent
        case "team": return .purple
        default: return Color(.secondaryLabelColor)
        }
    }

    private var isPro: Bool { plan == "pro" || plan == "team" }

    var body: some View {
        HStack(spacing: Space.xxs) {
            if isPro {
                Image(systemName: "crown.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
            }
            Text(plan.capitalized)
                .font(TypeScale.tiny)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xxxs + 1)
        .background(
            Capsule()
                .fill(color.opacity(0.10))
                .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 0.5))
        )
        .accessibilityLabel("Current plan")
        .accessibilityValue(plan.capitalized)
    }
}

// MARK: - Premium External Link

struct PremiumExternalLink: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xxs) {
                Text(title)
                    .font(TypeScale.bodySm)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isHovered ? Color.accent : Color(.secondaryLabelColor))
            .animation(Anim.hover, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(title), opens in browser")
        .accessibilityAddTraits(.isLink)
    }
}
