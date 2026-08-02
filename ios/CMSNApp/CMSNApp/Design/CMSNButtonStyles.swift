import SwiftUI

/// Button styles mirroring the site's `.btn-white` / `.btn-ghost-white` /
/// `.btn-ghost-black` — uppercase, letter-spaced, no rounded pill shapes,
/// no color beyond the five-color palette.

private struct CMSNButtonLabelStyle: ViewModifier {
    let textColor: Color
    func body(content: Content) -> some View {
        content
            .font(CMSNTypography.eyebrow())
            .kerning(1.6)
            .foregroundStyle(textColor)
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
    }
}

/// The filled, highest-emphasis action. Use once per screen.
struct CMSNPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(textColor: CMSNColor.offBlack))
            .background(CMSNColor.offWhite)
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

/// Outline button on a dark surface.
struct CMSNGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(textColor: CMSNColor.offWhite))
            .overlay(
                Rectangle()
                    .strokeBorder(CMSNColor.offWhite.opacity(configuration.isPressed ? 0.7 : 0.25), lineWidth: 1)
            )
    }
}

/// Outline button on a light surface (warm-surface sections).
struct CMSNGhostOnSurfaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(textColor: CMSNColor.offBlack))
            .overlay(
                Rectangle()
                    .strokeBorder(CMSNColor.offBlack.opacity(configuration.isPressed ? 1 : 0.25), lineWidth: 1)
            )
    }
}

/// Low-emphasis text-only action (quick-path buttons on Today, "skip" links).
struct CMSNTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CMSNTypography.eyebrow())
            .kerning(1.6)
            .foregroundStyle(CMSNColor.offWhite.opacity(configuration.isPressed ? 0.4 : 1))
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
