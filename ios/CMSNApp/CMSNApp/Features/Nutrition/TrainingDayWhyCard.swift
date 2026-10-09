import SwiftUI

/// "Why today's targets changed." Rest days use the same card and say the
/// targets are unchanged. `articleID` is the education-library slug
/// (`fuel-after-training`); this screen does not open that library.
struct TrainingDayWhyCard: View {
    let adjustment: TrainingDayAdjustment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Why Today's Targets Changed")
            Text(adjustment.explanation)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
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
        .padding(20)
        .cmsnCard()
        .accessibilityIdentifier(TrainingDayAdjustment.articleID)
    }
}
