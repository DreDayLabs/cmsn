import SwiftUI
import UIKit

/// Type for the shipped app.
///
/// Bebas Neue is the display face for large headings only. Body copy,
/// labels, buttons, and numbers use the system sans (SF Pro on device) at
/// a weight that stays legible. Nothing here adds letter-spacing: tracking
/// on small labels was spreading "Swap" and "Show setup & cues" apart.
/// Sizes use text styles, or `UIFontMetrics` for the numeric sizes callers
/// pass in, so Dynamic Type still scales them. At the default content size
/// the metrics match the designed points.
enum CMSNTypography {
    private static let displayFontName = "BebasNeue-Regular"

    /// Large campaign-style headline. Display face only.
    static func display(_ size: CGFloat) -> Font {
        .custom(displayFontName, size: size, relativeTo: .largeTitle)
    }

    /// Section headers and exercise-card titles. Display face only.
    static func displaySmall(_ size: CGFloat = 28) -> Font {
        .custom(displayFontName, size: size, relativeTo: .title)
    }

    /// Short section kicker. Caption is 12pt semibold and scales. Callers
    /// that want capitals use `EyebrowLabel`; this face is not tracked.
    static func eyebrow() -> Font {
        .system(.caption, design: .default, weight: .semibold)
    }

    /// Standard body copy. The body text style is 17pt and scales.
    static func body() -> Font {
        .system(.body, design: .default, weight: .regular)
    }

    /// Secondary sentences and hints. Subheadline is 15pt regular — not
    /// light, and not italic — and scales.
    static func bodyQuiet() -> Font {
        .system(.subheadline, design: .default, weight: .regular)
    }

    /// Control labels ("Reps", "Weight", "Set 1"). Caption semibold.
    static func label() -> Font {
        .system(.caption, design: .default, weight: .semibold)
    }

    /// Button titles. Subheadline semibold, system face, no tracking.
    static func button() -> Font {
        .system(.subheadline, design: .default, weight: .semibold)
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

/// Uppercase section kicker. Capitals only — no extra letter-spacing.
/// Color stays a neutral, never an accent.
struct EyebrowLabel: View {
    let text: String
    var color: Color = CMSNColor.Semantic.textSecondary

    var body: some View {
        Text(text.uppercased())
            .font(CMSNTypography.eyebrow())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(color)
    }
}
