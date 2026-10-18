import SwiftUI

/// One line on why today's targets moved, with the sourced note behind More.
/// The collapsed line never leads with the activity-factor placeholder.
/// `articleID` is the education-library slug (`fuel-after-training`).
struct TrainingDayWhyCard: View {
    let adjustment: TrainingDayAdjustment
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                Text(summaryLine)
                    .font(.system(size: 15))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(expanded ? "Less" : "More") {
                    expanded.toggle()
                }
                .buttonStyle(.cmsnText)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleSentences, id: \.self) { sentence in
                        Text(sentence.hasSuffix(".") ? sentence : sentence + ".")
                            .font(CMSNTypography.body())
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(adjustment.citations) { citation in
                        Link(destination: citation.url) {
                            Text(citation.label)
                                .font(CMSNTypography.caption())
                                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                                .underline()
                        }
                    }
                }
            }
        }
        .padding(16)
        .cmsnCard()
        .accessibilityIdentifier(TrainingDayAdjustment.articleID)
    }

    /// The board's one-liner. Unchanged days say so in a single sentence.
    private var summaryLine: String {
        if !adjustment.targetsChanged {
            return "Targets unchanged today."
        }
        if let useful = visibleSentences.first {
            return useful.hasSuffix(".") ? String(useful.dropLast()) : useful
        }
        return "Today's targets include the training you logged."
    }

    /// Sentences that explain the day without the uncited activity-factor note.
    private var visibleSentences: [String] {
        adjustment.explanationSentences.filter {
            !$0.localizedCaseInsensitiveContains("PLACEHOLDER")
        }
    }
}
