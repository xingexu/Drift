import SwiftUI
import AppKit
import CoreText

private func driftAdaptiveColor(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    })
}

enum PixelFont {
    static let postScriptName = "PressStart2P-Regular"

    static func register() {
        let url = Bundle.module.url(
            forResource: "PressStart2P",
            withExtension: "ttf",
            subdirectory: "Fonts"
        ) ?? Bundle.module.url(forResource: "PressStart2P", withExtension: "ttf")

        guard let url else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func font(_ size: CGFloat) -> Font {
        .custom(postScriptName, size: size)
    }
}

// MARK: - Drift Design System v2
// One source of truth for every visual decision in the app.
// Pixel-informed visual language shared by every app surface.

// MARK: - Accent Color Palette

/// A named accent color preset used in the Appearance settings.
struct AccentOption {
    let name: String
    let color: Color
}

/// Namespace for design-system constants that aren't view modifiers.
enum DriftDesign {
    /// Existing keys stay stable for saved preferences; colors map to the desert palette.
    static let accents: [AccentOption] = [
        AccentOption(name: "indigo",  color: Color.accent),
        AccentOption(name: "violet",  color: Color(red: 0.72, green: 0.35, blue: 0.52)),
        AccentOption(name: "rose",    color: Color(red: 0.82, green: 0.29, blue: 0.28)),
        AccentOption(name: "emerald", color: Color(red: 0.42, green: 0.56, blue: 0.22)),
        AccentOption(name: "amber",   color: Color(red: 0.91, green: 0.53, blue: 0.18)),
        AccentOption(name: "sky",     color: Color(red: 0.25, green: 0.59, blue: 0.66)),
    ]
}

// MARK: - Color Palette

extension Color {
    // Brand
    static let accent = driftAdaptiveColor(
        light: NSColor(red: 0.910, green: 0.475, blue: 0.349, alpha: 1), // #e87959
        dark: NSColor(red: 1.000, green: 0.404, blue: 0.310, alpha: 1)   // #ff674f
    )
    static let accentDeep = driftAdaptiveColor(
        light: NSColor(red: 0.835, green: 0.467, blue: 0.349, alpha: 1), // #d57759
        dark: NSColor(red: 0.812, green: 0.380, blue: 0.286, alpha: 1)   // #cf6149
    )

    static let driftBackground = driftAdaptiveColor(
        light: NSColor(red: 0.984, green: 0.973, blue: 0.949, alpha: 1), // #fbf8f2
        dark: NSColor(red: 0.067, green: 0.075, blue: 0.149, alpha: 1)   // #111326
    )
    static let driftPanel = driftAdaptiveColor(
        light: NSColor(red: 1.000, green: 0.992, blue: 0.976, alpha: 0.97), // rgba #fffdf9
        dark: NSColor(red: 0.122, green: 0.102, blue: 0.212, alpha: 0.97)   // rgba #1f1a36
    )
    static let driftPanelRaised = driftAdaptiveColor(
        light: NSColor(red: 0.984, green: 0.973, blue: 0.949, alpha: 0.98), // #fdf8f2
        dark: NSColor(red: 0.145, green: 0.114, blue: 0.239, alpha: 0.97)   // #251d3d
    )
    static let driftPanelInset = driftAdaptiveColor(
        light: NSColor(red: 1.000, green: 0.988, blue: 0.969, alpha: 0.92),
        dark: NSColor(red: 0.094, green: 0.078, blue: 0.169, alpha: 0.72)
    )
    static let driftBorder = driftAdaptiveColor(
        light: NSColor(red: 0.851, green: 0.631, blue: 0.467, alpha: 0.58),
        dark: NSColor(red: 0.855, green: 0.471, blue: 0.306, alpha: 0.55)
    )
    static let driftShadow = driftAdaptiveColor(
        light: NSColor(red: 0.780, green: 0.572, blue: 0.408, alpha: 0.07),
        dark: NSColor(red: 0.482, green: 0.224, blue: 0.259, alpha: 0.13)
    )
    static let driftText = driftAdaptiveColor(
        light: NSColor(red: 0.161, green: 0.153, blue: 0.176, alpha: 1), // #29272d
        dark: NSColor(red: 0.961, green: 0.945, blue: 0.922, alpha: 1)   // #f5f1eb
    )
    static let driftMuted = driftAdaptiveColor(
        light: NSColor(red: 0.404, green: 0.380, blue: 0.416, alpha: 1), // #67616a
        dark: NSColor(red: 0.737, green: 0.710, blue: 0.776, alpha: 1)   // #bcb5c6
    )

    // Semantic states
    static let productive  = Color(red: 0.392, green: 0.702, blue: 0.420) // #64b36b
    static let distraction = Color(red: 1.000, green: 0.404, blue: 0.310)
    static let streak      = Color(red: 0.945, green: 0.706, blue: 0.353) // #f1b45a
    static let caution     = Color(red: 0.875, green: 0.510, blue: 0.396)

    // Surfaces (adaptive — use in all color scheme contexts)
    /// Subtle card background — system control bg
    static let cardBg      = Color.driftPanel
    /// Hover/selected row background
    static let rowHover    = Color.driftPanelRaised

    // Borders & separators
    /// Standard border — 15% opaque
    static let border      = Color.driftBorder
    /// Strong border — sidebar dividers
    static let sep         = Color.driftBorder
}

// MARK: - Pixel Brand Mark

struct PixelDLogo: View {
    var size: CGFloat = 32
    var background: Color = .accent
    var foreground: Color = Color(red: 1.00, green: 0.94, blue: 0.65)
    var shadow: Color = .driftShadow

    private static let rows: [[Int]] = [
        [1, 1, 1, 1, 0, 0],
        [1, 1, 0, 1, 1, 0],
        [1, 1, 0, 0, 1, 1],
        [1, 1, 0, 0, 1, 1],
        [1, 1, 0, 0, 1, 1],
        [1, 1, 0, 0, 1, 1],
        [1, 1, 0, 1, 1, 0],
        [1, 1, 1, 1, 0, 0],
    ]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(shadow)
                .frame(width: size, height: size)
                .offset(x: max(3, size * 0.10), y: max(3, size * 0.10))

            Rectangle()
                .fill(background)
                .frame(width: size, height: size)
                .overlay(Rectangle().strokeBorder(Color(red: 1.00, green: 0.94, blue: 0.65).opacity(0.78), lineWidth: max(1, size * 0.04)))

            VStack(spacing: 0) {
                ForEach(0..<Self.rows.count, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<Self.rows[row].count, id: \.self) { column in
                            Rectangle()
                                .fill(Self.rows[row][column] == 1 ? foreground : Color.clear)
                                .frame(width: pixel, height: pixel)
                        }
                    }
                }
            }
            .frame(width: pixel * 6, height: pixel * 8)
        }
        .frame(width: size + max(3, size * 0.10), height: size + max(3, size * 0.10))
    }

    private var pixel: CGFloat {
        floor(size / 12)
    }
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
        static let xs   = Elevation.Shadow(color: .black.opacity(0.05), radius: 0, x: 2, y: 2)
        static let sm   = Elevation.Shadow(color: .black.opacity(0.07), radius: 0, x: 3, y: 3)
        static let md   = Elevation.Shadow(color: .black.opacity(0.11), radius: 0, x: 5, y: 5)
        static let lg   = Elevation.Shadow(color: .black.opacity(0.18), radius: 0, x: 8, y: 8)
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
    static let xs:   CGFloat = 3
    static let sm:   CGFloat = 4
    static let md:   CGFloat = 5
    static let lg:   CGFloat = 5
    static let xl:   CGFloat = 6
    static let pill: CGFloat = 999
}

// MARK: - Typography Scale

enum TypeScale {
    static let display: Font = PixelFont.font(36)
    static let h1:      Font = PixelFont.font(24)
    static let h2:      Font = PixelFont.font(15)
    static let heading: Font = PixelFont.font(11)
    static let bodyMd:  Font = PixelFont.font(10)
    static let bodySm:  Font = PixelFont.font(9)
    static let caption: Font = PixelFont.font(8)
    static let tiny:    Font = PixelFont.font(7)
    // Numeric display keeps the landing-page arcade character.
    static let monoLg:  Font = PixelFont.font(28)
    static let monoMd:  Font = PixelFont.font(15)
    static let monoSm:  Font = PixelFont.font(10)
    static let monoXs:  Font = PixelFont.font(8)
    // Section overline labels
    static let label:   Font = PixelFont.font(8)
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
            .foregroundStyle(Color.driftMuted)
            .textCase(.uppercase)
            .tracking(0)
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
                    .fill(Color.driftPanel)
                    .elevate(.sm)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.driftBorder, lineWidth: 1)
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
                    .fill(Color.driftPanelInset)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.driftBorder.opacity(0.72), lineWidth: 1)
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
                    .fill(color.opacity(0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(color.opacity(0.42), lineWidth: 1)
                    }
                    .shadow(color: Color.driftShadow, radius: 0, x: 3, y: 3)
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
            .offset(x: isHovered ? -2 : 0, y: isHovered ? -2 : 0)
            .shadow(
                color: .black.opacity(isHovered ? 0.16 : 0.07),
                radius: 0,
                x: isHovered ? 5 : 3,
                y: isHovered ? 5 : 3
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
            Rectangle()
                .fill(color)
                .frame(width: 7, height: 7)
                .overlay(
                    Rectangle()
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
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
                    .textCase(.uppercase)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm + 1)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background {
                Rectangle()
                    .fill(isHovered ? Color.driftPanelRaised : Color.driftPanel)
                    .overlay(Rectangle().strokeBorder(color.opacity(isHovered ? 0.95 : 0.72), lineWidth: 1.5))
                    .shadow(color: Color.driftShadow, radius: 0, x: isHovered ? 3 : 2, y: isHovered ? 3 : 2)
            }
            .foregroundStyle(Color.driftText)
            .animation(Anim.hover, value: isHovered)
        }
        .buttonStyle(DriftButtonStyle(variant: .primary))
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
                    .textCase(.uppercase)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs + 1)
            .background {
                Rectangle()
                    .fill(isHovered ? Color.driftPanelRaised : Color.driftPanel)
                    .overlay {
                        Rectangle().strokeBorder(Color.driftBorder.opacity(isHovered ? 0.9 : 0.65), lineWidth: 1)
                    }
                    .shadow(color: Color.driftShadow.opacity(0.55), radius: 0, x: isHovered ? 3 : 2, y: isHovered ? 3 : 2)
            }
            .foregroundStyle(isHovered ? Color.accent : Color.driftText)
            .animation(Anim.hover, value: isHovered)
        }
        .buttonStyle(DriftButtonStyle(variant: .secondary))
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
                    .textCase(.uppercase)
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xxs + 1)
            .background(
                Rectangle()
                    .fill(isHovered ? color.opacity(0.14) : .clear)
            )
            .foregroundStyle(isHovered ? color : Color.driftMuted)
            .animation(Anim.hover, value: isHovered)
        }
        .buttonStyle(DriftButtonStyle(variant: .ghost))
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
            Rectangle()
                .fill(color.opacity(0.12))
                .frame(width: size, height: size)
                .overlay(Rectangle().strokeBorder(color.opacity(0.42), lineWidth: 1))
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
                Rectangle()
                    .fill(Color.driftPanelInset)
                    .overlay {
                        Rectangle().strokeBorder(Color.driftBorder, lineWidth: 1)
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
                Rectangle()
                    .fill(dotColor.opacity(0.35))
                    .scaleEffect(pulsing ? 2.2 : 1.0)
                    .opacity(pulsing ? 0 : 0.6)
                    .animation(Anim.breathe, value: pulsing)
                    .onAppear { pulsing = true }
            }
            Rectangle()
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
                    Rectangle()
                        .fill(Color.distraction.opacity(0.22))

                    // Fill
                    Rectangle()
                        .fill(Color.productive)
                        .frame(width: geo.size.width * max(0, min(1, focusFraction)))
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(Color.white.opacity(0.24))
                                .frame(height: max(1, height / 3))
                        }
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
                        Rectangle().fill(Color.productive).frame(width: 5, height: 5)
                    }
                    Spacer()
                    Label {
                        Text("\(Int((1 - focusFraction) * 100))% Drift")
                            .font(TypeScale.caption)
                            .foregroundStyle(Color.distraction)
                    } icon: {
                        Rectangle().fill(Color.distraction).frame(width: 5, height: 5)
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
                Rectangle()
                    .fill(color.opacity(0.12))
                    .overlay(Rectangle().strokeBorder(color.opacity(0.62), lineWidth: 1))
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
                Rectangle()
                    .fill(Color.driftPanel)
                    .overlay {
                        Rectangle().strokeBorder(Color.driftBorder.opacity(0.85), lineWidth: 1)
                    }
                    .shadow(color: accentColor.opacity(0.14), radius: 0, x: 2, y: 2)
                    .shadow(color: Color.driftShadow, radius: 0, x: 2, y: 2)
            }
    }
}

extension View {
    func driftGlassCard(accent: Color = .clear, padding: CGFloat = Space.xl, radius: CGFloat = Radius.lg) -> some View {
        modifier(DriftGlassCard(accentColor: accent, padding: padding, radius: radius))
    }
}

// MARK: - Pixel Panel

struct PixelPanel: ViewModifier {
    var padding: CGFloat = 0
    var border: Color = .driftBorder
    var fill: Color = .driftPanel
    var shadow: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill.opacity(0.88))
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.clear,
                                Color.black.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(border.opacity(0.78), lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        Rectangle()
                            .fill(Color.streak.opacity(0.72))
                            .frame(width: 46, height: 2)
                            .padding(.leading, 18)
                    }
                    .shadow(color: shadow ? Color.black.opacity(0.22) : .clear, radius: 0, x: 4, y: 4)
            }
    }
}

extension View {
    func pixelPanel(
        padding: CGFloat = 0,
        border: Color = .driftBorder,
        fill: Color = .driftPanel,
        shadow: Bool = true
    ) -> some View {
        modifier(PixelPanel(padding: padding, border: border, fill: fill, shadow: shadow))
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
                color.opacity(opacity * 0.16)
                Rectangle()
                    .fill(color.opacity(opacity))
                    .frame(width: geo.size.width * 0.28, height: geo.size.height * 0.18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Rectangle()
                    .fill(color.opacity(opacity * 0.48))
                    .frame(width: geo.size.width * 0.18, height: geo.size.height * 0.14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
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
