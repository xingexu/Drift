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

// MARK: - Bundled Images

/// Loads PNG resources copied by SwiftPM under `Drift_Drift.bundle/Images`.
/// `Image(_:bundle:)` only checks the bundle root and therefore cannot find
/// files preserved inside the copied Images directory.
enum DriftImageLoader {
    private static let cache = NSCache<NSString, NSImage>()

    static func png(named name: String) -> NSImage? {
        let key = name as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "Images"
        ) ?? Bundle.module.url(forResource: name, withExtension: "png"),
        let image = NSImage(contentsOf: url) else {
            return nil
        }

        cache.setObject(image, forKey: key)
        return image
    }
}

// MARK: - Drift Design System
// One source of truth for the Drift desktop app interface.

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
        AccentOption(name: "violet",  color: Color(red: 0.42, green: 0.34, blue: 0.40)),
        AccentOption(name: "rose",    color: Color(red: 0.68, green: 0.23, blue: 0.22)),
        AccentOption(name: "emerald", color: Color(red: 0.30, green: 0.56, blue: 0.33)),
        AccentOption(name: "amber",   color: Color(red: 0.74, green: 0.46, blue: 0.17)),
        AccentOption(name: "sky",     color: Color(red: 0.38, green: 0.46, blue: 0.43)),
    ]
}

// MARK: - Color Palette

extension Color {
    // Warm desert control palette. The dark values are the canonical Drift
    // colors; light values keep the same warmth without sacrificing contrast.
    static let driftCanvas = driftAdaptiveColor(
        light: NSColor(red: 0.957, green: 0.918, blue: 0.871, alpha: 1),
        dark: NSColor(red: 0.067, green: 0.063, blue: 0.086, alpha: 1) // #111016
    )
    static let cocoa = driftAdaptiveColor(
        light: NSColor(red: 0.996, green: 0.965, blue: 0.918, alpha: 1),
        dark: NSColor(red: 0.141, green: 0.102, blue: 0.086, alpha: 1) // #241A16
    )
    static let cocoaRaised = driftAdaptiveColor(
        light: NSColor(red: 0.925, green: 0.855, blue: 0.773, alpha: 1),
        dark: NSColor(red: 0.188, green: 0.137, blue: 0.114, alpha: 1) // #30231D
    )
    static let cream = driftAdaptiveColor(
        light: NSColor(red: 0.141, green: 0.102, blue: 0.086, alpha: 1),
        dark: NSColor(red: 1.000, green: 0.953, blue: 0.875, alpha: 1) // #FFF3DF
    )
    static let creamMuted = driftAdaptiveColor(
        light: NSColor(red: 0.388, green: 0.329, blue: 0.286, alpha: 1),
        dark: NSColor(red: 0.722, green: 0.663, blue: 0.616, alpha: 1) // #B8A99D
    )
    static let sand = Color(red: 0.910, green: 0.780, blue: 0.655) // #E8C7A7
    static let sandInk = Color(red: 0.141, green: 0.102, blue: 0.086) // #241A16
    /// Fixed light text for copy placed directly over the dark desert artwork.
    /// Panel text remains adaptive through `cream` and `creamMuted`.
    static let desertCreamText = Color(red: 1.000, green: 0.953, blue: 0.875) // #FFF3DF
    static let desertMutedText = Color(red: 0.722, green: 0.663, blue: 0.616) // #B8A99D
    static let focusBlue = Color(red: 0.471, green: 0.588, blue: 1.000) // #7896FF
    static let neutral = Color(red: 0.596, green: 0.576, blue: 0.604) // #98939A

    // Brand
    static let accent = driftAdaptiveColor(
        light: NSColor(red: 0.247, green: 0.365, blue: 0.824, alpha: 1),
        dark: NSColor(red: 0.471, green: 0.588, blue: 1.000, alpha: 1)
    )
    static let accentDeep = driftAdaptiveColor(
        light: NSColor(red: 0.067, green: 0.078, blue: 0.157, alpha: 1),
        dark: NSColor(red: 0.035, green: 0.035, blue: 0.090, alpha: 1)
    )

    static let driftBackground = driftAdaptiveColor(
        light: NSColor(red: 0.957, green: 0.918, blue: 0.871, alpha: 1),
        dark: NSColor(red: 0.067, green: 0.063, blue: 0.086, alpha: 1)
    )
    static let driftPanel = driftAdaptiveColor(
        light: NSColor(red: 0.996, green: 0.965, blue: 0.918, alpha: 0.94),
        dark: NSColor(red: 0.141, green: 0.102, blue: 0.086, alpha: 0.94)
    )
    static let driftPanelRaised = driftAdaptiveColor(
        light: NSColor(red: 0.925, green: 0.855, blue: 0.773, alpha: 0.98),
        dark: NSColor(red: 0.188, green: 0.137, blue: 0.114, alpha: 0.98)
    )
    static let driftPanelInset = driftAdaptiveColor(
        light: NSColor(red: 0.941, green: 0.878, blue: 0.808, alpha: 0.98),
        dark: NSColor(red: 0.110, green: 0.078, blue: 0.067, alpha: 0.98)
    )
    static let driftBorder = driftAdaptiveColor(
        light: NSColor(red: 0.141, green: 0.102, blue: 0.086, alpha: 0.18),
        dark: NSColor(red: 1.000, green: 0.953, blue: 0.875, alpha: 0.14)
    )
    static let driftShadow = driftAdaptiveColor(
        light: NSColor.black.withAlphaComponent(0.34),
        dark: NSColor.black.withAlphaComponent(0.34)
    )
    static let driftText = driftAdaptiveColor(
        light: NSColor(red: 0.141, green: 0.102, blue: 0.086, alpha: 1),
        dark: NSColor(red: 1.000, green: 0.953, blue: 0.875, alpha: 1)
    )
    static let driftMuted = driftAdaptiveColor(
        light: NSColor(red: 0.388, green: 0.329, blue: 0.286, alpha: 1),
        dark: NSColor(red: 0.722, green: 0.663, blue: 0.616, alpha: 1)
    )

    // Semantic states
    static let productive  = Color(red: 0.322, green: 0.663, blue: 0.420) // #52A96B
    static let distraction = Color(red: 0.902, green: 0.424, blue: 0.361) // #E66C5C
    static let streak      = Color.sand
    static let caution     = Color(red: 0.929, green: 0.543, blue: 0.341)

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

// MARK: - Pixel Backdrop

struct DriftPixelBackdrop: View {
    var imageName: String = "drift-home-scene"
    var imageOpacity: Double = 1.0
    var washOpacity: Double = 0.46
    var blurRadius: CGFloat = 0
    var imageYOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.driftBackground

                if let image = DriftImageLoader.png(named: imageName) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .antialiased(false)
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .offset(y: imageYOffset)
                        .clipped()
                        .blur(radius: blurRadius)
                        .opacity(imageOpacity)
                        .saturation(1.08)
                        .contrast(1.05)
                }

                if washOpacity > 0 {
                    Color.black.opacity(washOpacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Full-bleed, non-interactive pixel artwork used by the main app pages.
struct DesertBackdrop: View {
    let imageName: String
    var washOpacity: Double = 0.46

    var body: some View {
        DriftPixelBackdrop(
            imageName: imageName,
            imageOpacity: 1,
            washOpacity: washOpacity,
            blurRadius: 0,
            imageYOffset: 0
        )
    }
}

// MARK: - Full-window shell material

enum DriftShellLayer {
    case sidebar
    case toolbar

    var materialOpacity: Double {
        switch self {
        case .sidebar: return 0.58
        case .toolbar: return 0.48
        }
    }

    var tintOpacity: Double {
        switch self {
        case .sidebar: return 0.76
        case .toolbar: return 0.66
        }
    }
}

/// Denser than content glass, but still reveals a quiet impression of the
/// full-window desert through native macOS material blur.
struct DriftShellSurface: View {
    let layer: DriftShellLayer

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(layer.materialOpacity)
            .overlay {
                Rectangle()
                    .fill(Color(red: 0.030, green: 0.024, blue: 0.052).opacity(layer.tintOpacity))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct PixelGridOverlay: View {
    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let step: CGFloat = 12
            let cols = Int(size.width / step) + 2
            let rows = Int(size.height / step) + 2
            for x in 0..<cols {
                for y in 0..<rows where (x + y).isMultiple(of: 6) {
                    let rect = CGRect(x: CGFloat(x) * step, y: CGFloat(y) * step, width: 2, height: 2)
                    context.fill(Path(rect), with: .color(Color.driftText.opacity(0.045)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Brand Mark

struct PixelDLogo: View {
    var size: CGFloat = 32
    var background: Color = .accent
    var foreground: Color = .white
    var shadow: Color = .driftShadow
    var isHighlighted = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(6, size * 0.25), style: .continuous)

        shape
            .fill(background)
            .frame(width: size, height: size)
            .overlay { shape.fill(Color.white.opacity(isHighlighted ? 0.10 : 0)) }
            .overlay(
                Text("D")
                    .font(PixelFont.font(size * 0.38))
                    .foregroundStyle(Color.accentDeep)
            )
            .overlay {
                shape.strokeBorder(
                    Color.desertCreamText.opacity(isHighlighted ? 0.72 : 0.50),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(isHighlighted ? 0.30 : 0.22), radius: 8, y: 4)
            .animation(Anim.quick, value: isHighlighted)
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
        static let xs   = Elevation.Shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        static let sm   = Elevation.Shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        static let md   = Elevation.Shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
        static let lg   = Elevation.Shadow(color: .black.opacity(0.09), radius: 18, x: 0, y: 8)
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
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 6
    static let md:   CGFloat = 8
    static let lg:   CGFloat = 10
    static let xl:   CGFloat = 14
    static let pill: CGFloat = 999
}

// MARK: - Typography Scale

enum TypeScale {
    static let display: Font = PixelFont.font(40)
    static let h1:      Font = PixelFont.font(24)
    static let h2:      Font = .system(size: 20, weight: .semibold)
    static let heading: Font = .system(size: 14, weight: .semibold)
    static let bodyMd:  Font = .system(size: 14, weight: .regular)
    static let bodySm:  Font = .system(size: 13, weight: .regular)
    static let caption: Font = .system(size: 12, weight: .regular)
    static let tiny:    Font = .system(size: 11, weight: .semibold)
    static let monoLg:  Font = .system(size: 31, weight: .semibold, design: .monospaced)
    static let monoMd:  Font = .system(size: 19, weight: .semibold, design: .monospaced)
    static let monoSm:  Font = .system(size: 14, weight: .semibold, design: .monospaced)
    static let monoXs:  Font = .system(size: 12, weight: .semibold, design: .monospaced)
    // Section overline labels
    static let label:   Font = .system(size: 11, weight: .semibold)
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
    static let tap    = Animation.easeOut(duration: 0.14)
    /// Content appearing
    static let appear = Animation.easeOut(duration: 0.18)
    /// Quick opacity / color fade
    static let quick  = Animation.easeOut(duration: 0.14)
    /// Page / tab transition
    static let page   = Animation.easeOut(duration: 0.20)
    /// Numeric counter update
    static let count  = Animation.easeOut(duration: 0.16)
    /// Breathing pulse (repeatForever)
    static let breathe = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    /// Hover enter/exit
    static let hover  = Animation.easeOut(duration: 0.18)
    /// Strong ease-out for interruptible Liquid Glass hover feedback
    static let glass  = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)
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
    var radius: CGFloat  = DriftSurfaceRadius.major

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                DriftGlassSurface(role: .content, cornerRadius: radius)
            }
    }
}

extension View {
    func driftCard(padding: CGFloat = Space.xl, radius: CGFloat = DriftSurfaceRadius.major) -> some View {
        modifier(DriftCard(padding: padding, radius: radius))
    }
}

// MARK: Inset card — inner panel feel (slightly darker)
struct InsetCard: ViewModifier {
    var padding: CGFloat = Space.md
    var radius: CGFloat  = DriftSurfaceRadius.input

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                DriftGlassSurface(role: .contentDense, cornerRadius: radius)
            }
    }
}

extension View {
    func insetCard(padding: CGFloat = Space.md, radius: CGFloat = DriftSurfaceRadius.input) -> some View {
        modifier(InsetCard(padding: padding, radius: radius))
    }
}

// MARK: Accent card — tinted highlight surface
struct AccentCard: ViewModifier {
    var color: Color = .accent
    var padding: CGFloat = Space.xl
    var radius: CGFloat  = DriftSurfaceRadius.major

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                DriftGlassSurface(role: .content, cornerRadius: radius, tint: color)
            }
    }
}

extension View {
    func accentCard(color: Color = .accent, padding: CGFloat = Space.xl, radius: CGFloat = DriftSurfaceRadius.major) -> some View {
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
            .shadow(
                color: .black.opacity(isHovered ? 0.06 : 0.03),
                radius: isHovered ? 8 : 4,
                x: 0,
                y: isHovered ? 3 : 1
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
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct DriftResponsivePressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
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
    var color: Color = .sand
    var isFullWidth: Bool = false

    @State private var isHovered = false

    init(_ title: String, icon: String? = nil, color: Color = .sand, isFullWidth: Bool = false, action: @escaping () -> Void) {
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
            .padding(.horizontal, 18)
            .frame(height: 44)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background {
                Capsule()
                    .fill(color)
                    .shadow(color: Color.black.opacity(0.22), radius: 8, y: 3)
            }
            .foregroundStyle(Color.sandInk)
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
            }
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background {
                DriftGlassSurface(
                    role: .functional,
                    cornerRadius: Radius.pill,
                    isHovered: isHovered
                )
            }
            .foregroundStyle(Color.cream)
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
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(isHovered ? Color.cocoaRaised : .clear)
            )
            .foregroundStyle(isHovered ? Color.cream : Color.driftMuted)
            .animation(Anim.hover, value: isHovered)
        }
        .buttonStyle(DriftButtonStyle(variant: .ghost))
        .onHover { isHovered = $0 }
    }
}

// MARK: - Native Material Surface Language

/// A semantic hierarchy keeps standard material in the content layer and
/// reserves Liquid Glass for controls. This avoids the nested-card effect that
/// appears when every rectangle competes for the same glass treatment.
enum DriftSurfaceRole: Equatable {
    case content
    case contentDense
    case functional

    var fallbackMaterial: Material {
        switch self {
        case .content, .contentDense: return .regularMaterial
        case .functional: return .thinMaterial
        }
    }

    var materialOpacity: Double {
        switch self {
        case .content: return 0.66
        case .contentDense: return 0.76
        case .functional: return 0.58
        }
    }

    var tintOpacity: Double {
        switch self {
        case .content: return 0.24
        case .contentDense: return 0.34
        case .functional: return 0.14
        }
    }

    var borderOpacity: Double {
        switch self {
        case .content: return 0.15
        case .contentDense: return 0.18
        case .functional: return 0.22
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .content: return 0.18
        case .contentDense: return 0.22
        case .functional: return 0.20
        }
    }
}

enum DriftSurfaceRadius {
    static let major: CGFloat = 18
    static let compact: CGFloat = 14
    static let input: CGFloat = 12
    static let icon: CGFloat = 10
}

/// Compatibility vocabulary for existing call sites. New page surfaces use
/// `driftContentSurface` or `driftFunctionalGlass` so their hierarchy is clear.
enum DriftGlassDensity: Equatable {
    case light
    case standard
    case data
    case popover

    var surfaceRole: DriftSurfaceRole {
        switch self {
        case .light, .standard: return .content
        case .data: return .contentDense
        case .popover: return .functional
        }
    }
}

/// One adaptive implementation for every app box. On macOS 26, functional
/// surfaces use native interactive Liquid Glass. Earlier systems use a native
/// material fallback with the same geometry, hierarchy, and accessibility.
struct DriftGlassSurface: View {
    var density: DriftGlassDensity = .standard
    var role: DriftSurfaceRole? = nil
    var cornerRadius: CGFloat = DriftSurfaceRadius.compact
    var tint: Color? = nil
    var isHovered = false
    var functionalDimming: Double = 0.16

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var resolvedRole: DriftSurfaceRole { role ?? density.surfaceRole }
    private var resolvedTint: Color { tint ?? Color.cocoa }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let borderBoost = contrast == .increased ? 0.18 : 0
        let hoverBoost = resolvedRole == .functional && isHovered ? 0.055 : 0

        materialLayer(shape: shape, hoverBoost: hoverBoost)
            .overlay {
                if resolvedRole == .functional && !reduceTransparency {
                    shape.fill(
                        Color.black.opacity(
                            isHovered ? max(0, functionalDimming - 0.03) : functionalDimming
                        )
                    )
                }
            }
            .overlay {
                shape.strokeBorder(
                    Color.cream.opacity(resolvedRole.borderOpacity + borderBoost + hoverBoost),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(contrast == .increased ? 0.30 : 0.18),
                            Color.white.opacity(0.035),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .shadow(
                color: Color.black.opacity(resolvedRole.shadowOpacity + (isHovered ? 0.025 : 0)),
                radius: resolvedRole == .functional ? 18 : 20,
                y: resolvedRole == .functional ? 7 : 9
            )
            .animation(
                reduceMotion ? nil : Anim.glass,
                value: isHovered
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func materialLayer(
        shape: RoundedRectangle,
        hoverBoost: Double
    ) -> some View {
        if reduceTransparency {
            shape
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    shape.fill(Color.cocoa.opacity(resolvedRole == .functional ? 0.74 : 0.86))
                }
        } else if resolvedRole == .functional {
            if #available(macOS 26.0, *) {
                shape
                    .fill(Color.clear)
                    .glassEffect(
                        .regular
                            .tint(resolvedTint.opacity(0.32 + hoverBoost))
                            .interactive(),
                        in: shape
                    )
            } else {
                fallbackMaterial(shape: shape, hoverBoost: hoverBoost)
            }
        } else {
            fallbackMaterial(shape: shape, hoverBoost: hoverBoost)
        }
    }

    private func fallbackMaterial(
        shape: RoundedRectangle,
        hoverBoost: Double
    ) -> some View {
        shape
            .fill(resolvedRole.fallbackMaterial)
            .opacity(resolvedRole.materialOpacity)
            .overlay {
                shape.fill(resolvedTint.opacity(resolvedRole.tintOpacity + hoverBoost))
            }
    }
}

private struct DriftSurfaceModifier: ViewModifier {
    var role: DriftSurfaceRole
    var cornerRadius: CGFloat
    var tint: Color?
    var functionalDimming: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background {
                DriftGlassSurface(
                    role: role,
                    cornerRadius: cornerRadius,
                    tint: tint,
                    isHovered: isHovered,
                    functionalDimming: functionalDimming
                )
            }
            .onHover { hovering in
                guard role == .functional else { return }
                if reduceMotion {
                    isHovered = hovering
                } else {
                    withAnimation(Anim.glass) {
                        isHovered = hovering
                    }
                }
            }
    }
}

private struct DriftInsetSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content.background {
            shape
                .fill(
                    reduceTransparency
                        ? Color(nsColor: .textBackgroundColor)
                        : Color.black.opacity(0.22)
                )
                .overlay {
                    shape.strokeBorder(
                        Color.cream.opacity(contrast == .increased ? 0.34 : 0.13),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
                }
        }
    }
}

extension View {
    func driftContentSurface(
        dense: Bool = false,
        cornerRadius: CGFloat = DriftSurfaceRadius.major
    ) -> some View {
        modifier(
            DriftSurfaceModifier(
                role: dense ? .contentDense : .content,
                cornerRadius: cornerRadius,
                tint: nil,
                functionalDimming: 0
            )
        )
    }

    func driftFunctionalGlass(
        cornerRadius: CGFloat = DriftSurfaceRadius.compact,
        tint: Color? = nil,
        dimmingOpacity: Double = 0.16
    ) -> some View {
        modifier(
            DriftSurfaceModifier(
                role: .functional,
                cornerRadius: cornerRadius,
                tint: tint,
                functionalDimming: dimmingOpacity
            )
        )
    }

    func driftInsetSurface(
        cornerRadius: CGFloat = DriftSurfaceRadius.input
    ) -> some View {
        modifier(DriftInsetSurfaceModifier(cornerRadius: cornerRadius))
    }

    func driftGlass(
        _ density: DriftGlassDensity = .standard,
        cornerRadius: CGFloat = DriftSurfaceRadius.compact
    ) -> some View {
        modifier(
            DriftSurfaceModifier(
                role: density.surfaceRole,
                cornerRadius: cornerRadius,
                tint: nil,
                functionalDimming: density == .popover ? 0.16 : 0
            )
        )
    }
}

struct TactilePanel<Content: View>: View {
    var padding: CGFloat = Space.xl
    var density: DriftGlassDensity = .standard
    var cornerRadius: CGFloat = DriftSurfaceRadius.major
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .driftGlass(density, cornerRadius: cornerRadius)
    }
}

private struct TactilePanelModifier: ViewModifier {
    var padding: CGFloat
    var density: DriftGlassDensity
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        TactilePanel(padding: padding, density: density, cornerRadius: cornerRadius) { content }
    }
}

extension View {
    func tactilePanel(
        padding: CGFloat = Space.xl,
        density: DriftGlassDensity = .standard,
        cornerRadius: CGFloat = DriftSurfaceRadius.major
    ) -> some View {
        modifier(TactilePanelModifier(padding: padding, density: density, cornerRadius: cornerRadius))
    }
}

struct ContentSurfacePanel<Content: View>: View {
    var padding: CGFloat = Space.xl
    var dense = false
    var cornerRadius: CGFloat = DriftSurfaceRadius.major
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .driftContentSurface(dense: dense, cornerRadius: cornerRadius)
    }
}

struct FunctionalGlassPanel<Content: View>: View {
    var padding: CGFloat = Space.xl
    var cornerRadius: CGFloat = DriftSurfaceRadius.major
    var tint: Color? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .driftFunctionalGlass(cornerRadius: cornerRadius, tint: tint)
    }
}

struct PrimaryPillButton: View {
    let title: String
    let icon: String
    var isFullWidth = false
    let action: () -> Void

    var body: some View {
        PrimaryButton(title, icon: icon, color: .sand, isFullWidth: isFullWidth, action: action)
    }
}

struct SecondaryPillButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        SecondaryButton(title, icon: icon, action: action)
    }
}

struct TertiaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        GhostButton(title, icon: icon, color: .sand, action: action)
    }
}

struct IconButton: View {
    let icon: String
    let label: String
    var color: Color = .cream
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(
                    DriftGlassSurface(
                        role: .functional,
                        cornerRadius: DriftSurfaceRadius.icon,
                        isHovered: isHovered
                    )
                )
        }
        .buttonStyle(DriftButtonStyle(variant: .ghost))
        .onHover { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

struct TactileMenuOption<Value: Hashable>: Identifiable {
    let title: String
    let icon: String
    let value: Value
    var id: String { "\(title)-\(String(describing: value))" }
}

struct TactileMenu<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [TactileMenuOption<Value>]
    var label: String? = nil

    private var selectedOption: TactileMenuOption<Value>? {
        options.first { $0.value == selection }
    }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option.value
                } label: {
                    Label(option.title, systemImage: option.icon)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let icon = selectedOption?.icon {
                    Image(systemName: icon)
                }
                Text(label ?? selectedOption?.title ?? "Choose")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.driftMuted)
            }
            .font(TypeScale.bodySm)
            .foregroundStyle(Color.cream)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                DriftGlassSurface(role: .functional, cornerRadius: DriftSurfaceRadius.compact)
            )
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(label ?? "Menu")
    }
}

struct SegmentedControl<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    @EnvironmentObject private var appState: AppState
    @Namespace private var selectionNamespace

    private var reduceMotion: Bool {
        appState.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(TypeScale.bodySm)
                        .fontWeight(selection == option ? .semibold : .regular)
                        .foregroundStyle(selection == option ? Color.sandInk : Color.creamMuted)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background {
                            if selection == option {
                                Capsule()
                                    .fill(Color.sand)
                                    .matchedGeometryEffect(id: "segmented-selection", in: selectionNamespace)
                            }
                        }
                }
                .buttonStyle(DriftButtonStyle(variant: .ghost))
                .accessibilityValue(selection == option ? "Selected" : "")
            }
        }
        .padding(4)
        .driftFunctionalGlass(cornerRadius: Radius.pill, dimmingOpacity: 0.42)
        .animation(
            reduceMotion ? nil : .spring(duration: 0.20, bounce: 0.08),
            value: selection
        )
    }
}

struct ClassificationBadge: View {
    let category: AppCategory

    private var icon: String {
        switch category {
        case .productive: return "checkmark.circle.fill"
        case .neutral: return "minus.circle.fill"
        case .distraction: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        Label(category.label, systemImage: icon)
            .font(TypeScale.tiny)
            .foregroundStyle(category.color)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule().fill(category.color.opacity(0.14)))
            .overlay(Capsule().strokeBorder(category.color.opacity(0.30), lineWidth: 1))
            .accessibilityLabel("Classification: \(category.label)")
    }
}

struct MetricCell: View {
    let label: String
    let value: String
    var comparison: String? = nil
    var color: Color = .cream

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .sectionLabel()
            Text(value)
                .font(TypeScale.monoMd)
                .monospacedDigit()
                .foregroundStyle(color)
            if let comparison, !comparison.isEmpty {
                Text(comparison)
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.driftMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsRow<Trailing: View>: View {
    let title: String
    let explanation: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Space.lg) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(TypeScale.heading)
                Text(explanation)
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.driftMuted)
            }
            Spacer(minLength: Space.xl)
            trailing()
        }
        .padding(.horizontal, Space.lg)
        .frame(minHeight: 58)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cream.opacity(0.10)).frame(height: 1)
        }
    }
}

struct EmptyState: View {
    let icon: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Space.lg) {
            IconBadge(systemName: icon, color: .sand, size: 44)
            Text(message)
                .font(TypeScale.bodyMd)
                .foregroundStyle(Color.driftMuted)
            Spacer()
            if let actionTitle, let action {
                PrimaryPillButton(title: actionTitle, icon: "arrow.right", action: action)
            }
        }
        .padding(Space.xl)
    }
}

// MARK: - Icon Badge (colored icon container)
struct IconBadge: View {
    let systemName: String
    var color: Color = .accent
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(color.opacity(0.28), lineWidth: 1)
                )
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
                    .fill(color.opacity(0.08))
                    .overlay(Rectangle().strokeBorder(color.opacity(0.20), lineWidth: 1))
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
    var radius: CGFloat    = DriftSurfaceRadius.major

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                DriftGlassSurface(
                    role: .functional,
                    cornerRadius: radius,
                    tint: accentColor
                )
            }
    }
}

extension View {
    func driftGlassCard(accent: Color = .clear, padding: CGFloat = Space.xl, radius: CGFloat = DriftSurfaceRadius.major) -> some View {
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
                DriftGlassSurface(
                    role: .contentDense,
                    cornerRadius: DriftSurfaceRadius.compact,
                    tint: fill
                )
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
            DriftPixelBackdrop(imageOpacity: 1, washOpacity: 0.20)
                .frame(width: geo.size.width, height: geo.size.height)
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
