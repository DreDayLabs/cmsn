import SwiftUI

/// Category list for the education library. The Library tab opens here.
/// The existing supplement notes stay one step inside Supplements.
struct EducationLibraryView: View {
    @State private var path: [LibraryDestination]

    init(openingArticleID: String? = nil) {
        if let destination = EducationLibrary.destination(openingArticleID: openingArticleID) {
            _path = State(initialValue: [destination])
        } else {
            _path = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        ForEach(ArticleCategory.allCases) { category in
                            NavigationLink(value: LibraryDestination.category(category)) {
                                CategoryRow(category: category)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("education-category-\(category.rawValue)")
                        }
                        Text(EducationLibrary.notMedicalAdviceNote)
                            .font(CMSNTypography.bodyQuiet())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CMSNColor.offBlack, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: LibraryDestination.self) { destination in
                switch destination {
                case .category(let category):
                    EducationCategoryView(category: category)
                case .article(let id):
                    if let article = EducationLibrary.article(id: id) {
                        ArticleReaderView(article: article)
                    } else {
                        MissingArticleView()
                    }
                case .supplementNotes:
                    SupplementLibraryView()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Train, fuel, understand")
            Text("Library")
                .font(CMSNTypography.displaySmall(36))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text("Why training and fueling work, written out. Not a plan, and not a prescription.")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
    }
}

private struct CategoryRow: View {
    let category: ArticleCategory

    private var articles: [Article] {
        EducationLibrary.articles(in: category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.rawValue.uppercased())
                .font(CMSNTypography.eyebrow())
                .kerning(1.8)
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            Text(category.rawValue)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text(categoryDetail)
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .cmsnCard()
    }

    private var categoryDetail: String {
        let count = articles.count
        let notes = count == 1 ? "1 note" : "\(count) notes"
        switch category {
        case .supplements:
            return "\(notes) on protein supplements, plus the supplement library already in the app."
        default:
            return notes
        }
    }
}

private struct EducationCategoryView: View {
    let category: ArticleCategory

    private var articles: [Article] {
        EducationLibrary.articles(in: category)
    }

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    EyebrowLabel(text: category.rawValue)
                    Text(category.rawValue)
                        .font(CMSNTypography.displaySmall(32))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)

                    if category == .supplements {
                        NavigationLink(value: LibraryDestination.supplementNotes) {
                            SupplementLibraryLinkCard()
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("education-open-supplement-notes")
                    }

                    ForEach(articles) { article in
                        NavigationLink(value: LibraryDestination.article(article.id)) {
                            ArticleRow(article: article)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("education-article-\(article.id)")
                    }
                }
                .padding(24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CMSNColor.offBlack, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct SupplementLibraryLinkCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Already in the app")
            Text("Supplement notes")
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text("What a supplement is, cautions, and the sources already written for that shelf. Education, not a shopping list.")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .cmsnCard()
    }
}

private struct ArticleRow: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(article.title)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text(article.summary)
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(ReadingTimeEstimate.label(for: article))
                .font(CMSNTypography.caption())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1)
        }
    }
}

struct ArticleReaderView: View {
    let article: Article

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: article.category.rawValue)
                        Text(article.title)
                            .font(CMSNTypography.displaySmall(32))
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Text(article.summary)
                            .font(CMSNTypography.body())
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Text(ReadingTimeEstimate.label(for: article))
                            .font(CMSNTypography.caption())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        Text(ReadingTimeEstimate.todoNote)
                            .font(CMSNTypography.caption())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }

                    ForEach(article.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            EyebrowLabel(text: section.heading)
                            Text(section.body)
                                .font(CMSNTypography.body())
                                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }

                    relatedSection
                    sourcesSection

                    Text(EducationLibrary.notMedicalAdviceNote)
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CMSNColor.offBlack, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .accessibilityIdentifier("education-reader-\(article.id)")
    }

    @ViewBuilder
    private var relatedSection: some View {
        let related = EducationLibrary.relatedArticles(for: article)
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                EyebrowLabel(text: "Related")
                ForEach(related) { item in
                    NavigationLink(value: LibraryDestination.article(item.id)) {
                        Text(item.title)
                            .font(CMSNTypography.body())
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: ArticleReaderContent.sourcesHeading)
            ForEach(ArticleReaderContent.sourceLines(for: article)) { line in
                VStack(alignment: .leading, spacing: 4) {
                    Text(line.title)
                        .font(CMSNTypography.body())
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    Text(line.detail)
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    Link(line.url.absoluteString, destination: line.url)
                        .font(CMSNTypography.caption())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
            }
        }
    }
}

private struct MissingArticleView: View {
    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            Text("That note is not in the library.")
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
    }
}

#Preview("Library") {
    EducationLibraryView()
}

#Preview("Fuel after training") {
    EducationLibraryView(openingArticleID: EducationLibrary.fuelAfterTrainingID)
}
