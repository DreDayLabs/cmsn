import SwiftUI

/// "Are you on any restrictive diets?" Multi-select on the Nutrition tab.
/// The answer is saved on the athlete's nutrition preference row, and the
/// selected diets show product-seeded pre- and post-workout fuel ideas.
struct RestrictiveDietsSection: View {
    let athleteID: UUID
    @Environment(AppState.self) private var appState
    @State private var selection = NutritionDietSelection.unanswered

    private var state: RestrictiveDietSectionState {
        RestrictiveDietSectionState.make(selection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Restrictive diets")
            Text("Are you on any restrictive diets?")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text("Pick every pattern you follow. None clears the rest.")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            CMSNFlowLayout(spacing: 8) {
                ForEach(RestrictiveDietCatalog.choices) { diet in
                    dietChip(diet)
                }
            }

            if state.showsFastingWindows {
                fastingWindows
            }

            if state.surface.isVisible {
                Text(state.surface.disclaimer)
                    .font(CMSNTypography.caption())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let overlap = state.surface.overlapNote {
                    Text(overlap)
                        .font(CMSNTypography.caption())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(state.surface.cards) { card in
                    suggestionCard(card)
                }
            }
        }
        .onAppear {
            selection = appState.nutritionRepository.dietSelection(for: athleteID)
        }
    }

    private var fastingWindows: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eating window")
                .font(CMSNTypography.label())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            HStack(spacing: 8) {
                ForEach(FastingWindow.allCases) { window in
                    fastingChip(window)
                }
            }
        }
    }

    private func dietChip(_ diet: RestrictiveDiet) -> some View {
        let on = state.selection.dietIDs.contains(diet.id)
        return Button {
            apply(selection.toggling(diet.id))
        } label: {
            Text(diet.displayName)
                .font(CMSNTypography.eyebrow())
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: 220)
                .foregroundStyle(on ? CMSNColor.offBlack : CMSNColor.Semantic.textPrimary)
                .cmsnChip(isSelected: on)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(diet.displayName)
        .accessibilityAddTraits(on ? .isSelected : AccessibilityTraits())
    }

    private func fastingChip(_ window: FastingWindow) -> some View {
        let on = state.selection.fastingWindow == window
        return Button {
            apply(selection.selectingFastingWindow(window))
        } label: {
            Text(window.displayName)
                .font(CMSNTypography.eyebrow())
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .foregroundStyle(on ? CMSNColor.offBlack : CMSNColor.Semantic.textPrimary)
                .cmsnChip(isSelected: on)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(window.displayName)
        .accessibilityAddTraits(on ? .isSelected : AccessibilityTraits())
    }

    private func suggestionCard(_ card: DietFuelCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.displayName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text(card.summary)
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            fuelLine(title: "Pre-workout", foods: card.preWorkoutFoods, timing: card.preWorkoutTiming)
            fuelLine(title: "Post-workout", foods: card.postWorkoutFoods, timing: card.postWorkoutTiming)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cmsnCard()
        .accessibilityElement(children: .combine)
    }

    private func fuelLine(title: String, foods: String, timing: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(CMSNTypography.label())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text(foods)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(timing)
                .font(CMSNTypography.caption())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func apply(_ next: NutritionDietSelection) {
        selection = next
        appState.nutritionRepository.saveDietSelection(next, athleteID: athleteID)
    }
}
