import SwiftUI

/// The soft card language: continuous-corner radius, a barely-raised fill,
/// a hairline edge, and a low shadow. Replaces the V0 sharp `Rectangle()`
/// outlines, which read as wireframe boxes rather than product surfaces.
///
/// Discipline still applies — no new colors. Elevation comes from opacity
/// steps on the existing palette plus shadow, never from a new gray.
enum CMSNSurfaceStyle {
    /// One radius everywhere so cards, chips, and buttons agree.
    static let cornerRadius: CGFloat = 14
    /// Slightly tighter radius for small controls (chips, badges).
    static let chipCornerRadius: CGFloat = 10

    static let fill = CMSNColor.offWhite.opacity(0.05)
    static let fillPressed = CMSNColor.offWhite.opacity(0.1)
    static let edge = CMSNColor.offWhite.opacity(0.08)
    static let edgeSelected = CMSNColor.offWhite
}

/// A raised card surface. Apply after the content's own padding:
/// `VStack { ... }.padding(20).cmsnCard()`.
private struct CMSNCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .fill(CMSNSurfaceStyle.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .strokeBorder(CMSNSurfaceStyle.edge, lineWidth: 1)
            )
            .shadow(color: CMSNColor.black.opacity(0.35), radius: 12, y: 6)
    }
}

/// A selectable chip surface (goals, equipment options). Selected chips
/// invert to the filled offWhite face, matching the primary button.
private struct CMSNChipModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.chipCornerRadius, style: .continuous)
                    .fill(isSelected ? CMSNColor.offWhite : CMSNSurfaceStyle.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.chipCornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? CMSNSurfaceStyle.edgeSelected : CMSNSurfaceStyle.edge, lineWidth: 1)
            )
    }
}

extension View {
    func cmsnCard() -> some View { modifier(CMSNCardModifier()) }
    func cmsnChip(isSelected: Bool) -> some View { modifier(CMSNChipModifier(isSelected: isSelected)) }
}
