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
    @State private var showingMealBuilder = false
    @State private var savedMeals: [SavedMeal] = []

    private var targets: MacroTargets { MacroTargetCalculator.targets(for: athlete) }

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        proteinRing
                        logFoodSection
                        quickAddRow
                        if !savedMeals.isEmpty { myMealsSection }
                        if !(log?.entries.isEmpty ?? true) { todaysEntries }
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
            .sheet(isPresented: $showingMealBuilder) {
                MealBuilderView { name, totals, ingredients, saveAsMeal in
                    logBuiltMeal(name: name, totals: totals, ingredients: ingredients, saveAsMeal: saveAsMeal)
                }
            }
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
        .cmsnCard()
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

    private var logFoodSection: some View {
        Button {
            showingMealBuilder = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Log Food")
                        .font(CMSNTypography.body())
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    Text("Scan a barcode, search, or build a meal")
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
            }
            .padding(18)
        }
        .buttonStyle(.plain)
        .cmsnCard()
    }

    private var myMealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "My Meals")
            ForEach(savedMeals) { meal in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(meal.name)
                            .font(CMSNTypography.body())
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Text("\(Int(meal.totals.protein.rounded()))g protein · \(Int(meal.totals.calories.rounded())) kcal · \(meal.ingredients.count) item\(meal.ingredients.count == 1 ? "" : "s")")
                            .font(CMSNTypography.bodyQuiet())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                    Spacer()
                    Button("Log") { logSavedMeal(meal) }
                        .buttonStyle(.cmsnText)
                }
                .padding(14)
                .cmsnCard()
                .contextMenu {
                    Button(role: .destructive) {
                        appState.nutritionRepository.deleteSavedMeal(meal)
                        savedMeals = appState.nutritionRepository.savedMeals()
                    } label: {
                        Label("Delete Meal", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var todaysEntries: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Logged Today")
            VStack(spacing: 0) {
                ForEach(sortedEntries, id: \.id) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.label)
                                .font(CMSNTypography.body())
                                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                            Text(entrySubtitle(entry))
                                .font(CMSNTypography.bodyQuiet())
                                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        }
                        Spacer()
                        Button {
                            appState.nutritionRepository.removeEntry(entry)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        }
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        if entry.id != sortedEntries.last?.id {
                            Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .cmsnCard()
        }
    }

    private var sortedEntries: [NutritionEntry] {
        (log?.entries ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    private func entrySubtitle(_ entry: NutritionEntry) -> String {
        var parts = ["\(Int(entry.proteinGrams.rounded()))g protein"]
        if let kcal = entry.calories { parts.append("\(Int(kcal.rounded())) kcal") }
        parts.append(entry.timestamp.formatted(date: .omitted, time: .shortened))
        return parts.joined(separator: " · ")
    }

    private func logBuiltMeal(name: String, totals: MacroPortion, ingredients: [DraftIngredient], saveAsMeal: Bool) {
        guard let log else { return }
        let entry = NutritionEntry(
            label: name,
            proteinGrams: totals.protein,
            carbGrams: totals.carbs,
            fatGrams: totals.fat,
            calories: totals.calories,
            source: .mealBuilder
        )
        appState.nutritionRepository.addEntry(entry, to: log)
        if saveAsMeal {
            appState.nutritionRepository.saveMeal(name: name, ingredients: ingredients)
            savedMeals = appState.nutritionRepository.savedMeals()
        }
    }

    private func logSavedMeal(_ meal: SavedMeal) {
        guard let log else { return }
        let totals = meal.totals
        let entry = NutritionEntry(
            label: meal.name,
            proteinGrams: totals.protein,
            carbGrams: totals.carbs,
            fatGrams: totals.fat,
            calories: totals.calories,
            source: .savedMeal
        )
        appState.nutritionRepository.addEntry(entry, to: log)
    }

    private func loadLog() {
        let t = targets
        log = appState.nutritionRepository.createOrFetchToday(
            proteinTarget: t.proteinGrams,
            carbTarget: t.carbGrams,
            fatTarget: t.fatGrams,
            calorieEstimate: t.calorieEstimate
        )
        savedMeals = appState.nutritionRepository.savedMeals()
    }

    private func quickAdd(label: String, grams: Double, source: NutritionEntrySource) {
        guard let log else { return }
        let entry = NutritionEntry(label: label, proteinGrams: grams, source: source)
        appState.nutritionRepository.addEntry(entry, to: log)
    }
}
