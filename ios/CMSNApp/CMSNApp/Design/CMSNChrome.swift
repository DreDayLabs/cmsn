import UIKit

/// Opaque black chrome for the tab bar and navigation bar. The system
/// material blur read as glass; these appearances are flat `#000000`.
/// Called once from `RootView` before the tabs exist, so it does not
/// have to edit `MainTabView`.
enum CMSNChrome {
    static func apply() {
        let background = CMSNPalette.background.uiColor
        let primary = CMSNPalette.textPrimary.uiColor
        let secondary = CMSNPalette.textSecondary.uiColor
        let tabFont = UIFont.systemFont(ofSize: 10, weight: .medium)

        let item = UITabBarItemAppearance()
        item.normal.iconColor = secondary
        item.normal.titleTextAttributes = [
            .foregroundColor: secondary,
            .font: tabFont,
            .kern: 0,
        ]
        item.selected.iconColor = primary
        item.selected.titleTextAttributes = [
            .foregroundColor: primary,
            .font: tabFont,
            .kern: 0,
        ]

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = background
        tab.shadowColor = background
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        tab.backgroundEffect = nil
        // A stretched opaque image keeps the fill at true black. With the
        // bar translucent for layout, a color alone was compositing up to
        // about #1C1C1C.
        tab.backgroundImage = Self.opaqueBlackImage()

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tab
        tabBar.scrollEdgeAppearance = tab
        // Stay translucent for layout only. An opaque bar already ends the
        // page above itself; `isTranslucent = false` makes SwiftUI inset by
        // that height a second time, which leaves a black band and clips the
        // last card. The appearance above is an opaque black fill, so the
        // bar does not go back to a material blur.
        tabBar.isTranslucent = true
        tabBar.tintColor = primary
        tabBar.unselectedItemTintColor = secondary

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = background
        nav.shadowColor = background
        nav.titleTextAttributes = [
            .foregroundColor: primary,
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
        ]
        nav.largeTitleTextAttributes = [.foregroundColor: primary]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = nav
        navigationBar.scrollEdgeAppearance = nav
        navigationBar.compactAppearance = nav
        navigationBar.tintColor = primary
        navigationBar.isTranslucent = false
    }

    /// 2×2 opaque black, stretched by the bar. Any translucent pixel would
    /// turn the material back on.
    private static func opaqueBlackImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
}
