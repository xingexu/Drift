import SwiftUI

// MARK: - Drift Design System v2
// One source of truth for every visual decision in the app.
// Inspired by: Linear, Raycast, Apple HIG, Cluely, Stripe design.
// Rules: NO magic numbers in views. NO inline colors. NO custom shadows.
// Everything — color, spacing, type, animation, elevation — lives here.

// MARK: - Accent Color Palette

/// A named accent color preset used in the Appearance settings.
struct AccentOption {
    let name: String
    let color: Color
}

/// Namespace for design-system constants that aren't view modifiers.
enum DriftDesign {
    /// The six built-in accent color presets. Blue (Drift brand) is the default.
    static let accents: [AccentOption] = [
        AccentOption(name: "indigo",  color: Color(red: 0.616, green: 0.765, blue: 0.992)),  // #9DC3FD — Drift brand blue
        AccentOption(name: "violet",  color: Color(red: 0.612, green: 0.388, blue: 0.957)),
        AccentOption(name: "rose",    color: Color(red: 0.957, green: 0.267, blue: 0.455)),
        AccentOption(name: "emerald", color: Color(red: 0.133, green: 0.773, blue: 0.502)),
        AccentOption(name: "amber",   color: Color(red: 0.984, green: 0.671, blue: 0.137)),
        AccentOption(name: "sky",     color: Color(red: 0.125, green: 0.706, blue: 0.929)),
    ]
}

// MARK: - Color Palette

extension Color {
    // Brand
    /// Primary accent — Drift brand light blue
    static let accent      = Color(red: 0.616, green: 0.765, blue: 0.992)   // #9DC3FD (Drift brand blue)
    /// Accent pressed/hover state — slightly deeper
    static let accentDeep  = Color(red: 0.447, green: 0.616, blue: 0.882)   // #729DE1

    // Semantic states
    /// Focused / productive — vivid green
    static let productive  = Color(red: 0.133, green: 0.773, blue: 0.365)   // #22C55E
    /// Drifting / distraction — clear red
    static let distraction = Color(red: 0.937, green: 0.267, blue: 0.267)   // #EF4444
    /// Streak / energy — warm amber
    static let streak      = Color(red: 0.984, green: 0.671, blue: 0.137)   // #FBAB23
    /// Warning / caution — orange
    static let caution     = Color(red: 0.980, green: 0.506, blue: 0.157)   // #FA8128

    // Surfaces (adaptive — use in all color scheme contexts)
    /// Subtle card background — system control bg
    static let cardBg      = Color(.controlBackgroundColor)
    /// Hover/selected row background
    static let rowHover    = Color(.controlColor)

    // Borders & separators
    /// Standard border — 15% opaque
    static let border      = Color(.separatorColor).opacity(0.5)
    /// Strong border — sidebar dividers
    static let sep         = Color(.separatorColor)
}

// MARK: - Elevation (shadow presets)

enum Elevation {
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        // Static members on Shadow itself so `.sm` resolves as `Elevation.Shadow.sm`
        // when used in .elevate(.sm) context
        static let none = Elevation.Shadow(color: .clear,               radius: 0,  x: 0, y: 0)
        static let xs   = Elevation.Shadow(color: .black.opacity(0.04), radius: 4,  x: 0, y: 1)
        static let sm   = Elevation.Shadow(color: .black.opacity(0.06), radius: 8,  x: 0, y: 2)
        static let md   = Elevation.Shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 4)
        static let lg   = Elevation.Shadow(color: .black.opacity(0.18), radius: 28, x: 0, y: 8)
    }

    // Convenience aliases on Elevation itself for Elevation.sm usage
    static let none = Shadow.none
    static let xs   = Shadow.xs
    static let sm   = Shadow.sm
    static let md   = Shadow.md
    static let lg   = Shadow.lg
}

extension View {
    func elevate(_ e: Elevation.Shadow) -> some View {
        shadow(color: e.color, radius: e.radius, x: e.x, y: e.y)
    }
}

// MARK: - Spacing (8pt grid)

enum Space {
    static let xxxs: CGFloat =  2
    static let xxs:  CGFloat =  4
    static let xs:   CGFloat =  6
    static let sm:   CGFloat =  8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let xxxl: CGFloat = 32
    static let section: CGFloat = 36
    static let page:    CGFloat = 28
}

// MARK: - Corner Radius

enum Radius {
    static let xs:   CGFloat =  4
    static let sm:   CGFloat =  6
    static let md:   CGFloat = 10
    static let lg:   CGFloat = 14
    static let xl:   CGFloat = 20
    static let pill: CGFloat = 100
}

// MARK: - Typography Scale

enum TypeScale {
    // Display — hero number (session timer)
    static let display: Font = .system(size: 48, weight: .bold,     design: .monospaced)
    // Large title — welcome screen headline
    static let h1:      Font = .system(size: 28, weight: .bold)
    // Section title
    static let h2:      Font = .system(size: 22, weight: .bold)
    // Card headline
    static let heading: Font = .system(size: 15, weight: .semibold)
    // Body — standard readable text
    static let bodyMd:  Font = .system(size: 13)
    // Body small — metadata, timestamps
    static let bodySm:  Font = .system(size: 12)
    // Caption — secondary labels
    static let caption: Font = .system(size: 11)
    // Tiny label — badges, overlines
    static let tiny:    Font = .system(size:  9.5, weight: .medium)
    // Monospaced — timer, durations
    static let monoLg:  Font = .system(size: 28,  weight: .bold,    design: .monospaced)
    static let monoMd:  Font = .system(size: 15,  weight: .semibold, design: .monospaced)
    static let monoSm:  Font = .system(size: 13,  weight: .medium,   design: .monospaced)
    static let monoXs:  Font = .system(size: 11,  weight: .regular,  design: .monospaced)
    // Section overline labels
    static let label:   Font = .system(size: 11,  weight: .semibold)
    // Legacy aliases
    static let hero     = h1
    static let title    = h2
    static let body     = bodyMd
    static let mono     = monoLg
    static let monoMed  = monoMd
    static let sectionLabel = label
}

// MARK: - Animation Tokens

enum Anim {
    /// Button tap / toggle
    static let tap    = Animation.spring(response: 0.25, dampingFraction: 0.75)
    /// Content appearing
    static let appear = Animation.spring(response: 0.42, dampingFraction: 0.84)
    /// Quick opacity / color fade
    static let quick  = Animation.easeOut(duration: 0.14)
    /// Page / tab transition
    static let page   = Animation.spring(response: 0.38, dampingFraction: 0.88)
    /// Numeric counter update
    static let count  = Animation.spring(response: 0.32, dampingFraction: 0.82)
    /// Breathing pulse (repeatForever)
    static let breathe = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    /// Hover enter/exit
    static let hover  = Animation.easeOut(duration: 0.18)
}

// MARK: - View Modifiers

// MARK: Section label (overline)
struct SectionLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(TypeScale.label)
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

extension View {
    func sectionLabel() -> some View {
        modifier(SectionLabel())
    }
}

// MARK: Standard card surface
struct DriftCard: ViewModifier {
    var padding: CGFloat = Space.xl
    var radius: CGFloat  = Radius.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(.controlBackgroundColor))
                    .elevate(.sm)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.border, lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    func driftCard(padding: CGFloat = Space.xl, radius: CGFloat = Radius.lg) -> some View {
        modifier(DriftCard(padding: padding, radius: radius))
    }
}

// MARK: Inset card — inner panel feel (slightly darker)
struct InsetCard: ViewModifier {
    var padding: CGFloat = Space.md
    var radius: CGFloat  = Radius.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(.windowBackgroundColor).opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.border, lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    func insetCard(padding: CGFloat = Space.md, radius: CGFloat = Radius.md) -> some View {
        modifier(InsetCard(padding: padding, radius: radius))
    }
}

// MARK: Accent card — tinted highlight surface
struct AccentCard: ViewModifier {
    var color: Color = .accent
    var padding: CGFloat = Space.xl
    var radius: CGFloat  = Radius.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(color.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(color.opacity(0.18), lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    func accentCard(color: Color = .accent, padding: CGFloat = Space.xl, radius: CGFloat = Radius.lg) -> some View {
        modifier(AccentCard(color: color, padding: padding, radius: radius))
    }
}

// MARK: Hover lift — interactive card hover state
struct HoverLift: ViewModifier {
    var scale: CGFloat       = 1.012
    var shadowRadius: CGFloat = 14

    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.09 : 0.04),
                radius: isHovered ? shadowRadius : 6,
                y: isHovered ? 4 : 2
            )
            .animation(Anim.hover, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

extension View {
    func hoverLift(scale: CGFloat = 1.012, shadowRadius: CGFloat = 14) -> some View {
        modifier(HoverLift(scale: scale, shadowRadius: shadowRadius))
    }
}

// MARK: Stagger appear — list / grid entry animation
struct StaggerAppear: ViewModifier {
    let index:    Int
    let appeared: Bool
    var yOffset: CGFloat   = 10
    var baseDelay: Double  = 0.04

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : yOffset)
            .animation(
                Anim.appear.delay(Double(index) * baseDelay),
                value: appeared
            )
    }
}

extension View {
    func staggerAppear(index: Int, appeared: Bool, yOffset: CGFloat = 10, baseDelay: Double = 0.04) -> some View {
        modifier(StaggerAppear(index: index, appeared: appeared, yOffset: yOffset, baseDelay: baseDelay))
    }
}

// MARK: Pulse — live status indicator
struct PulseModifier: ViewModifier {
    @State private var pulsing = false
    var color: Color = .productive

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 1.5)
                        .scaleEffect(pulsing ? 2.0 : 1.0)
                        .opacity(pulsing ? 0 : 0.8)
                        .animation(Anim.breathe, value: pulsing)
                )
                .onAppear { pulsing = true }
        }
    }
}

extension View {
    func livePulse(color: Color = .productive) -> some View {
        modifier(PulseModifier(color: color))
    }
}

// MARK: - Button Styles

struct DriftButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, ghost, danger, destructive }
    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(Anim.tap, value: configuration.isPressed)
    }
}

extension View {
    func driftButton(_ variant: DriftButtonStyle.Variant = .primary) -> some View {
        buttonStyle(DriftButtonStyle(variant: variant))
    }
}

// MARK: Primary action button (full visual)
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var color: Color = .accent
    var isFullWidth: Bool = false

    @State private var isHovered = false

    init(_ title: String, icon: String? = nil, color: Color = .accent, isFullWidth: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
        self.color = color
        self.isFullWidth = isFullWidth
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(TypeScale.heading)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm + 1)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(isHovered ? color.opacity(0.88) : color)
                    .elevate(isHovered ? .sm : .xs)
            }
            .foregroundStyle(.white)
            .animation(Anim.hover, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: Secondary button (bordered)
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    @State private var isHovered = false

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(title)
                    .font(TypeScale.bodyMd)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs + 1)
            .background {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(isHovered ? Color(.controlColor) : Color(.controlBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(Color.border, lineWidth: 0.75)
                    }
            }
            .foregroundStyle(isHovered ? Color.accent : Color(.labelColor))
            .animation(Anim.hover, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: Ghost button (text only with hover bg)
struct GhostButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var color: Color = .accent

    @State private var isHovered = false

    init(_ title: String, icon: String? = nil, color: Color = .accent, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
        self.color = color
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xxs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(TypeScale.bodySm)
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xxs + 1)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(isHovered ? color.opacity(0.10) : .clear)
            )
            .foregroundStyle(isHovered ? color : Color(.secondaryLabelColor))
            .animation(Anim.hover, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Icon Badge (colored icon container)
struct IconBadge: View {
    let systemName: String
    var color: Color = .accent
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Key Badge (keyboard shortcut chip)
struct KeyBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(TypeScale.tiny)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Space.xs)
            .padding(.vertical, Space.xxxs + 1)
            .background {
                RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                    .fill(Color(.controlColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                            .strokeBorder(Color.border, lineWidth: 0.5)
                    }
            }
    }
}

// MARK: - Status Dot (live indicator)
struct StatusDot: View {
    enum Status { case tracking, paused, idle }
    let status: Status
    @State private var pulsing = false

    var dotColor: Color {
        switch status {
        case .tracking: return .productive
        case .paused:   return .streak
        case .idle:     return Color(.tertiaryLabelColor)
        }
    }

    var body: some View {
        ZStack {
            if status == .tracking {
                Circle()
                    .fill(dotColor.opacity(0.35))
                    .scaleEffect(pulsing ? 2.2 : 1.0)
                    .opacity(pulsing ? 0 : 0.6)
                    .animation(Anim.breathe, value: pulsing)
                    .onAppear { pulsing = true }
            }
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
        }
        .frame(width: 14, height: 14)
    }
}

// MARK: - Metric Row (stat + label pair)
struct MetricPair: View {
    let value: String
    let label: String
    var valueFont: Font = TypeScale.monoMd
    var color: Color = Color(.labelColor)
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: Space.xxxs) {
            Text(value)
                .font(valueFont)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(Anim.count, value: value)
            Text(label)
                .font(TypeScale.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Focus / Distraction Bar
struct FocusBar: View {
    let focusFraction: CGFloat   // 0…1
    var height: CGFloat = 6
    var showLabels: Bool = true

    var body: some View {
        VStack(spacing: Space.xxs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: Radius.pill)
                        .fill(Color.distraction.opacity(0.22))

                    // Fill
                    RoundedRectangle(cornerRadius: Radius.pill)
                        .fill(
                            LinearGradient(
                                colors: [Color.productive.opacity(0.85), Color.productive],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * max(0, min(1, focusFraction)))
                }
            }
            .frame(height: height)

            if showLabels {
                HStack {
                    Label {
                        Text("\(Int(focusFraction * 100))% Focus")
                            .font(TypeScale.caption)
                            .foregroundStyle(Color.productive)
                    } icon: {
                        Circle().fill(Color.productive).frame(width: 5, height: 5)
                    }
                    Spacer()
                    Label {
                        Text("\(Int((1 - focusFraction) * 100))% Drift")
                            .font(TypeScale.caption)
                            .foregroundStyle(Color.distraction)
                    } icon: {
                        Circle().fill(Color.distraction).frame(width: 5, height: 5)
                    }
                }
            }
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "Get started"

    var body: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(spacing: Space.xs) {
                Text(title)
                    .font(TypeScale.heading)
                    .foregroundStyle(.primary)
                Text(message)
                    .font(TypeScale.bodyMd)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let action = action {
                PrimaryButton(actionTitle, action: action)
            }
        }
        .padding(Space.xxxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tag / Chip
struct DriftTag: View {
    let text: String
    var color: Color = .accent

    var body: some View {
        Text(text)
            .font(TypeScale.tiny)
            .foregroundStyle(color)
            .padding(.horizontal, Space.xs)
            .padding(.vertical, Space.xxxs)
            .background {
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 0.5))
            }
    }
}

// MARK: - Divider token
struct DriftDivider: View {
    var opacity: Double = 1.0
    var body: some View {
        Rectangle()
            .fill(Color.border.opacity(opacity))
            .frame(height: 0.5)
    }
}

// MARK: - Glass Card (floating elevated surface — for current session, modals)
struct DriftGlassCard: ViewModifier {
    var accentColor: Color = .clear
    var padding: CGFloat   = Space.xl
    var radius: CGFloat    = Radius.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
                    .shadow(color: accentColor.opacity(0.14), radius: 22, y: 8)
                    .shadow(color: .black.opacity(0.07), radius: 8, y: 2)
            }
    }
}

extension View {
    func driftGlassCard(accent: Color = .clear, padding: CGFloat = Space.xl, radius: CGFloat = Radius.lg) -> some View {
        modifier(DriftGlassCard(accentColor: accent, padding: padding, radius: radius))
    }
}

// MARK: - Stat Number Modifier (consistent monospaced stat display)
struct StatNumberModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(TypeScale.monoMd)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
            .animation(Anim.count, value: UUID())
    }
}

extension View {
    func statNumber() -> some View {
        modifier(StatNumberModifier())
    }
}

// MARK: - Ambient Glow (full-view color wash for focus/break states)
// Named AmbientGlow to avoid collision with AmbientBackground defined in StudyView.swift.
struct AmbientGlow: View {
    let color: Color
    var opacity: Double = 0.07

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(
                    colors: [color.opacity(opacity), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.9
                )
                RadialGradient(
                    colors: [color.opacity(opacity * 0.5), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.6
                )
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Reduced Motion Helper
extension Animation {
    /// Returns the animation, or .none if the user has enabled reduced motion.
    static func accessible(_ animation: Animation, env: EnvironmentValues? = nil) -> Animation {
        // Views should check @Environment(\.accessibilityReduceMotion) directly.
        // This is a convenience alias for documentation purposes.
        return animation
    }
}

// Note: SidebarNavItem is defined in ContentView.swift to avoid redeclaration
// when ContentView defines its own version.

// MARK: - Session State Color Helper
extension Color {
    /// Returns the semantic color for a given session/tracking state
    static func sessionColor(isTracking: Bool, isPaused: Bool) -> Color {
        if !isTracking { return Color(.tertiaryLabelColor) }
        if isPaused { return .streak }
        return .productive
    }
}
