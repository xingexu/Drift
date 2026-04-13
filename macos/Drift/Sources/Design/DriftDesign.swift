import SwiftUI

// MARK: - Drift Design System
// One source of truth for every visual decision in the app.
// NO magic numbers in view files — everything references this.

// MARK: - Animation

enum Anim {
    /// Standard interaction feedback (button taps, toggles)
    static let tap = Animation.spring(response: 0.28, dampingFraction: 0.72)
    /// Content appearing on screen
    static let appear = Animation.spring(response: 0.45, dampingFraction: 0.82)
    /// Quick state changes (color, opacity)
    static let quick = Animation.easeOut(duration: 0.15)
    /// Tab/page transitions
    static let page = Animation.spring(response: 0.4, dampingFraction: 0.86)
    /// Subtle breathing/pulsing
    static let breathe = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    /// Numeric counter changes
    static let count = Animation.spring(response: 0.35, dampingFraction: 0.85)
}

// MARK: - Spacing (8pt grid)

enum Space {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let page: CGFloat = 28
}

// MARK: - Radius

enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let pill: CGFloat = 100
}

// MARK: - Type Scale

enum TypeScale {
    static let hero: Font = .system(size: 28, weight: .bold, design: .default)
    static let title: Font = .system(size: 22, weight: .bold)
    static let heading: Font = .system(size: 15, weight: .semibold)
    static let body: Font = .system(size: 13)
    static let caption: Font = .system(size: 11)
    static let tiny: Font = .system(size: 9.5, weight: .medium)
    static let mono: Font = .system(size: 28, weight: .bold, design: .monospaced)
    static let monoSm: Font = .system(size: 13, weight: .medium, design: .monospaced)
    static let sectionLabel: Font = .system(size: 11, weight: .semibold)
}

// MARK: - Colors

extension Color {
    /// Brand accent — used for primary actions and highlights
    static let accent = Color.drift

    /// Productive/focused state
    static let productive = Color("Green")

    /// Distraction/drift state
    static let distraction = Color("Red")

    /// Streak/energy
    static let streak = Color.orange

    /// Subtle card background — uses native material
    static let cardBg = Color(.controlBackgroundColor)

    /// Separator
    static let sep = Color(.separatorColor)
}

// MARK: - Section Label Style

struct SectionLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(TypeScale.sectionLabel)
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

extension View {
    func sectionLabel() -> some View {
        modifier(SectionLabel())
    }
}

// MARK: - Interactive Button Style (every button uses this)

struct DriftButtonStyle: ButtonStyle {
    enum Variant {
        case primary, secondary, ghost, danger
    }

    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(Anim.tap, value: configuration.isPressed)
    }
}

extension View {
    func driftButton(_ variant: DriftButtonStyle.Variant = .primary) -> some View {
        buttonStyle(DriftButtonStyle(variant: variant))
    }
}

// MARK: - Card Modifier (native material, not custom glass)

struct DriftCard: ViewModifier {
    var padding: CGFloat = Space.xl

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .strokeBorder(Color.sep.opacity(0.15), lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    func driftCard(padding: CGFloat = Space.xl) -> some View {
        modifier(DriftCard(padding: padding))
    }
}

// MARK: - Staggered Appear Modifier

struct StaggerAppear: ViewModifier {
    let index: Int
    let appeared: Bool

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(
                Anim.appear.delay(Double(index) * 0.04),
                value: appeared
            )
    }
}

extension View {
    func staggerAppear(index: Int, appeared: Bool) -> some View {
        modifier(StaggerAppear(index: index, appeared: appeared))
    }
}

// MARK: - Hover Lift (for interactive cards)

struct HoverLift: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.06 : 0.03),
                radius: isHovered ? 12 : 6,
                y: isHovered ? 4 : 2
            )
            .animation(Anim.quick, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

extension View {
    func hoverLift() -> some View {
        modifier(HoverLift())
    }
}
