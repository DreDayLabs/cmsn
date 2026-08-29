import SwiftUI

/// Editorial surface language aligned with the marketing site and
/// `brand/02-identity-and-logo.md`: near-sharp corners, hairline edges,
/// no soft elevation shadows. Soft rounded "fitness-app cards" undercut the
/// machined / boardroom-clean positioning.
///
/// Discipline still applies — no new colors. Depth comes from opacity steps
/// on the existing palette, never from a new gray or a multi-layer shadow.
enum CMSNSurfaceStyle {
    /// Near-sharp continuous radius — reads engineered, not bubbly.
    /// Matches the site's rectangular chrome more closely than a 14pt soft card.
    static let cornerRadius: CGFloat = 4
    /// Slightly tighter radius for small controls (chips, badges).
    static let chipCornerRadius: CGFloat = 2

    static let fill = CMSNColor.offWhite.opacity(0.045)
    static let fillPressed = CMSNColor.offWhite.opacity(0.09)
    static let edge = CMSNColor.offWhite.opacity(0.1)
    static let edgeSelected = CMSNColor.offWhite
}

/// A flat editorial surface. Apply after the content's own padding:
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
    }
}

/// A selectable chip surface (goals, equipment options). Selected chips
/// invert to the filled offWhite face, matching the primary button.
/// Uses the near-sharp chip radius — never a Capsule / rounded-full pill.
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
