import SwiftUI

/// "What's New" swipeable carousel — Nutrition, Supplements, Profile, and
/// CMSN Training Session, in that order (Nutrition first, per the product
/// direction that food is the sweet-spot feature to lead with).
struct WhatsNewCarouselView: View {
    let onContinue: () -> Void

    private static let cards: [WhatsNewCard] = [
        WhatsNewCard(
            eyebrow: "Nutrition",
            systemImage: "fork.knife",
            headline: "FOOD IS\nFUEL.",
            body: "Set your targets. Log what you eat. No calorie shame, just the numbers that get you where you're going."
        ),
        WhatsNewCard(
            eyebrow: "Supplements",
            systemImage: "pills",
            headline: "KNOW WHAT\nYOU'RE TAKING.",
            body: "Creatine, protein, caffeine — what it does, what the evidence says, nothing pushed on you."
        ),
        WhatsNewCard(
            eyebrow: "Profile",
            systemImage: "person",
            headline: "ONE PROFILE.\nNO GUESSING.",
            body: "Equipment, injuries, goals — tell us once. Every session adjusts to you, not the other way around."
        ),
        WhatsNewCard(
            eyebrow: "CMSN Training Session",
            systemImage: "dumbbell",
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
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1)
                Image(systemName: card.systemImage)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
            }
            .frame(width: 56, height: 56)

            EyebrowLabel(text: card.eyebrow)

            Text(card.headline)
                .font(CMSNTypography.displaySmall(34))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)

            Text(card.body)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .frame(maxWidth: 300, alignment: .leading)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.top, 60)
    }
}

private struct WhatsNewCard {
    let eyebrow: String
    let systemImage: String
    let headline: String
    let body: String
}

#Preview {
    WhatsNewCarouselView(onContinue: {})
}
