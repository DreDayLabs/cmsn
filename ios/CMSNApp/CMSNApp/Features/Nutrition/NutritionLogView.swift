import SwiftData
import SwiftUI

/// The Nutrition tab. Protein is the headline metric — the calorie estimate
/// is shown as smaller, secondary context, per the product's nutrition
/// "sweet spot" scope (not a full food database).
struct NutritionLogView: View {
    let athlete: Athlete
    @Environment(AppState.self) private var appState

    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]

    @State private var log: NutritionLog?
    @State private var showingMealSuggestions = false
    @State private var mealResults: [MealSuggestion] = []
    @State private var showingMealBuilder = false
    @State private var savedMeals: [SavedMeal] = []

    private var adjustment: TrainingDayAdjustment {
        TrainingDayAdjustment.adjust(athlete: athlete, sessions: workoutSessions)
    }

    private var targets: MacroTargets { adjustment.adjusted }

    private var targetSyncID: String {
        "\(targets.proteinGrams)-\(targets.carbGrams)-\(targets.fatGrams)-\(targets.calorieEstimate)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNPageVideoBackground(
                    clip: .nutrition,
                    isActive: appState.selectedTab == .nutrition && !showingMealBuilder
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        macroSummary
                        TrainingDayWhyCard(adjustment: adjustment)
                        logFoodSection
                        quickAddRow
                        RestrictiveDietsSection(athleteID: athlete.id)
                        if !savedMeals.isEmpty { myMealsSection }
                        if !(log?.entries.isEmpty ?? true) { todaysEntries }
                        mealEngineEntry

                        if showingMealSuggestions {
                            mealSuggestionsList
                        }
                    }
                    .padding(20)
                }
                .scrollContentBackground(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: targetSyncID) { loadLog() }
            .sheet(isPresented: $showingMealBuilder) {
                MealBuilderView { name, totals, ingredients, saveAsMeal in
                    logBuiltMeal(name: name, totals: totals, ingredients: ingredients, saveAsMeal: saveAsMeal)
                }
            }
        }
    }

    private var header: some View {
        CMSNScreenHeader(
            title: "Nutrition",
            trailing: Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        )
    }

    private var macroSummary: some View {
        let loggedProtein = log?.proteinGramsLogged ?? 0
        let proteinTarget = targets.proteinGrams
        let proteinLeft = proteinTarget - loggedProtein
        let fraction = proteinTarget > 0 ? min(1, max(0, loggedProtein / proteinTarget)) : 0
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(CMSNColor.Semantic.track, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(CMSNColor.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(whole(loggedProtein))")
                            .font(CMSNTypography.numeric(28, weight: .bold))
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Text("of \(whole(proteinTarget))")
                            .font(.system(size: 12))
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                }
                .frame(width: 108, height: 108)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Protein")
                .accessibilityValue("\(whole(loggedProtein)) of \(whole(proteinTarget)) grams")

                VStack(alignment: .leading, spacing: 2) {
                    Text("Protein")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    Text(whole(abs(proteinLeft)))
                        .font(CMSNTypography.display(52))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        // Bebas keeps a deep line box under the digits. Pull
                        // "g left" up without eating the figure itself.
                        .padding(.bottom, -8)
                    Text(proteinLeft.rounded() < 0 ? "g over" : "g left")
                        .font(.system(size: 15))
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    Text("~\(grouped(targets.calorieEstimate)) kcal target")
                        .font(.system(size: 13))
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                Spacer(minLength: 0)
            }

            macroBar(
                title: "Calories",
                logged: caloriesLogged,
                target: targets.calorieEstimate,
                unit: "kcal"
            )
            macroBar(
                title: "Carbs",
                logged: summed(\.carbGrams),
                target: targets.carbGrams,
                unit: "g"
            )
            macroBar(
                title: "Fat",
                logged: summed(\.fatGrams),
                target: targets.fatGrams,
                unit: "g"
            )
        }
        .padding(18)
        .cmsnCard()
    }

    private func macroBar(title: String, logged: Double, target: Double, unit: String) -> some View {
        let fraction = target > 0 ? min(1, max(0, logged / target)) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Spacer()
                Text("\(grouped(logged)) / \(grouped(target)) \(unit)")
                    .font(CMSNTypography.numeric(14))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(CMSNColor.Semantic.track)
                    Capsule()
                        .fill(CMSNColor.white)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 8)
        }
    }

    private var caloriesLogged: Double {
        (log?.entries ?? []).reduce(0) { $0 + ($1.calories ?? 0) }
    }

    private func summed(_ keyPath: KeyPath<NutritionEntry, Double?>) -> Double {
        (log?.entries ?? []).reduce(0) { $0 + ($1[keyPath: keyPath] ?? 0) }
    }

    private func whole(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    private func grouped(_ value: Double) -> String {
        Int(value.rounded()).formatted(.number.grouping(.automatic))
    }

    private var quickAddRow: some View {
        HStack(spacing: 12) {
            Button("+ Shake 25 g") { quickAdd(label: "Protein Shake", grams: 25, source: .quickAddShake) }
                .buttonStyle(.cmsnGhost)
            Button("+ Meal 30 g") { quickAdd(label: "Meal", grams: 30, source: .quickAddProtein) }
                .buttonStyle(.cmsnGhost)
        }
    }

    private var mealEngineEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Need an idea?")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            HStack(spacing: 12) {
                Button("High protein, low cost") {
                    mealResults = MealSuggestionEngine.highProteinLowCostNoCook()
                    showingMealSuggestions = true
                }
                .buttonStyle(.cmsnGhost)
                Button("Under 15 min") {
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
                        .font(CMSNTypography.caption())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                .overlay(alignment: .bottom) { Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1) }
                .padding(.vertical, 6)
            }
        }
    }

    private var logFoodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showingMealBuilder = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                    Text("Log food")
                }
            }
            .buttonStyle(.cmsnPrimary)
            .accessibilityLabel("Log Food")

            Text("Scan a barcode, search, or build a meal")
                .font(.system(size: 13))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .frame(maxWidth: .infinity)
        }
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
