import SwiftUI

/// "What's New" swipeable carousel — Nutrition, Supplements, Profile, and
/// CMSN Training Session, in that order (Nutrition first, per the product
/// direction that food is the sweet-spot feature to lead with).
struct WhatsNewCarouselView: View {
    let onContinue: () -> Void

    private static let cards: [WhatsNewCard] = [
        WhatsNewCard(
            eyebrow: "Nutrition",
            imageName: "Nutrition",
            headline: "FOOD IS\nFUEL.",
            body: "Set your targets. Log what you eat. No calorie shame, just the numbers that get you where you're going."
        ),
        WhatsNewCard(
            eyebrow: "Supplements",
            imageName: "Supplements",
            headline: "KNOW WHAT\nYOU'RE TAKING.",
            body: "Creatine, protein, caffeine — what it does, what the evidence says, nothing pushed on you."
        ),
        WhatsNewCard(
            eyebrow: "Profile",
            imageName: "Profile",
            headline: "ONE PROFILE.\nNO GUESSING.",
            body: "Equipment, injuries, goals — tell us once. Every session adjusts to you, not the other way around."
        ),
        WhatsNewCard(
            eyebrow: "CMSN Training Session",
            imageName: "TrainingSession",
            headline: "A SESSION BUILT\nFOR TODAY.",
            body: "Sore? Short on time? Only got dumbbells? The plan flexes. Showing up is the hard part — we handle the rest."
        ),
    ]

    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                EyebrowLabel(text: "What's New")
                Spacer()
                Button("Skip", action: onContinue).buttonStyle(.cmsnText)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            TabView(selection: $page) {
                ForEach(Array(Self.cards.enumerated()), id: \.offset) { index, card in
                    cardView(card).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 24) {
                HStack(spacing: 8) {
                    ForEach(Self.cards.indices, id: \.self) { index in
                        Circle()
                            .fill(index == page ? CMSNColor.offWhite : CMSNColor.Semantic.divider)
                            .frame(width: 6, height: 6)
                            .scaleEffect(index == page ? 1.4 : 1)
                            .animation(.easeOut(duration: 0.25), value: page)
                    }
                }
                Button("Continue", action: advance)
                    .buttonStyle(.cmsnPrimary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(CMSNColor.offBlack.ignoresSafeArea())
    }

    private func advance() {
        if page < Self.cards.count - 1 {
            withAnimation { page += 1 }
        } else {
            onContinue()
        }
    }

    private func cardView(_ card: WhatsNewCard) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(card.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [
                    .clear,
                    CMSNColor.offBlack.opacity(0.55),
                    CMSNColor.offBlack.opacity(0.97),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 14) {
                EyebrowLabel(text: card.eyebrow)

                Text(card.headline)
                    .font(CMSNTypography.displaySmall(32))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)

                Text(card.body)
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .frame(maxWidth: 300, alignment: .leading)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
        .clipped()
    }
}

private struct WhatsNewCard {
    let eyebrow: String
    let imageName: String
    let headline: String
    let body: String
}

#Preview {
    WhatsNewCarouselView(onContinue: {})
}
