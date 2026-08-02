import SwiftUI

/// The Nutrition tab. Protein is the headline metric — the calorie estimate
/// is shown as smaller, secondary context, per the product's nutrition
/// "sweet spot" scope (not a full food database).
struct NutritionLogView: View {
    let athlete: Athlete
    @Environment(AppState.self) private var appState

    @State private var log: NutritionLog?
    @State private var showingMealSuggestions = false
    @State private var mealResults: [MealSuggestion] = []

    private var targets: MacroTargets { MacroTargetCalculator.targets(for: athlete) }

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        proteinRing
                        quickAddRow
                        macroContext
                        mealEngineEntry

                        if showingMealSuggestions {
                            mealSuggestionsList
                        }
                    }
                    .padding(24)
                }
            }
            .task { loadLog() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Nutrition")
            Text("Protein")
                .font(CMSNTypography.displaySmall(40))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }

    private var proteinRing: some View {
        VStack(alignment: .leading, spacing: 10) {
            let logged = log?.proteinGramsLogged ?? 0
            let target = log?.proteinGramsTarget ?? targets.proteinGrams
            Text("\(Int(logged))g / \(Int(target))g")
                .font(CMSNTypography.numeric(28))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(CMSNColor.Semantic.divider)
                    Rectangle().fill(CMSNColor.offWhite)
                        .frame(width: geometry.size.width * min(1, target > 0 ? logged / target : 0))
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
    }

    private var quickAddRow: some View {
        HStack(spacing: 12) {
            Button("+ Shake (25g)") { quickAdd(label: "Protein Shake", grams: 25, source: .quickAddShake) }
                .buttonStyle(.cmsnGhost)
            Button("+ Meal (30g)") { quickAdd(label: "Meal", grams: 30, source: .quickAddProtein) }
                .buttonStyle(.cmsnGhost)
        }
    }

    private var macroContext: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Today's Estimate")
            Text("~\(Int(log?.calorieEstimate ?? targets.calorieEstimate)) kcal · \(Int(log?.carbGramsTarget ?? targets.carbGrams))g carb · \(Int(log?.fatGramsTarget ?? targets.fatGrams))g fat")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
    }

    private var mealEngineEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Need An Idea?")
            HStack(spacing: 12) {
                Button("High Protein, Low Cost") {
                    mealResults = MealSuggestionEngine.highProteinLowCostNoCook()
                    showingMealSuggestions = true
                }
                .buttonStyle(.cmsnGhost)
                Button("Under 15 Min") {
                    mealResults = MealSuggestionEngine.under15Minutes()
                    showingMealSuggestions = true
                }
                .buttonStyle(.cmsnGhost)
            }
        }
    }

    private var mealSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(mealResults) { meal in
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.name).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
                    Text(meal.ingredients.joined(separator: ", "))
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    Text("~\(Int(meal.approxProteinGramsLow))–\(Int(meal.approxProteinGramsHigh))g protein · \(meal.prepMinutes) min")
                        .font(.system(size: 11))
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                .overlay(alignment: .bottom) { Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1) }
                .padding(.vertical, 6)
            }
        }
    }

    private func loadLog() {
        let t = targets
        log = appState.nutritionRepository.createOrFetchToday(
            proteinTarget: t.proteinGrams,
            carbTarget: t.carbGrams,
            fatTarget: t.fatGrams,
            calorieEstimate: t.calorieEstimate
        )
    }

    private func quickAdd(label: String, grams: Double, source: NutritionEntrySource) {
        guard let log else { return }
        let entry = NutritionEntry(label: label, proteinGrams: grams, source: source)
        appState.nutritionRepository.addEntry(entry, to: log)
    }
}
