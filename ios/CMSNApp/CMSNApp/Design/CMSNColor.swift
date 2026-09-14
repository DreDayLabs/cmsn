import SwiftUI

/// The CMSN palette, locked in `brand/02-identity-and-logo.md`.
///
/// Discipline from the brand doc applies here too: these five colors are the
/// whole palette. No new colors get added to satisfy a UI edge case — reach
/// for opacity/weight variation on these instead.
enum CMSNColor {
    /// True black. Reserved for the rare full-bleed statement moment (matches
    /// the marketing site's "earned in the dark" section) — not the default
    /// app background, which is `offBlack`.
    static let black = Color(hex: 0x000000)

    /// The app's actual background color almost everywhere. Garment-dye
    /// reality per the brand doc: pure black is rare, this off-black reads
    /// as premium rather than flat.
    static let offBlack = Color(hex: 0x0A0A0A)

    /// Primary text/foreground on dark surfaces, and the wordmark's "light"
    /// variant color.
    static let offWhite = Color(hex: 0xFAFAF8)

    /// True white. Used sparingly for the highest-contrast surfaces (e.g. a
    /// filled primary button face), mirroring the site's `btn-white`.
    static let white = Color(hex: 0xFFFFFF)

    /// Warm off-white used for light-surface sections (shop/product areas on
    /// the site) — never pure white, per brand discipline.
    static let warmSurface = Color(hex: 0xF5F3F0)

    /// Navy accent. Used only as accent, never as a wash — per brand rule,
    /// navy garments take the white mark, not the reverse.
    static let navy = Color(hex: 0x0B1526)

    /// The single gray in the system. Used for secondary text and dividers.
    static let gray = Color(hex: 0x8A8A8A)

    /// Semantic aliases so features don't hardcode black/white and can react
    /// to a future light-mode pass without a palette rewrite.
    enum Semantic {
        static let background = CMSNColor.offBlack
        static let surface = CMSNColor.warmSurface
        static let textPrimary = CMSNColor.offWhite
        static let textOnSurface = CMSNColor.offBlack
        static let textSecondary = CMSNColor.offWhite.opacity(0.4)
        static let textSecondaryOnSurface = CMSNColor.offBlack.opacity(0.35)
        static let divider = CMSNColor.offWhite.opacity(0.1)
        static let accent = CMSNColor.navy

        /// Discipline scoring reads as "quiet, earned" — reuse gray, never a
        /// new success-green. Positive deltas get a subtle offWhite emphasis
        /// instead of a traffic-light color system.
        static let scorePositive = CMSNColor.offWhite
        static let scoreCaution = CMSNColor.gray
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
