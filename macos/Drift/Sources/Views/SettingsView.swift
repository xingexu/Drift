import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetConfirmation = false
    @State private var showResetSuccess = false
    @State private var checkoutError: String?
    @State private var showCheckoutError = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.xxl) {

                // Page header
                HStack {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Settings")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-0.8)

                        Text("Customize your Drift experience.")
                            .font(TypeScale.bodyMd)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // APPEARANCE
                settingsSection("APPEARANCE", icon: "sun.max") {
                    VStack(spacing: 0) {
                        SettingsPickerRow(
                            icon: "display",
                            iconColor: .secondary,
                            title: "Theme",
                            subtitle: "Light or dark — Drift adapts throughout."
                        ) {
                            Picker(selection: Binding(
                                get: { appState.theme },
                                set: { appState.setTheme($0) }
                            )) {
                                Text(AppTheme.light.label).tag(AppTheme.light)
                                Text(AppTheme.dark.label).tag(AppTheme.dark)
                            } label: { EmptyView() }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 160)
                            .accessibilityLabel("Theme selector")
                            .accessibilityValue(appState.theme.label)
                        }

                        DriftDivider()

                        SettingsToggleRow(
                            icon: "waveform.path.ecg",
                            iconColor: .secondary,
                            title: "Reduce motion",
                            subtitle: "Minimize decorative animations.",
                            isOn: Binding(
                                get: { appState.reduceMotion },
                                set: { appState.setReduceMotion($0) }
                            )
                        )

                        DriftDivider()

                        SettingsPickerRow(
                            icon: "square.grid.2x2",
                            iconColor: .secondary,
                            title: "Density",
                            subtitle: "Compact fits more on screen; spacious breathes."
                        ) {
                            Picker(selection: Binding(
                                get: { appState.density },
                                set: { appState.setDensity($0) }
                            )) {
                                Text("Compact").tag("Compact")
                                Text("Comfortable").tag("Comfortable")
                                Text("Spacious").tag("Spacious")
                            } label: { EmptyView() }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 260)
                            .accessibilityLabel("Density selector")
                            .accessibilityValue(appState.density)
                        }
                    }
                    .sectionCard()
                }

                // TRACKING
                settingsSection("TRACKING", icon: "chart.bar.xaxis") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "arrow.up.right.circle",
                            iconColor: .green,
                            title: "Launch at login",
                            subtitle: "Start Drift automatically when you log in.",
                            isOn: Binding(
                                get: { appState.launchAtLogin },
                                set: { newValue in
                                    appState.launchAtLogin = newValue
                                    UserDefaults.standard.set(newValue, forKey: "drift_launch_login")
                                }
                            )
                        )

                        DriftDivider()

                        SettingsToggleRow(
                            icon: "bell",
                            iconColor: .orange,
                            title: "Desktop notifications",
                            subtitle: "Be notified about Drift events.",
                            isOn: Binding(
                                get: { appState.notificationsEnabled },
                                set: { newValue in
                                    appState.notificationsEnabled = newValue
                                    UserDefaults.standard.set(newValue, forKey: "drift_notifications")
                                }
                            )
                        )

                        DriftDivider()

                        SettingsPickerRow(
                            icon: "timer",
                            iconColor: .secondary,
                            title: "Idle timeout",
                            subtitle: "Pause tracking after inactivity."
                        ) {
                            Picker(selection: Binding(
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
                            } label: { EmptyView() }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 220)
                            .accessibilityLabel("Idle timeout duration")
                            .accessibilityValue(idleTimeoutLabel)
                        }
                    }
                    .sectionCard()
                }

                // KEYBOARD SHORTCUTS
                settingsSection("KEYBOARD SHORTCUTS", icon: "keyboard") {
                    VStack(spacing: 0) {
                        SettingsShortcutRow(
                            icon: "1.circle", title: "Home",     keys: ["1"]
                        )
                        DriftDivider()
                        SettingsShortcutRow(
                            icon: "2.circle", title: "Session",  keys: ["2"]
                        )
                        DriftDivider()
                        SettingsShortcutRow(
                            icon: "3.circle", title: "Focus",    keys: ["3"]
                        )
                        DriftDivider()
                        SettingsShortcutRow(
                            icon: "4.circle", title: "History",  keys: ["4"]
                        )
                        DriftDivider()
                        SettingsShortcutRow(
                            icon: "5.circle", title: "Settings", keys: ["5"]
                        )
                        DriftDivider()
                        SettingsShortcutRow(
                            icon: "record.circle",
                            title: "Toggle tracking",
                            keys: ["\u{2318}", "\u{21E7}", "D"]
                        )
                        DriftDivider()
                        SettingsShortcutRow(
                            icon: "arrow.counterclockwise",
                            title: "Reset session",
                            keys: ["\u{2318}", "\u{21E7}", "R"]
                        )
                        DriftDivider()
                        SettingsShortcutRow(
                            icon: "play.pause",
                            title: "Play / Pause focus timer",
                            keys: ["Space"]
                        )
                        DriftDivider()
                        SettingsShortcutRow(
                            icon: "xmark.circle",
                            title: "Stop focus session",
                            keys: ["Esc"]
                        )
                    }
                    .sectionCard()
                }

                // ABOUT
                settingsSection("ABOUT", icon: "info.circle") {
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

                        SettingsInfoRow(
                            icon: "globe",
                            iconColor: appState.accentColor,
                            title: "Website"
                        ) {
                            PremiumExternalLink(title: "drift.app") {
                                if let url = URL(string: "https://drift.app") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                    .sectionCard()
                }

                // DANGER ZONE
                settingsSection("DANGER ZONE", icon: "exclamationmark.triangle") {
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
                                                    .strokeBorder(Color.distraction.opacity(0.28), lineWidth: 0.5)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Reset All Data")
                            .accessibilityHint("Opens a confirmation dialog before erasing all data")
                        }
                        .padding(Space.md)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                    .strokeBorder(Color.distraction.opacity(0.22), lineWidth: 0.5)
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                }
            }
            .padding(Space.page)
        }
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) { resetAllData() }
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

    // MARK: - Section Builder

    @ViewBuilder
    private func settingsSection<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
            }

            content()
        }
    }

    // MARK: - Helpers

    private var idleTimeoutLabel: String {
        switch appState.idleTimeout {
        case 120:  return "2 minutes"
        case 300:  return "5 minutes"
        case 600:  return "10 minutes"
        case 900:  return "15 minutes"
        default:   return "\(appState.idleTimeout / 60) minutes"
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

    // MARK: - Actions

    private func resetAllData() {
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "com.drift.app"
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        appState.logout()
        appState.session.reset()
        appState.pastSessions.removeAll()
        // Route through setters so each default is re-persisted to the freshly
        // cleared UserDefaults (direct assignment skipped persistence, leaving
        // state and disk out of sync) and no preference is silently missed.
        appState.setTheme(.system)
        appState.setDensity("Spacious")
        appState.setTypography("Sora")
        appState.setHomeLayout("Hero")
        appState.setReduceMotion(false)
        appState.setAccentColor(DriftDesign.accents.first?.name ?? appState.accentColorName)
        appState.idleTimeout = 300
        appState.notificationsEnabled = true
        appState.launchAtLogin = true
        showResetSuccess = true
    }
}

// MARK: - Section Card Modifier

private extension View {
    func sectionCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
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
        .background(isHovered ? Color.primary.opacity(0.05) : .clear)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Settings Picker Row

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
        .background(isHovered ? Color.primary.opacity(0.05) : .clear)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Settings Info Row

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
        .background(isHovered ? Color.primary.opacity(0.05) : .clear)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Settings Action Row

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
            .background(isHovered ? Color.primary.opacity(0.05) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Settings Shortcut Row

struct SettingsShortcutRow: View {
    let icon: String
    let title: String
    let keys: [String]
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Space.md) {
            IconBadge(systemName: icon, color: Color(.secondaryLabelColor), size: 28)

            Text(title)
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
        .background(isHovered ? Color.primary.opacity(0.05) : .clear)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(keys.joined(separator: " "))")
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
