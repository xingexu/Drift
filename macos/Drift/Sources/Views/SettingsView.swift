import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetConfirmation = false
    @State private var showResetSuccess = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.xxl) {

                HStack(alignment: .top, spacing: Space.md) {
                    SettingsPageIcon(color: Color.streak)
                        .frame(width: 30, height: 30)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("SETTINGS")
                            .font(TypeScale.h1)

                        Text("Core preferences for tracking and focus.")
                            .font(TypeScale.bodyMd)
                            .foregroundStyle(Color.driftMuted)
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
                            PixelOptionPicker(selection: Binding(
                                get: { appState.theme },
                                set: { appState.setTheme($0) }
                            ), options: [
                                (AppTheme.system.label, AppTheme.system),
                                (AppTheme.light.label, AppTheme.light),
                                (AppTheme.dark.label, AppTheme.dark)
                            ])
                            .frame(width: 230)
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
                            PixelOptionPicker(selection: Binding(
                                get: { appState.idleTimeout },
                                set: { newValue in
                                    appState.idleTimeout = newValue
                                    UserDefaults.standard.set(newValue, forKey: "drift_idle_timeout")
                                }
                            ), options: [
                                ("2m", 120),
                                ("5m", 300),
                                ("10m", 600),
                                ("15m", 900)
                            ])
                            .frame(width: 220)
                            .accessibilityLabel("Idle timeout duration")
                            .accessibilityValue(idleTimeoutLabel)
                        }
                    }
                    .sectionCard()
                }

                // DANGER ZONE
                settingsSection("DANGER ZONE", icon: "exclamationmark.triangle") {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        HStack(spacing: Space.md) {
                            IconBadge(systemName: "trash", color: Color.distraction, size: 36)

                            VStack(alignment: .leading, spacing: Space.xxxs) {
                                Text("Reset All Data")
                                    .font(TypeScale.heading)
                                    .foregroundStyle(Color.distraction)
                                Text("Permanently erase all sessions and local preferences.")
                                    .font(TypeScale.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                showResetConfirmation = true
                            } label: {
                                Text("Reset")
                                    .font(TypeScale.caption)
                                    .foregroundStyle(Color.distraction)
                                    .padding(.horizontal, Space.md)
                                    .padding(.vertical, Space.xxs + 1)
                                    .background(
                                        Rectangle()
                                            .fill(Color.distraction.opacity(0.10))
                                            .overlay(
                                                Rectangle()
                                                    .strokeBorder(Color.distraction.opacity(0.42), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Reset All Data")
                            .accessibilityHint("Opens a confirmation dialog before erasing all data")
                        }
                        .padding(Space.md)
                        .frame(minHeight: 72)
                    }
                    .pixelPanel(border: Color.distraction.opacity(0.70), fill: Color.driftPanel, shadow: true)
                }
            }
            .frame(maxWidth: 1320, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 32)
        }
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) { resetAllData() }
        } message: {
            Text("This will permanently erase all local data including session history and preferences. This action cannot be undone.")
        }
        .alert("Data Reset Complete", isPresented: $showResetSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("All local data has been cleared and settings restored to defaults.")
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
                    .foregroundStyle(Color.streak)

                Text(title)
                    .font(TypeScale.label)
                    .tracking(0)
                    .foregroundStyle(Color.streak)
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
        appState.setReduceMotion(false)
        appState.setAccentColor(DriftDesign.accents.first?.name ?? appState.accentColorName)
        appState.idleTimeout = 300
        appState.notificationsEnabled = true
        appState.launchAtLogin = true
        showResetSuccess = true
    }
}

private struct SettingsPageIcon: View {
    let color: Color

    var body: some View {
        ZStack {
            Rectangle()
                .fill(color.opacity(0.11))
                .overlay(Rectangle().strokeBorder(color.opacity(0.34), lineWidth: 1))
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Section Card Modifier

private extension View {
    func sectionCard() -> some View {
        self
            .pixelPanel(border: Color.driftBorder, fill: Color.driftPanel, shadow: true)
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
            IconBadge(systemName: icon, color: iconColor, size: 36)

            VStack(alignment: .leading, spacing: Space.xxxs) {
                Text(title)
                    .font(TypeScale.heading)
                if let sub = subtitle {
                    Text(sub)
                        .font(TypeScale.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            PixelToggle(isOn: $isOn)
                .accessibilityLabel(title)
                .accessibilityValue(isOn ? "Enabled" : "Disabled")
        }
        .padding(.horizontal, Space.lg)
        .frame(minHeight: 76)
        .background(isHovered ? Color.driftPanelRaised.opacity(0.72) : .clear)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
    }
}

private struct PixelToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(Anim.tap) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Rectangle()
                    .fill(isOn ? Color.accent.opacity(0.24) : Color.primary.opacity(0.06))
                    .frame(width: 46, height: 24)
                    .overlay(Rectangle().strokeBorder(isOn ? Color.accent : Color.border, lineWidth: 2))
                Rectangle()
                    .fill(isOn ? Color.accent : Color.secondary)
                    .frame(width: 14, height: 14)
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PixelOptionPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(String, Value)]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button {
                    withAnimation(Anim.quick) { selection = option.1 }
                } label: {
                    Text(option.0.uppercased())
                        .font(TypeScale.tiny)
                        .tracking(0)
                        .foregroundStyle(selection == option.1 ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selection == option.1 ? Color.accent : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .overlay(Rectangle().strokeBorder(Color.border, lineWidth: 2))
        )
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
            IconBadge(systemName: icon, color: iconColor, size: 36)

            VStack(alignment: .leading, spacing: Space.xxxs) {
                Text(title)
                    .font(TypeScale.heading)
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
        .frame(minHeight: 76)
        .background(isHovered ? Color.driftPanelRaised.opacity(0.72) : .clear)
        .animation(Anim.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
    }
}
