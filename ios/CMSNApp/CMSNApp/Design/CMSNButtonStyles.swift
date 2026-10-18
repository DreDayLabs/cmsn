import SwiftUI

/// Pill actions in the system face. One filled white button is the strongest
/// thing on a screen. Ghost is a `#111` pill, not an outlined box. The
/// primary button dims as a whole so its black label stays on white.
/// Titles stay on one line at every content size.

private struct CMSNButtonLabelStyle: ViewModifier {
    let textColor: Color
    func body(content: Content) -> some View {
        content
            .font(CMSNTypography.button())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(textColor)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
    }
}

struct CMSNPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(textColor: CMSNColor.Semantic.buttonLabel))
            .background(Capsule().fill(CMSNColor.Semantic.buttonFill))
            // Whole-control dim only. Gray ink on the white face would miss AA.
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct CMSNGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(textColor: CMSNColor.Semantic.textPrimary))
            .background(
                Capsule().fill(configuration.isPressed ? CMSNSurfaceStyle.fillPressed : CMSNSurfaceStyle.fill)
            )
    }
}

/// White Log pill that sizes to its label. The full-width primary would
/// swallow the reps and weight fields. `fixedSize` keeps it from squeezing
/// the neighboring target into a column.
struct CMSNCompactPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CMSNTypography.button())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(CMSNColor.Semantic.buttonLabel)
            .padding(.vertical, 12)
            .padding(.horizontal, 22)
            .background(Capsule().fill(CMSNColor.Semantic.buttonFill))
            .opacity(configuration.isPressed ? 0.92 : 1)
            .fixedSize(horizontal: true, vertical: true)
    }
}

/// Later sets stay tappable without competing with the active set's Log.
struct CMSNCompactQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CMSNTypography.button())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(CMSNColor.Semantic.textPrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 22)
            .background(Capsule().fill(CMSNColor.Semantic.border))
            .opacity(configuration.isPressed ? 0.92 : 1)
            .fixedSize(horizontal: true, vertical: true)
    }
}

/// Outline for a light surface. Unused by current screens; kept so a light
/// section can outline in black without inventing a new style later.
/// Label is black on white, which clears AA.
struct CMSNGhostOnSurfaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(textColor: CMSNColor.Semantic.buttonLabel))
            .background(
                Capsule().fill(configuration.isPressed ? CMSNColor.Semantic.buttonLabel.opacity(0.06) : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(CMSNColor.Semantic.buttonLabel.opacity(configuration.isPressed ? 1 : 0.35), lineWidth: CMSNSpacing.hairline)
            )
    }
}

struct CMSNTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CMSNTypography.button())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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

extension ButtonStyle where Self == CMSNCompactPrimaryButtonStyle {
    static var cmsnCompactPrimary: CMSNCompactPrimaryButtonStyle { CMSNCompactPrimaryButtonStyle() }
}

extension ButtonStyle where Self == CMSNCompactQuietButtonStyle {
    static var cmsnCompactQuiet: CMSNCompactQuietButtonStyle { CMSNCompactQuietButtonStyle() }
}
