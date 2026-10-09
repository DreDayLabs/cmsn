import SwiftUI
import UIKit

/// Type for the shipped app.
///
/// Display stays on the bundled Bebas Neue (OFL, already in the target).
/// Everything else is the system face — no new font files. Sizes use text
/// styles, or `UIFontMetrics` for the numeric sizes callers pass in, so
/// Dynamic Type still scales them. At the default content size the metrics
/// match the designed points.
enum CMSNTypography {
    private static let displayFontName = "BebasNeue-Regular"

    /// Large campaign-style headline.
    static func display(_ size: CGFloat) -> Font {
        .custom(displayFontName, size: size, relativeTo: .largeTitle)
    }

    /// Section headers, score numbers, exercise-card titles.
    static func displaySmall(_ size: CGFloat = 28) -> Font {
        .custom(displayFontName, size: size, relativeTo: .title)
    }

    /// All-caps letter-spaced labels. Caption 2 is 11pt at the default size
    /// and scales with Dynamic Type.
    static func eyebrow() -> Font {
        .system(.caption2, design: .default, weight: .medium)
    }

    /// Standard body copy. The body text style is 17pt and scales.
    static func body() -> Font {
        .system(.body, design: .default, weight: .regular)
    }

    /// Quiet register for disclaimers and secondary sentences. Subheadline
    /// is 15pt light italic and scales.
    static func bodyQuiet() -> Font {
        .system(.subheadline, design: .default, weight: .light).italic()
    }

    /// Supporting metadata. Caption is 12pt and scales.
    static func caption() -> Font {
        .system(.caption, design: .default, weight: .regular)
    }

    /// Badges and dense chrome. Caption 2 (11pt), up from a fixed 8pt that
    /// could not stay legible under Dynamic Type.
    static func micro() -> Font {
        .system(.caption2, design: .default, weight: .medium)
    }

    /// Tabular figures for weights, reps, and scores. Scaled against a text
    /// style chosen from the designed size, so the default size is unchanged
    /// and a larger content-size category grows the number.
    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let style: UIFont.TextStyle
        switch size {
        case 28...: style = .largeTitle
        case 20..<28: style = .title2
        default: style = .body
        }
        let scaled = UIFontMetrics(forTextStyle: style).scaledValue(for: size)
        return .system(size: scaled, weight: weight, design: .default).monospacedDigit()
    }
}

/// Uppercase, tracked label. Tracking is the editorial move; color stays
/// a neutral, never an accent.
struct EyebrowLabel: View {
    let text: String
    var color: Color = CMSNColor.Semantic.textSecondary

    var body: some View {
        Text(text.uppercased())
            .font(CMSNTypography.eyebrow())
            .kerning(2.6)
            .foregroundStyle(color)
    }
}
