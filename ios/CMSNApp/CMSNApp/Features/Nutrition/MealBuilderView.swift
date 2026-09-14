import SwiftUI

/// One ingredient in the meal being built — already resolved to a chosen
/// portion, so totals are straight sums.
struct DraftIngredient: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var portionDescription: String
    var macros: MacroPortion
}

/// Build a meal from scanned, searched, or hand-entered ingredients; macros
/// sum live; log it to today, optionally saving it as a reusable meal.
/// This is the founder's shake example made concrete: 2 scoops whey +
/// 3 scoops Greek yogurt logs as ONE meal with combined macros.
struct MealBuilderView: View {
    let onLog: (_ name: String, _ totals: MacroPortion, _ ingredients: [DraftIngredient], _ saveAsMeal: Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var ingredients: [DraftIngredient] = []
    @State private var mealName = ""
    @State private var saveAsMeal = false

    private enum AddRoute: Identifiable {
        case scanner, search, manual
        var id: Int { hashValue }
    }
    @State private var addRoute: AddRoute?
    @State private var pendingProduct: FoodProduct?
    @State private var lookupError: String?
    @State private var isLookingUp = false

    private var totals: MacroPortion { ingredients.reduce(.zero) { $0 + $1.macros } }

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        addButtons
                        if isLookingUp { ProgressView().tint(CMSNColor.offWhite) }
                        if let lookupError {
                            Text(lookupError)
                                .font(CMSNTypography.bodyQuiet())
                                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        }
                        if !ingredients.isEmpty {
                            ingredientList
                            totalsCard
                            saveControls
                            Button("Log This Meal") { logMeal() }
                                .buttonStyle(.cmsnPrimary)
                        } else {
                            Text("Add what's actually in the meal — every scoop, every mix-in — and the macros add up here.")
                                .font(CMSNTypography.bodyQuiet())
                                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        }
                    }
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.buttonStyle(.cmsnText)
                }
            }
        }
        .sheet(item: $addRoute) { route in
            switch route {
            case .scanner:
                BarcodeScannerView { code in lookUpBarcode(code) }
            case .search:
                FoodSearchView { product in pendingProduct = product }
            case .manual:
                ManualIngredientView { ingredient in ingredients.append(ingredient) }
            }
        }
        .sheet(item: $pendingProduct) { product in
            PortionEditorView(product: product) { ingredient in
                ingredients.append(ingredient)
                pendingProduct = nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Build A Meal")
            Text("WHAT'S IN IT?")
                .font(CMSNTypography.displaySmall(30))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }

    private var addButtons: some View {
        HStack(spacing: 12) {
            Button("Scan") { addRoute = .scanner }.buttonStyle(.cmsnGhost)
            Button("Search") { addRoute = .search }.buttonStyle(.cmsnGhost)
            Button("Manual") { addRoute = .manual }.buttonStyle(.cmsnGhost)
        }
    }

    private var ingredientList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ingredients) { ingredient in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ingredient.name)
                            .font(CMSNTypography.body())
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Text("\(ingredient.portionDescription) · \(Int(ingredient.macros.protein.rounded()))g protein · \(Int(ingredient.macros.calories.rounded())) kcal")
                            .font(CMSNTypography.bodyQuiet())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                    Spacer()
                    Button {
                        ingredients.removeAll { $0.id == ingredient.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    if ingredient.id != ingredients.last?.id {
                        Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .cmsnCard()
    }

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Meal Total")
            Text("\(Int(totals.protein.rounded()))g protein")
                .font(CMSNTypography.numeric(26))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text("\(Int(totals.calories.rounded())) kcal · \(Int(totals.carbs.rounded()))g carb · \(Int(totals.fat.rounded()))g fat")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cmsnCard()
    }

    private var saveControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $saveAsMeal) {
                Text("Save as a meal I can re-log")
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
            }
            .tint(CMSNColor.offWhite.opacity(0.6))
            if saveAsMeal {
                TextField("Meal name (e.g. Morning Shake)", text: $mealName)
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .padding(12)
                    .cmsnChip(isSelected: false)
            }
        }
    }

    private func lookUpBarcode(_ code: String) {
        isLookingUp = true
        lookupError = nil
        Task {
            defer { isLookingUp = false }
            do {
                pendingProduct = try await OpenFoodFactsService.product(forBarcode: code)
            } catch {
                lookupError = error.localizedDescription
            }
        }
    }

    private func logMeal() {
        let fallback = ingredients.count == 1 ? ingredients[0].name : "Meal (\(ingredients.count) items)"
        let name = mealName.trimmingCharacters(in: .whitespaces).isEmpty ? fallback : mealName.trimmingCharacters(in: .whitespaces)
        onLog(name, totals, ingredients, saveAsMeal)
        dismiss()
    }
}

/// Search Open Food Facts by name.
struct FoodSearchView: View {
    let onSelect: (FoodProduct) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [FoodProduct] = []
    @State private var isSearching = false
    @State private var message: String?

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    EyebrowLabel(text: "Search Foods")
                    Spacer()
                    Button("Close") { dismiss() }.buttonStyle(.cmsnText)
                }
                .padding(.top, 20)

                HStack(spacing: 10) {
                    TextField("Whey protein, greek yogurt…", text: $query)
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        .submitLabel(.search)
                        .onSubmit(runSearch)
                        .padding(12)
                        .cmsnChip(isSelected: false)
                    Button("Go") { runSearch() }.buttonStyle(.cmsnText)
                }

                if isSearching { ProgressView().tint(CMSNColor.offWhite).frame(maxWidth: .infinity) }
                if let message {
                    Text(message)
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(results) { product in
                            Button {
                                onSelect(product)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(product.name)
                                        .font(CMSNTypography.body())
                                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                                        .multilineTextAlignment(.leading)
                                    Text(searchSubtitle(product))
                                        .font(CMSNTypography.bodyQuiet())
                                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func searchSubtitle(_ product: FoodProduct) -> String {
        var parts: [String] = []
        if let brand = product.brand { parts.append(brand) }
        if let protein = product.proteinPer100g { parts.append("\(Int(protein.rounded()))g protein / 100g") }
        if let kcal = product.caloriesPer100g { parts.append("\(Int(kcal.rounded())) kcal / 100g") }
        return parts.joined(separator: " · ")
    }

    private func runSearch() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSearching = true
        message = nil
        Task {
            defer { isSearching = false }
            do {
                results = try await OpenFoodFactsService.search(text)
                if results.isEmpty { message = "Nothing found — try a shorter name, or add it manually." }
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

/// Pick how much of a found product goes into the meal. Grams-based with
/// the label's serving as the starting point when OFF has one.
struct PortionEditorView: View {
    let product: FoodProduct
    let onAdd: (DraftIngredient) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var gramsText: String

    init(product: FoodProduct, onAdd: @escaping (DraftIngredient) -> Void) {
        self.product = product
        self.onAdd = onAdd
        _gramsText = State(initialValue: String(Int((product.servingGrams ?? 100).rounded())))
    }

    private var grams: Double { Double(gramsText) ?? 0 }
    private var macros: MacroPortion { product.macros(forGrams: grams) }

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    EyebrowLabel(text: "How Much?")
                    Spacer()
                    Button("Close") { dismiss() }.buttonStyle(.cmsnText)
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name)
                        .font(CMSNTypography.displaySmall(24))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    if let serving = product.servingDescription {
                        Text("Label serving: \(serving)")
                            .font(CMSNTypography.bodyQuiet())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                }

                HStack(spacing: 12) {
                    TextField("Grams", text: $gramsText)
                        .keyboardType(.decimalPad)
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        .padding(12)
                        .frame(width: 110)
                        .cmsnChip(isSelected: false)
                    Text("grams")
                        .font(CMSNTypography.body())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    if let serving = product.servingGrams {
                        Button("+1 serving (\(Int(serving.rounded()))g)") {
                            gramsText = String(Int((grams + serving).rounded()))
                        }
                        .buttonStyle(.cmsnText)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    EyebrowLabel(text: "This Portion")
                    Text("\(Int(macros.protein.rounded()))g protein · \(Int(macros.calories.rounded())) kcal")
                        .font(CMSNTypography.numeric(20))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    Text("\(Int(macros.carbs.rounded()))g carb · \(Int(macros.fat.rounded()))g fat")
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cmsnCard()

                Button("Add To Meal") {
                    guard grams > 0 else { return }
                    onAdd(DraftIngredient(
                        name: product.name,
                        portionDescription: "\(Int(grams.rounded()))g",
                        macros: macros
                    ))
                    dismiss()
                }
                .buttonStyle(.cmsnPrimary)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}

/// Hand-enter an ingredient the database doesn't have (or a home recipe
/// where you already know the macros — "2 scoops whey, 50g protein").
struct ManualIngredientView: View {
    let onAdd: (DraftIngredient) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var portion = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var calories = ""

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        EyebrowLabel(text: "Add Manually")
                        Spacer()
                        Button("Close") { dismiss() }.buttonStyle(.cmsnText)
                    }
                    .padding(.top, 20)

                    field("Name", text: $name, placeholder: "Whey protein, 2 scoops")
                    field("Portion (optional)", text: $portion, placeholder: "2 scoops")
                    HStack(spacing: 12) {
                        numberField("Protein g", text: $protein)
                        numberField("Carbs g", text: $carbs)
                    }
                    HStack(spacing: 12) {
                        numberField("Fat g", text: $fat)
                        numberField("Calories", text: $calories)
                    }

                    Button("Add To Meal") {
                        let trimmedName = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmedName.isEmpty else { return }
                        onAdd(DraftIngredient(
                            name: trimmedName,
                            portionDescription: portion.trimmingCharacters(in: .whitespaces).isEmpty ? "1 portion" : portion,
                            macros: MacroPortion(
                                protein: Double(protein) ?? 0,
                                carbs: Double(carbs) ?? 0,
                                fat: Double(fat) ?? 0,
                                calories: Double(calories) ?? 0
                            )
                        ))
                        dismiss()
                    }
                    .buttonStyle(.cmsnPrimary)
                }
                .padding(24)
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(CMSNTypography.bodyQuiet()).foregroundStyle(CMSNColor.Semantic.textSecondary)
            TextField(placeholder, text: text)
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .padding(12)
                .cmsnChip(isSelected: false)
        }
    }

    private func numberField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(CMSNTypography.bodyQuiet()).foregroundStyle(CMSNColor.Semantic.textSecondary)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .padding(12)
                .cmsnChip(isSelected: false)
        }
    }
}
