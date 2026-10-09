import SwiftUI

/// Flat editorial surfaces. Depth is a solid step from background to
/// `#121212`, plus a 1pt solid hairline. No translucent wash and no shadow.
enum CMSNSurfaceStyle {
    /// Near-square. Continuous, but tight enough to read as cut, not pillowed.
    static let cornerRadius: CGFloat = 2
    /// Chips are square.
    static let chipCornerRadius: CGFloat = 0

    static let fill = CMSNColor.Semantic.surface
    static let fillPressed = CMSNColor.Semantic.surfacePressed
    static let edge = CMSNColor.Semantic.border
    static let edgeSelected = CMSNColor.Semantic.textPrimary
}

private struct CMSNCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .fill(CMSNSurfaceStyle.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .strokeBorder(CMSNSurfaceStyle.edge, lineWidth: CMSNSpacing.hairline)
            )
    }
}

/// Selected chips invert to the off-white face. Unselected chips use the
/// same solid surface as a card. Never a capsule.
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
                    .strokeBorder(isSelected ? CMSNSurfaceStyle.edgeSelected : CMSNSurfaceStyle.edge, lineWidth: CMSNSpacing.hairline)
            )
    }
}

extension View {
    func cmsnCard() -> some View { modifier(CMSNCardModifier()) }
    func cmsnChip(isSelected: Bool) -> some View { modifier(CMSNChipModifier(isSelected: isSelected)) }
}
