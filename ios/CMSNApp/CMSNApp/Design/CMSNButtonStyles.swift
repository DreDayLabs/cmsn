import SwiftUI

/// Button styles mirroring the site's `.btn-white` / `.btn-ghost-white` /
/// `.btn-ghost-black` — uppercase, letter-spaced, flat faces, no soft
/// elevation. Shapes follow `CMSNSurfaceStyle` (near-sharp continuous corners).

private struct CMSNButtonLabelStyle: ViewModifier {
    let textColor: Color
    func body(content: Content) -> some View {
        content
            .font(CMSNTypography.eyebrow())
            .kerning(2.0)
            .foregroundStyle(textColor)
            .padding(.vertical, 16)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
    }
}

/// The filled, highest-emphasis action. Use once per screen.
/// Flat offWhite face — matches the site's `btn-white`, no drop shadow.
struct CMSNPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(textColor: CMSNColor.offBlack))
            .background(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .fill(CMSNColor.offWhite)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

/// Outline button on a dark surface.
struct CMSNGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(textColor: CMSNColor.offWhite))
            .background(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .fill(configuration.isPressed ? CMSNSurfaceStyle.fillPressed : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .strokeBorder(CMSNColor.offWhite.opacity(configuration.isPressed ? 0.7 : 0.25), lineWidth: 1)
            )
    }
}

/// Outline button on a light surface (warm-surface sections).
struct CMSNGhostOnSurfaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(CMSNButtonLabelStyle(textColor: CMSNColor.offBlack))
            .background(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .fill(CMSNColor.offBlack.opacity(configuration.isPressed ? 0.08 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .strokeBorder(CMSNColor.offBlack.opacity(configuration.isPressed ? 1 : 0.25), lineWidth: 1)
            )
    }
}

/// Low-emphasis text-only action (quick-path buttons on Today, "skip" links).
struct CMSNTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CMSNTypography.eyebrow())
            .kerning(2.0)
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
