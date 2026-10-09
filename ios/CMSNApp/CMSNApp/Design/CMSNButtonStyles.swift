import SwiftUI

/// Flat, tracked, full-width actions. One filled white button is the
/// strongest thing on a screen. Ghost is an outline in solid gray, not a
/// frosted fill. Pressed ghost and text labels drop to `textSecondary`,
/// which still clears AA on black. They do not fade to 40% white. The
/// primary button dims as a whole so its black label stays on white.

private struct CMSNButtonLabelStyle: ViewModifier {
    let textColor: Color
    func body(content: Content) -> some View {
        content
            .font(CMSNTypography.eyebrow())
            .kerning(2.4)
            .foregroundStyle(textColor)
            .padding(.vertical, CMSNSpacing.buttonVertical)
            .padding(.horizontal, CMSNSpacing.buttonHorizontal)
            .frame(maxWidth: .infinity)
    }
}

struct CMSNPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(textColor: CMSNColor.Semantic.buttonLabel))
            .background(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .fill(CMSNColor.Semantic.buttonFill)
            )
            // Whole-control dim only. Gray ink on the white face would miss AA.
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct CMSNGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(
                textColor: configuration.isPressed ? CMSNColor.Semantic.textSecondary : CMSNColor.Semantic.textPrimary
            ))
            .background(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .fill(configuration.isPressed ? CMSNSurfaceStyle.fillPressed : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .strokeBorder(CMSNColor.Semantic.borderStrong, lineWidth: CMSNSpacing.hairline)
            )
    }
}

/// Outline for a light surface. Unused by current screens; kept so a light
/// section can outline in black without inventing a new style later.
/// Label `#0A0A0A` on white clears AA.
struct CMSNGhostOnSurfaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(textColor: CMSNColor.Semantic.buttonLabel))
            .background(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .fill(configuration.isPressed ? CMSNColor.Semantic.buttonLabel.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .strokeBorder(CMSNColor.Semantic.buttonLabel.opacity(configuration.isPressed ? 1 : 0.35), lineWidth: CMSNSpacing.hairline)
            )
    }
}

struct CMSNTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CMSNTypography.eyebrow())
            .kerning(2.4)
            .foregroundStyle(configuration.isPressed ? CMSNColor.Semantic.textSecondary : CMSNColor.Semantic.textPrimary)
    }
}

extension ButtonStyle where Self == CMSNPrimaryButtonStyle {
    static var cmsnPrimary: CMSNPrimaryButtonStyle { CMSNPrimaryButtonStyle() }
}

extension ButtonStyle where Self == CMSNGhostButtonStyle {
    static var cmsnGhost: CMSNGhostButtonStyle { CMSNGhostButtonStyle() }
}

extension ButtonStyle where Self == CMSNGhostOnSurfaceButtonStyle {
    static var cmsnGhostOnSurface: CMSNGhostOnSurfaceButtonStyle { CMSNGhostOnSurfaceButtonStyle() }
}

extension ButtonStyle where Self == CMSNTextButtonStyle {
    static var cmsnText: CMSNTextButtonStyle { CMSNTextButtonStyle() }
}
