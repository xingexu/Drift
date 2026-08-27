import SwiftUI
import AppKit
import ApplicationServices
import UniformTypeIdentifiers

private enum SettingsDestination: String, CaseIterable, Identifiable {
    case general = "General"
    case tracking = "Tracking"
    case rules = "Rules"
    case blocking = "Blocking"
    case privacy = "Privacy"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .tracking: return "eye"
        case .rules: return "square.grid.2x2"
        case .blocking: return "shield"
        case .privacy: return "lock"
        }
    }
}

private struct SettingsNavigationItem: View {
    let item: SettingsDestination
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let reduceMotion: Bool
    let action: () -> Void

    @State private var isHovered = false
    @FocusState private var isKeyboardFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                Text(item.rawValue)
                    .font(TypeScale.bodySm)
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.cream : Color.creamMuted)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.sand.opacity(0.18))
                        .matchedGeometryEffect(id: "settings-selection", in: selectionNamespace)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.cream.opacity(0.055))
                }
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(Color.sand)
                        .frame(width: 3, height: 24)
                        .matchedGeometryEffect(id: "settings-indicator", in: selectionNamespace)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        Color.cream.opacity(isKeyboardFocused ? 0.58 : 0),
                        lineWidth: 1.5
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DriftResponsivePressStyle(reduceMotion: reduceMotion))
        .focused($isKeyboardFocused)
        .onHover { isHovered = $0 }
        .animation(Anim.quick, value: isHovered)
        .accessibilityLabel(item.rawValue)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private enum RulesScope: String, CaseIterable, Identifiable {
    case apps = "Apps"
    case websites = "Websites"
    var id: String { rawValue }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var tracker: WindowTracker
    @StateObject private var blocker = FocusBlocker.shared
    @State private var destination: SettingsDestination = .general
    @State private var rulesScope: RulesScope = .apps
    @State private var rulesSearch = ""
    @State private var rulesFilter: AppCategory?
    @State private var newBlockedSite = ""
    @State private var showDeleteHistoryConfirmation = false
    @State private var showResetConfirmation = false
    @State private var showResetSuccess = false
    @Namespace private var settingsSelectionNamespace

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
                .frame(height: 138)

            HStack(alignment: .top, spacing: 24) {
                settingsNavigation
                    .frame(width: 210)

                ScrollView(showsIndicators: false) {
                    settingsContent
                        .frame(maxWidth: 760, alignment: .topLeading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.bottom, 40)
                }
            }
            .frame(maxWidth: 1040, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .alert("Delete history?", isPresented: $showDeleteHistoryConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete History", role: .destructive) { appState.deleteHistory() }
        } message: {
            Text("This permanently removes tracked sessions from this Mac. Your preferences and blocking list will remain.")
        }
        .onAppear {
            if let requested = ProcessInfo.processInfo.environment["DRIFT_SNAPSHOT_SETTINGS"],
               let requestedDestination = SettingsDestination(rawValue: requested) {
                destination = requestedDestination
            }
        }
    }

    private var settingsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(TypeScale.h1)
                    .foregroundStyle(Color.desertCreamText)
                Text("Tracking, focus, and privacy preferences.")
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(Color.desertMutedText)
            }
            .shadow(color: Color.black.opacity(0.75), radius: 4, y: 2)
            Spacer()
        }
        .frame(maxWidth: 1040)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private var settingsNavigation: some View {
        VStack(spacing: 6) {
            ForEach(SettingsDestination.allCases) { item in
                SettingsNavigationItem(
                    item: item,
                    isSelected: destination == item,
                    selectionNamespace: settingsSelectionNamespace,
                    reduceMotion: appState.reduceMotion
                ) {
                    destination = item
                }
            }
        }
        .padding(8)
        .driftContentSurface(cornerRadius: DriftSurfaceRadius.major)
        .animation(
            appState.reduceMotion ? nil : .spring(duration: 0.20, bounce: 0.08),
            value: destination
        )
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch destination {
        case .general: generalSettings
        case .tracking: trackingSettings
        case .rules: rulesSettings
        case .blocking: blockingSettings
        case .privacy: privacySettings
        }
    }

    private var generalSettings: some View {
        settingsPanel(title: "General", subtitle: "Appearance and everyday behavior") {
            SettingsRow(title: "Appearance", explanation: "Choose how Drift matches your Mac.") {
                SegmentedControl(
                    options: [AppTheme.system, .light, .dark],
                    selection: Binding(get: { appState.theme }, set: { appState.setTheme($0) }),
                    title: { $0.label }
                )
            }
            SettingsRow(title: "Reduce Motion", explanation: "Keep state changes clear without movement.") {
                Toggle("Reduce Motion", isOn: Binding(
                    get: { appState.reduceMotion },
                    set: { appState.setReduceMotion($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.sand)
            }
            SettingsRow(title: "Launch at Login", explanation: "Start Drift when you sign in to this Mac.") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: {
                        appState.launchAtLogin = $0
                        UserDefaults.standard.set($0, forKey: "drift_launch_login")
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.sand)
            }
            SettingsRow(title: "Notifications", explanation: "Show focus and blocking updates.") {
                Toggle("Notifications", isOn: Binding(
                    get: { appState.notificationsEnabled },
                    set: {
                        appState.notificationsEnabled = $0
                        UserDefaults.standard.set($0, forKey: "drift_notifications")
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.sand)
            }
            SettingsRow(title: "Idle Timeout", explanation: "Pause tracking after inactivity.") {
                TactileMenu(
                    selection: Binding(
                        get: { appState.idleTimeout },
                        set: {
                            appState.idleTimeout = $0
                            UserDefaults.standard.set($0, forKey: "drift_idle_timeout")
                        }
                    ),
                    options: [120, 300, 600, 900].map {
                        TactileMenuOption(title: "\($0 / 60)m", icon: "timer", value: $0)
                    }
                )
                .frame(width: 130)
            }
        }
    }

    private var trackingSettings: some View {
        settingsPanel(title: "Tracking", subtitle: "Permissions Drift uses to read context") {
            permissionRow(
                title: "Accessibility",
                explanation: "Reads the active app and window title.",
                granted: AXIsProcessTrusted(),
                privacyPane: "Privacy_Accessibility"
            )
            permissionRow(
                title: "Browser Automation",
                explanation: "Reads the active tab URL in supported browsers.",
                granted: !tracker.activeURL.isEmpty,
                privacyPane: "Privacy_Automation"
            )
        }
    }

    private var rulesSettings: some View {
        ContentSurfacePanel(padding: 0, dense: true, cornerRadius: DriftSurfaceRadius.major) {
            VStack(alignment: .leading, spacing: 0) {
                settingsPanelHeader(title: "Rules", subtitle: "Correct how apps and websites are classified")
                    .padding(24)

                Rectangle().fill(Color.cream.opacity(0.12)).frame(height: 1)

                HStack(spacing: 10) {
                    SegmentedControl(
                        options: RulesScope.allCases,
                        selection: $rulesScope,
                        title: { $0.rawValue }
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.driftMuted)
                        TextField("Search rules", text: $rulesSearch)
                            .textFieldStyle(.plain)
                            .font(TypeScale.bodySm)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .driftInsetSurface()

                    Menu {
                        Button("All") { rulesFilter = nil }
                        ForEach(AppCategory.allCases, id: \.rawValue) { category in
                            Button(category.label) { rulesFilter = category }
                        }
                    } label: {
                        Text(rulesFilter?.label ?? "All")
                            .font(TypeScale.bodySm)
                            .foregroundStyle(Color.cream)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .driftFunctionalGlass(cornerRadius: Radius.pill)
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(20)

                Rectangle().fill(Color.cream.opacity(0.12)).frame(height: 1)

                if filteredClassificationTargets.isEmpty {
                    EmptyState(icon: "wand.and.stars", message: "Recent classified activity will appear here.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(filteredClassificationTargets) { item in
                            ruleRow(item)
                        }
                    }
                }
            }
        }
    }

    private var blockingSettings: some View {
        ContentSurfacePanel(padding: 0, dense: true, cornerRadius: DriftSurfaceRadius.major) {
            VStack(alignment: .leading, spacing: 0) {
                settingsPanelHeader(title: "Blocking", subtitle: "Choose the websites Focus keeps quiet")
                    .padding(24)

                Rectangle().fill(Color.cream.opacity(0.12)).frame(height: 1)

                HStack(spacing: 10) {
                    TextField("example.com", text: $newBlockedSite)
                        .textFieldStyle(.plain)
                        .font(TypeScale.bodySm)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .driftInsetSurface()
                        .onSubmit(addBlockedSite)

                    PrimaryPillButton(title: "Add website", icon: "plus") { addBlockedSite() }
                }
                .padding(20)

                Rectangle().fill(Color.cream.opacity(0.12)).frame(height: 1)

                ForEach(blocker.blockedSites, id: \.self) { site in
                    SettingsRow(title: site, explanation: blocker.isSiteEnabled(site) ? "Enabled for Focus" : "Disabled") {
                        HStack(spacing: 10) {
                            Toggle(site, isOn: Binding(
                                get: { blocker.isSiteEnabled(site) },
                                set: { blocker.setSite(site, enabled: $0) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(Color.sand)
                            IconButton(icon: "trash", label: "Remove \(site)", color: .distraction) {
                                blocker.removeSite(site)
                            }
                        }
                    }
                }
            }
        }
    }

    private var privacySettings: some View {
        ContentSurfacePanel(padding: 0, dense: true, cornerRadius: DriftSurfaceRadius.major) {
            VStack(alignment: .leading, spacing: 0) {
                settingsPanelHeader(title: "Privacy", subtitle: "Your attention data stays under your control")
                    .padding(24)

                Rectangle().fill(Color.cream.opacity(0.12)).frame(height: 1)

                SettingsRow(title: "Local Storage", explanation: "Sessions and corrections are stored only on this Mac.") {
                    Text("Local").font(TypeScale.caption).foregroundStyle(Color.productive)
                }
                SettingsRow(title: "Cloud Sync", explanation: "No activity data is uploaded.") {
                    Text("Off").font(TypeScale.caption).foregroundStyle(Color.driftMuted)
                }
                SettingsRow(title: "Export Data", explanation: "Save a portable JSON copy of sessions and rules.") {
                    SecondaryPillButton(title: "Export", icon: "square.and.arrow.up") { exportData() }
                }

                SettingsRow(title: "Delete History", explanation: "Permanently remove tracked sessions from this Mac.") {
                    Button {
                        showDeleteHistoryConfirmation = true
                    } label: {
                        Text("Delete History")
                            .font(TypeScale.bodySm)
                            .foregroundStyle(Color.distraction)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(Capsule().fill(Color.distraction.opacity(0.10)))
                            .overlay(Capsule().strokeBorder(Color.distraction.opacity(0.42), lineWidth: 1))
                    }
                    .buttonStyle(DriftButtonStyle(variant: .danger))
                }
            }
        }
    }

    @ViewBuilder
    private func settingsPanel<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ContentSurfacePanel(padding: 0, dense: true, cornerRadius: DriftSurfaceRadius.major) {
            VStack(alignment: .leading, spacing: 0) {
                settingsPanelHeader(title: title, subtitle: subtitle)
                    .padding(24)
                Rectangle()
                    .fill(Color.cream.opacity(0.12))
                    .frame(height: 1)
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    private func settingsPanelHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(TypeScale.h2)
                .foregroundStyle(Color.cream)
            Text(subtitle)
                .font(TypeScale.bodySm)
                .foregroundStyle(Color.driftMuted)
        }
    }

    private func permissionRow(
        title: String,
        explanation: String,
        granted: Bool,
        privacyPane: String
    ) -> some View {
        SettingsRow(title: title, explanation: explanation) {
            HStack(spacing: 12) {
                Label(
                    granted ? "Granted" : "Required",
                    systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                )
                .font(TypeScale.caption)
                .foregroundStyle(granted ? Color.productive : Color.distraction)

                SecondaryPillButton(title: "Open System Settings", icon: "arrow.up.right") {
                    openPrivacyPane(privacyPane)
                }
            }
        }
    }

    private func ruleRow(_ item: ClassificationTarget) -> some View {
        HStack(spacing: Space.md) {
            if item.key.hasPrefix("app:") {
                ApplicationIcon(name: item.name, size: 38)
            } else {
                IconBadge(systemName: "globe", color: .sand, size: 38)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(TypeScale.heading)
                    .lineLimit(1)
                Text(item.key.hasPrefix("app:") ? "Application" : "Website")
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.driftMuted)
            }

            Spacer()

            TactileMenu(
                selection: Binding(
                    get: { appState.classificationOverride(for: item.key) ?? item.inferredCategory },
                    set: { appState.setClassificationOverride($0, for: item.key) }
                ),
                options: AppCategory.allCases.map {
                    TactileMenuOption(title: $0.label, icon: categoryIcon($0), value: $0)
                }
            )
            .frame(width: 166)

            TertiaryButton(title: "Reset override") {
                appState.removeClassificationOverride(for: item.key)
            }
            .disabled(appState.classificationOverride(for: item.key) == nil)
            .opacity(appState.classificationOverride(for: item.key) == nil ? 0.45 : 1)
        }
        .padding(.horizontal, Space.lg)
        .frame(minHeight: 64)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cream.opacity(0.10)).frame(height: 1)
        }
    }

    private var filteredClassificationTargets: [ClassificationTarget] {
        recentClassificationTargets.filter { item in
            let matchesScope = rulesScope == .apps
                ? item.key.hasPrefix("app:")
                : item.key.hasPrefix("domain:")
            let matchesSearch = rulesSearch.isEmpty
                || item.name.localizedCaseInsensitiveContains(rulesSearch)
            let displayedCategory = appState.classificationOverride(for: item.key) ?? item.inferredCategory
            let matchesCategory = rulesFilter == nil || displayedCategory == rulesFilter
            return matchesScope && matchesSearch && matchesCategory
        }
    }

    private func categoryIcon(_ category: AppCategory) -> String {
        switch category {
        case .productive: return "checkmark.circle.fill"
        case .neutral: return "minus.circle.fill"
        case .distraction: return "exclamationmark.triangle.fill"
        }
    }

    private func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func addBlockedSite() {
        blocker.addSite(newBlockedSite)
        newBlockedSite = ""
    }

    private struct ExportPayload: Codable {
        let exportedAt: Date
        let sessions: [PastSession]
        let classificationOverrides: [String: AppCategory]
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Drift Export.json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let payload = ExportPayload(
            exportedAt: Date(),
            sessions: appState.pastSessions,
            classificationOverrides: appState.classificationOverrides
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(payload) {
            try? data.write(to: url, options: .atomic)
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

    private struct ClassificationTarget: Identifiable {
        let id: String
        let key: String
        let name: String
        let inferredCategory: AppCategory
    }

    private var recentClassificationTargets: [ClassificationTarget] {
        let events = (appState.pastSessions.flatMap { $0.events ?? [] } + appState.session.events)
            .sorted { $0.timestamp > $1.timestamp }
        var seen = Set<String>()
        var targets: [ClassificationTarget] = []
        for event in events {
            if !event.owner.isEmpty {
                let appKey = "app:\(event.owner.lowercased())"
                if seen.insert(appKey).inserted {
                    targets.append(
                        ClassificationTarget(
                            id: appKey,
                            key: appKey,
                            name: event.owner,
                            inferredCategory: event.category
                        )
                    )
                }
            }

            if let urlString = event.url,
               let domain = classificationDomain(from: urlString) {
                let domainKey = "domain:\(domain)"
                if seen.insert(domainKey).inserted {
                    targets.append(
                        ClassificationTarget(
                            id: domainKey,
                            key: domainKey,
                            name: domain,
                            inferredCategory: event.category
                        )
                    )
                }
            }

            if targets.count >= 40 {
                return Array(targets.prefix(40))
            }
        }
        return targets
    }

    private func classificationDomain(from value: String) -> String? {
        let candidate = value.contains("://") ? value : "https://\(value)"
        guard let host = URL(string: candidate)?.host?.lowercased() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
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
        appState.classificationOverrides.removeAll()
        // Route through setters so each default is re-persisted to the freshly
        // cleared UserDefaults (direct assignment skipped persistence, leaving
        // state and disk out of sync) and no preference is silently missed.
        appState.setTheme(.light)
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

private struct ClassificationSettingsRow: View {
    let name: String
    @Binding var selection: AppCategory

    var body: some View {
        HStack(spacing: Space.md) {
            IconBadge(systemName: "app", color: selection.color, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(TypeScale.heading)
                    .lineLimit(1)
                Text("Override Drift's automatic classification")
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.driftMuted)
            }
            Spacer()
            Picker("Classification", selection: $selection) {
                ForEach(AppCategory.allCases, id: \.rawValue) { category in
                    Text(category.label).tag(category)
                }
            }
            .labelsHidden()
            .frame(width: 150)
        }
        .padding(.horizontal, Space.lg)
        .frame(minHeight: 72)
    }
}

private struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(spacing: Space.md) {
            IconBadge(systemName: icon, color: .secondary, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(TypeScale.heading)
                Text(subtitle).font(TypeScale.caption).foregroundStyle(Color.driftMuted)
            }
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.driftMuted)
            }
        }
        .padding(.horizontal, Space.lg)
        .frame(minHeight: 72)
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
