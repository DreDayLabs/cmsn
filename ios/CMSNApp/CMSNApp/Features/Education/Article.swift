import Foundation

/// A bundled education article. Stable `id` slugs are the deep-link
/// contract — `fuel-after-training` is the id a training-day explanation
/// can open later. This is static content, not a SwiftData model.
struct Article: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    /// One line. No embedded newlines.
    let summary: String
    let category: ArticleCategory
    let sections: [ArticleSection]
    let citations: [ArticleCitation]
    let relatedIDs: [String]

    /// Words a reader actually sees, excluding the separate medical-advice
    /// note and the reading-time label.
    var countableText: String {
        ([summary] + sections.flatMap { [$0.heading, $0.body] }).joined(separator: " ")
    }

    var readingTimeMinutes: Int {
        ReadingTimeEstimate.minutes(for: countableText)
    }
}

enum ArticleCategory: String, CaseIterable, Identifiable, Hashable {
    case fuel = "Fuel"
    case training = "Training"
    case recovery = "Recovery"
    case supplements = "Supplements"

    var id: String { rawValue }
}

struct ArticleSection: Identifiable, Equatable, Hashable {
    let id: String
    let heading: String
    let body: String
}

struct ArticleCitation: Identifiable, Equatable, Hashable {
    let title: String
    let authorsOrOrg: String
    let year: Int
    let url: URL

    var id: String { "\(year)|\(title)|\(url.absoluteString)" }
}

/// Where the library can send a reader. The supplement-notes case is the
/// existing supplement library, still reachable from the Supplements category.
enum LibraryDestination: Hashable {
    case category(ArticleCategory)
    case article(String)
    case supplementNotes
}

/// Reading time for bundled articles.
///
/// PLACEHOLDER: 200 words per minute. TODO: replace with a cited adult
/// reading rate. None of the approved nutrition sources report one, so the
/// label the reader sees is marked PLACEHOLDER and carries this TODO.
enum ReadingTimeEstimate {
    static let placeholderWordsPerMinute = 200

    static let todoNote = "TODO: reading time uses an uncited 200-words-per-minute rate."

    static func wordCount(in text: String) -> Int {
        text.split { $0.isWhitespace }.count
    }

    static func minutes(for text: String) -> Int {
        let words = wordCount(in: text)
        guard words > 0 else { return 0 }
        let minutes = Double(words) / Double(placeholderWordsPerMinute)
        return Int(minutes.rounded(.up))
    }

    static func label(minutes: Int) -> String {
        "PLACEHOLDER · \(minutes) min"
    }

    static func label(for article: Article) -> String {
        label(minutes: article.readingTimeMinutes)
    }
}

/// Visible source rows for the reader. Kept beside the view so the
/// Sources section cannot drift from the citation list.
enum ArticleReaderContent {
    static let sourcesHeading = "Sources"

    static func sourceLines(for article: Article) -> [ArticleSourceLine] {
        article.citations.map { citation in
            ArticleSourceLine(
                title: citation.title,
                detail: "\(citation.authorsOrOrg), \(citation.year)",
                url: citation.url
            )
        }
    }
}

struct ArticleSourceLine: Equatable, Identifiable {
    let title: String
    let detail: String
    let url: URL

    var id: String { url.absoluteString + title }
}

/// Decimal strings for figures that are either cited or computed from
/// cited inputs. Locale-stable so a test and the article prose match.
enum CitedNumberFormat {
    static func string(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

/// Worked Compendium example used inside `estimating-workout-calories`.
///
/// Code 02054 is 3.5 MET (2024 Adult Compendium, Herrmann et al.,
/// J Sport Health Sci 2024; conditioning-exercise table).
/// 1 MET ≈ 1 kcal/kg/h (Herrmann et al. 2024).
/// NET MET = MET − 1 so the resting energy inside 1 MET is not counted twice.
/// 80 kg and 45 minutes are example inputs, not a measured athlete.
/// (3.5 − 1) × 80 × (45 / 60) = 150 kcal above rest.
enum CompendiumEnergyExample {
    static let code = "02054"
    static let met = 3.5
    static let exampleBodyweightKG = 80.0
    static let exampleMinutes = 45.0

    static var netMET: Double { met - 1 }
    static var exampleHours: Double { exampleMinutes / 60 }
    static var exampleKcalAboveRest: Double { netMET * exampleBodyweightKG * exampleHours }
}
