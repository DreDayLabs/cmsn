import XCTest
@testable import CMSNApp

final class EducationLibraryTests: XCTestCase {
    private let requiredIDs = [
        "fuel-after-training",
        "how-much-protein",
        "estimating-workout-calories",
        "carbs-and-training-load",
        "rest-days-and-recovery"
    ]

    func testArticleIDsAreUnique() {
        let ids = EducationLibrary.articles.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertFalse(ids.isEmpty)
    }

    func testSeedArticleCountStaysInsideTheRequestedRange() {
        XCTAssertGreaterThanOrEqual(EducationLibrary.articles.count, 4)
        XCTAssertLessThanOrEqual(EducationLibrary.articles.count, 6)
    }

    func testRequiredSeedArticlesExist() {
        for id in requiredIDs {
            XCTAssertNotNil(EducationLibrary.article(id: id), id)
        }
        XCTAssertEqual(EducationLibrary.fuelAfterTrainingID, "fuel-after-training")
    }

    func testEveryArticleHasAtLeastOneHTTPSCitation() {
        for article in EducationLibrary.articles {
            XCTAssertFalse(article.citations.isEmpty, article.id)
            for citation in article.citations {
                XCTAssertFalse(citation.title.isEmpty, article.id)
                XCTAssertFalse(citation.authorsOrOrg.isEmpty, article.id)
                XCTAssertGreaterThan(citation.year, 1900, article.id)
                XCTAssertEqual(citation.url.scheme?.lowercased(), "https", article.id)
                XCTAssertNotNil(citation.url.host, article.id)
                XCTAssertFalse(citation.url.host?.isEmpty ?? true, article.id)
            }
        }
    }

    func testRelatedIDsResolveAndAreNotSelfLinks() {
        for article in EducationLibrary.articles {
            XCTAssertEqual(
                EducationLibrary.relatedArticles(for: article).count,
                article.relatedIDs.count,
                article.id
            )
            for relatedID in article.relatedIDs {
                XCTAssertNotEqual(relatedID, article.id, article.id)
                let resolved = EducationLibrary.article(id: relatedID)
                XCTAssertNotNil(resolved, "\(article.id) -> \(relatedID)")
            }
            XCTAssertEqual(Set(article.relatedIDs).count, article.relatedIDs.count, article.id)
        }
    }

    func testEveryCategoryIsNonEmpty() {
        for category in ArticleCategory.allCases {
            XCTAssertFalse(EducationLibrary.articles(in: category).isEmpty, category.rawValue)
        }
    }

    func testDeepLinkLookupFindsFuelAfterTrainingAndRejectsUnknownIDs() {
        let article = EducationLibrary.article(id: "fuel-after-training")
        XCTAssertEqual(article?.id, EducationLibrary.fuelAfterTrainingID)
        XCTAssertEqual(article?.category, .fuel)
        XCTAssertNil(EducationLibrary.article(id: "not-a-real-article"))
        XCTAssertNil(EducationLibrary.article(id: "Fuel-After-Training"))

        XCTAssertEqual(
            EducationLibrary.destination(openingArticleID: "fuel-after-training"),
            .article("fuel-after-training")
        )
        XCTAssertNil(EducationLibrary.destination(openingArticleID: nil))
        XCTAssertNil(EducationLibrary.destination(openingArticleID: "missing"))
    }

    func testSummariesAreSingleLinesAndSectionsArePopulated() {
        for article in EducationLibrary.articles {
            XCTAssertFalse(article.summary.isEmpty, article.id)
            XCTAssertNil(article.summary.firstIndex(of: "\n"), article.id)
            XCTAssertFalse(article.sections.isEmpty, article.id)
            for section in article.sections {
                XCTAssertFalse(section.heading.isEmpty, article.id)
                XCTAssertFalse(section.body.isEmpty, article.id)
            }
        }
    }

    func testReadingTimeMatchesThePlaceholderRate() {
        let twoHundred = Array(repeating: "word", count: 200).joined(separator: " ")
        XCTAssertEqual(ReadingTimeEstimate.wordCount(in: twoHundred), 200)
        XCTAssertEqual(ReadingTimeEstimate.minutes(for: twoHundred), 1)
        XCTAssertEqual(ReadingTimeEstimate.minutes(for: twoHundred + " extra"), 2)
        XCTAssertEqual(ReadingTimeEstimate.minutes(for: "   "), 0)
        XCTAssertEqual(ReadingTimeEstimate.wordCount(in: "one  two\nthree"), 3)

        for article in EducationLibrary.articles {
            let minutes = ReadingTimeEstimate.minutes(for: article.countableText)
            XCTAssertEqual(article.readingTimeMinutes, minutes, article.id)
            XCTAssertGreaterThan(minutes, 0, article.id)
            let label = ReadingTimeEstimate.label(for: article)
            XCTAssertTrue(label.contains("PLACEHOLDER"), article.id)
            XCTAssertTrue(label.contains("\(minutes)"), article.id)
        }
        XCTAssertTrue(ReadingTimeEstimate.todoNote.contains("TODO"))
        XCTAssertTrue(ReadingTimeEstimate.todoNote.contains("200"))
    }

    func testSourceLinesMatchCitations() {
        for article in EducationLibrary.articles {
            let lines = ArticleReaderContent.sourceLines(for: article)
            XCTAssertEqual(lines.count, article.citations.count, article.id)
            XCTAssertEqual(ArticleReaderContent.sourcesHeading, "Sources")
            for (line, citation) in zip(lines, article.citations) {
                XCTAssertEqual(line.title, citation.title)
                XCTAssertEqual(line.url, citation.url)
                XCTAssertTrue(line.detail.contains(citation.authorsOrOrg))
                XCTAssertTrue(line.detail.contains("\(citation.year)"))
            }
        }
    }

    func testNotMedicalAdviceNoteNamesARegisteredDietitian() {
        let note = EducationLibrary.notMedicalAdviceNote.lowercased()
        XCTAssertTrue(note.contains("not medical advice"))
        XCTAssertTrue(note.contains("registered dietitian"))
        XCTAssertTrue(note.contains("2016"))
    }

    func testFuelAfterTrainingCitesACSMAndISSN() {
        let article = EducationLibrary.article(id: "fuel-after-training")
        let hosts = Set(article?.citations.compactMap(\.url.host) ?? [])
        XCTAssertTrue(hosts.contains("pubmed.ncbi.nlm.nih.gov"))
        XCTAssertTrue(hosts.contains("jissn.biomedcentral.com"))
        let prose = article?.countableText ?? ""
        XCTAssertTrue(prose.contains("1 to 1.2"))
        XCTAssertTrue(prose.contains("0.25 to 0.3"))
        XCTAssertTrue(prose.contains("20 to 40"))
        XCTAssertTrue(prose.contains("2016"))
        XCTAssertTrue(prose.contains("2017"))
    }

    func testCompendiumExampleIsTheCitedArithmetic() {
        XCTAssertEqual(CompendiumEnergyExample.met, 3.5)
        XCTAssertEqual(CompendiumEnergyExample.netMET, 2.5)
        XCTAssertEqual(CompendiumEnergyExample.exampleHours, 0.75)
        XCTAssertEqual(CompendiumEnergyExample.exampleKcalAboveRest, 150)
        XCTAssertEqual(CitedNumberFormat.string(3.5), "3.5")
        XCTAssertEqual(CitedNumberFormat.string(150), "150")
        XCTAssertEqual(CitedNumberFormat.string(0.75), "0.75")

        let article = EducationLibrary.article(id: "estimating-workout-calories")
        let prose = article?.countableText ?? ""
        XCTAssertTrue(prose.contains("150"))
        XCTAssertTrue(prose.contains("3.5"))
        XCTAssertTrue(prose.contains("02054"))
        XCTAssertTrue(prose.contains("9.8"))
        XCTAssertTrue(prose.contains("8 to 15%"))
        XCTAssertTrue(prose.contains("1114"))
        XCTAssertTrue(prose.contains("912 have a measured"))
        XCTAssertTrue(prose.contains("202 are estimated"))
        XCTAssertTrue(prose.contains("19 to 59"))
        XCTAssertTrue(prose.contains("example inputs"))
    }

    func testCitedRangesStayInTheArticlesThatUseThem() {
        let protein = EducationLibrary.article(id: "how-much-protein")?.countableText ?? ""
        XCTAssertTrue(protein.contains("1.4 to 2.0"))
        XCTAssertTrue(protein.contains("1.2 to 2.0"))
        XCTAssertTrue(protein.contains("2.3 to 3.1"))
        XCTAssertTrue(protein.contains("3.0"))
        XCTAssertTrue(protein.contains("10 to 35%"))

        let carbs = EducationLibrary.article(id: "carbs-and-training-load")?.countableText ?? ""
        XCTAssertTrue(carbs.contains("3 to 5"))
        XCTAssertTrue(carbs.contains("5 to 7"))
        XCTAssertTrue(carbs.contains("6 to 10"))
        XCTAssertTrue(carbs.contains("8 to 12"))
        XCTAssertTrue(carbs.contains("20 to 35%"))
        XCTAssertTrue(carbs.contains("45 to 65%"))

        let rest = EducationLibrary.article(id: "rest-days-and-recovery")?.countableText ?? ""
        XCTAssertTrue(rest.contains("24 hours"))
        XCTAssertTrue(rest.contains("3 to 5"))
        XCTAssertTrue(rest.contains("1.4 to 2.0"))
    }

    func testArticlesDoNotHideUncitedPlaceholderFigures() {
        for article in EducationLibrary.articles {
            XCTAssertFalse(article.countableText.contains("PLACEHOLDER"), article.id)
            XCTAssertFalse(article.countableText.contains("TODO"), article.id)
        }
    }
}
