import CoreGraphics

/// Spacing scale. Shared chrome (buttons, and anything new) reads from
/// here. Feature screens keep their own padding so token work does not
/// rewrite layout that other branches are editing.
enum CMSNSpacing {
    static let hairline: CGFloat = 1
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let buttonVertical: CGFloat = 18
    static let buttonHorizontal: CGFloat = 28
}
