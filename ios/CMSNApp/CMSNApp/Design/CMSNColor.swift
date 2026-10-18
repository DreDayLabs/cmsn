import SwiftUI
import UIKit

/// 8-bit sRGB. Every `Color` in `CMSNColor` is built from these values, and
/// `CMSNContrastTests` measures the same numbers, so the test cannot drift
/// from what the screens paint.
struct CMSNRGB: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    var uiColor: UIColor {
        UIColor(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }

    var color: Color { Color(uiColor: uiColor) }
}

/// WCAG 2.x relative-luminance contrast. 4.5 is the AA floor for normal text.
enum CMSNContrast {
    static let normalTextAA = 4.5

    static func ratio(foreground: CMSNRGB, on background: CMSNRGB) -> Double {
        let lighter = max(luminance(foreground), luminance(background))
        let darker = min(luminance(foreground), luminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ rgb: CMSNRGB) -> Double {
        func linear(_ channel: UInt8) -> Double {
            let value = Double(channel) / 255
            if value <= 0.04045 { return value / 12.92 }
            return pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }
}

/// Monochrome palette.
///
/// Dark is what the app ships (`preferredColorScheme(.dark)`). The light
/// values are a specified, contrast-checked alternate — they are not installed
/// as live colors, because `offBlack` / `offWhite` are used as both ink and
/// paper and a naive adaptive swap would wash the primary button out. Screens
/// stay on the dark set until a real light theme retargets those roles.
///
/// Retired from the UI, and not present as live values:
/// - Navy `#0B1526`. The only chromatic token. It was `Semantic.accent` and
///   nearly invisible on off-black (about 1.08:1). Garment navy stays a fabric
///   color, not a screen color. No accent hue replaces it.
/// - Warm surface `#F5F3F0`. A beige cast. Light surfaces, if they ship, are
///   neutral `#F5F5F5` / white.
/// - Off-white `#FAFAF8`. A warm cast on primary type. Primary type is now
///   pure white.
/// - Lifted background `#0A0A0A` and primary ink `#F4F4F4`. They cleared AA
///   but read dull. Screens are true black with pure white primary ink.
///   `#0A0A0A` remains only as `scrim`, for photo and video overlays whose
///   opacities were tuned against that value.
/// - `textSecondary` as off-white at 40% opacity (about 3.66:1). Then solid
///   `#8A8A8A` (about 5.7:1), which cleared AA and still read gray-on-black.
///   Secondary type is now `#C8C8C8` (12.55:1 on black, 11.20:1 on surface).
/// - `textSecondaryOnSurface` as off-black at 35% on the warm beige. About
///   2.32:1. Secondary type on a surface is the same solid gray.
enum CMSNPalette {
    /// Shipped dark experience. Primary ink is pure white on true black.
    static let black = CMSNRGB(red: 0x00, green: 0x00, blue: 0x00)
    static let background = CMSNRGB(red: 0x00, green: 0x00, blue: 0x00)
    static let surface = CMSNRGB(red: 0x12, green: 0x12, blue: 0x12)
    static let surfacePressed = CMSNRGB(red: 0x1C, green: 0x1C, blue: 0x1C)
    static let textPrimary = CMSNRGB(red: 0xFF, green: 0xFF, blue: 0xFF)
    /// Secondary ink. 12.55:1 on black, 11.20:1 on surface, 10.19:1 on pressed.
    static let textSecondary = CMSNRGB(red: 0xC8, green: 0xC8, blue: 0xC8)
    static let white = CMSNRGB(red: 0xFF, green: 0xFF, blue: 0xFF)
    static let border = CMSNRGB(red: 0x3A, green: 0x3A, blue: 0x3A)
    /// Outlines for secondary actions. White, so a ghost button is not a
    /// gray stroke on a gray card.
    static let borderStrong = CMSNRGB(red: 0xFF, green: 0xFF, blue: 0xFF)
    /// Photo and video scrim. Not used for type or screen backgrounds.
    static let scrim = CMSNRGB(red: 0x0A, green: 0x0A, blue: 0x0A)

    /// Specified light mode. Contrast-tested. Not installed — see the enum note.
    static let lightBackground = CMSNRGB(red: 0xF5, green: 0xF5, blue: 0xF5)
    static let lightSurface = CMSNRGB(red: 0xFF, green: 0xFF, blue: 0xFF)
    static let lightTextPrimary = CMSNRGB(red: 0x11, green: 0x11, blue: 0x11)
    static let lightTextSecondary = CMSNRGB(red: 0x5C, green: 0x5C, blue: 0x5C)
    static let lightBorder = CMSNRGB(red: 0xD9, green: 0xD9, blue: 0xD9)
    static let lightButtonFill = CMSNRGB(red: 0x11, green: 0x11, blue: 0x11)
    static let lightButtonLabel = CMSNRGB(red: 0xF5, green: 0xF5, blue: 0xF5)
}

/// Live colors for the shipped dark UI. Features should prefer `Semantic`.
enum CMSNColor {
    static let black = CMSNPalette.black.color
    /// Screen background. True black. The name is historical.
    static let offBlack = CMSNPalette.background.color
    /// Overlay for the welcome video and narrative photos. Separate from the
    /// screen background so those opacities keep the composite they were
    /// tuned for.
    static let scrim = CMSNPalette.scrim.color
    static let offWhite = CMSNPalette.textPrimary.color
    /// Primary button face. Not a tint — the brightest neutral.
    static let white = CMSNPalette.white.color
    static let gray = CMSNPalette.textSecondary.color

    enum Semantic {
        static let background = CMSNColor.offBlack
        static let surface = CMSNPalette.surface.color
        static let surfacePressed = CMSNPalette.surfacePressed.color
        static let textPrimary = CMSNColor.offWhite
        /// Cards are elevated black, so type on them is the same light ink.
        static let textOnSurface = CMSNColor.offWhite
        static let textSecondary = CMSNColor.gray
        static let textSecondaryOnSurface = CMSNColor.gray
        static let divider = CMSNPalette.border.color
        static let border = CMSNPalette.border.color
        static let borderStrong = CMSNPalette.borderStrong.color
        /// No chromatic accent. Hierarchy is weight, size, and gray.
        static let accent = CMSNColor.offWhite
        static let scorePositive = CMSNColor.offWhite
        static let scoreCaution = CMSNColor.gray
        /// Destructive rows stay gray on purpose. A red would be a second hue.
        static let destructive = CMSNColor.gray
        static let control = CMSNColor.offWhite
        static let buttonFill = CMSNColor.white
        static let buttonLabel = CMSNColor.offBlack
    }
}

/// Opacity that still clears AA when `#F4F4F4` is drawn on `#0A0A0A`.
/// Used for an unselected option, not for body copy.
enum CMSNEmphasis {
    static let unselected = 0.72
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
