import SwiftUI

/// Typography system mirroring the marketing site: a condensed display face
/// for headlines (Bebas Neue there), quiet system sans for everything else.
///
/// NOTE for whoever opens this in Xcode: `Resources/Fonts/BebasNeue-Regular.ttf`
/// is NOT bundled by this build (binary font files can't be authored by an
/// agent that can only write text). Download the OFL-licensed family from
/// Google Fonts, drop the .ttf into `Resources/Fonts/`, and add it to
/// `UIAppFonts` in Info.plist — see `ios/CMSNApp/README.md`. Until then,
/// `Font.custom` falls back to the system font automatically, so the app
/// still builds and runs correctly, just without the condensed display look.
enum CMSNTypography {
    private static let displayFontName = "BebasNeue-Regular"

    /// Large campaign-style headline. "THE BODY IS THE CMSN." scale.
    static func display(_ size: CGFloat) -> Font {
        .custom(displayFontName, size: size, relativeTo: .largeTitle)
    }

    /// Section headers, score numbers, exercise-card titles.
    static func displaySmall(_ size: CGFloat = 28) -> Font {
        .custom(displayFontName, size: size, relativeTo: .title)
    }

    /// All-caps letter-spaced labels ("SHOP MEN", "TODAY'S FOCUS").
    static func eyebrow() -> Font {
        .system(size: 10, weight: .semibold, design: .default)
    }

    /// Standard body copy.
    static func body() -> Font {
        .system(size: 15, weight: .regular, design: .default)
    }

    /// Secondary/italic-register copy (the brand's quiet, hedged voice —
    /// used for supplement disclaimers, injury-safety language, etc.)
    static func bodyQuiet() -> Font {
        .system(size: 14, weight: .light, design: .default).italic()
    }

    /// Numeric-heavy displays (weight, reps, score) that need tabular figures
    /// so digits don't jitter as they update mid-set.
    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

/// The letter-spacing the site leans on constantly for uppercase labels.
/// SwiftUI has no native tracking modifier pre-iOS 26, so this is applied via
/// `.kerning`, which is the correct equivalent for fixed-width tracking.
struct EyebrowLabel: View {
    let text: String
    var color: Color = CMSNColor.Semantic.textSecondary

    var body: some View {
        Text(text.uppercased())
            .font(CMSNTypography.eyebrow())
            .kerning(1.8)
            .foregroundStyle(color)
    }
}
