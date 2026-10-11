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

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tab
        tabBar.scrollEdgeAppearance = tab
        tabBar.isTranslucent = false
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
}
