import Foundation
import SwiftData

/// A food looked up from Open Food Facts (or entered by hand), before it's
/// been portioned into a meal. Transient — never persisted directly; a
/// chosen portion of one becomes a `SavedMealIngredient` or contributes to
/// a logged entry's totals.
struct FoodProduct: Identifiable, Hashable {
    var id: String            // OFF barcode, or a UUID string for manual foods
    var name: String
    var brand: String?
    var barcode: String?
    /// Macros per 100 g — OFF's canonical basis. nil when OFF has no data
    /// for that nutrient.
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var caloriesPer100g: Double?
    /// OFF serving size in grams when the label declares one (e.g. one
    /// scoop = 31 g). Used as the portion default so "1 serving" is a tap.
    var servingGrams: Double?
    var servingDescription: String?

    func macros(forGrams grams: Double) -> MacroPortion {
        let f = grams / 100.0
        return MacroPortion(
            protein: (proteinPer100g ?? 0) * f,
            carbs: (carbsPer100g ?? 0) * f,
            fat: (fatPer100g ?? 0) * f,
            calories: (caloriesPer100g ?? 0) * f
        )
    }
}

/// Resolved macros for one chosen portion.
struct MacroPortion: Hashable {
    var protein: Double
    var carbs: Double
    var fat: Double
    var calories: Double

    static let zero = MacroPortion(protein: 0, carbs: 0, fat: 0, calories: 0)
    static func + (l: MacroPortion, r: MacroPortion) -> MacroPortion {
        MacroPortion(protein: l.protein + r.protein, carbs: l.carbs + r.carbs, fat: l.fat + r.fat, calories: l.calories + r.calories)
    }
}

/// A reusable meal the athlete built once and re-logs with one tap ("My
/// Morning Shake"). Ingredients store *resolved* portion macros, not
/// per-100g data — re-logging must reproduce exactly what was saved even
/// if the food database's numbers drift later.
@Model
final class SavedMeal {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SavedMealIngredient.meal)
    var ingredients: [SavedMealIngredient]

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), ingredients: [SavedMealIngredient] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.ingredients = ingredients
    }

    var totals: MacroPortion {
        ingredients.reduce(.zero) { $0 + MacroPortion(protein: $1.proteinGrams, carbs: $1.carbGrams, fat: $1.fatGrams, calories: $1.calories) }
    }
}

@Model
final class SavedMealIngredient {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Human-readable portion ("62 g", "2 scoops") shown in the meal detail.
    var portionDescription: String
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double
    var calories: Double
    var sortOrder: Int

    var meal: SavedMeal?

    init(
        id: UUID = UUID(),
        name: String,
        portionDescription: String,
        proteinGrams: Double,
        carbGrams: Double,
        fatGrams: Double,
        calories: Double,
        sortOrder: Int
    ) {
        self.id = id
        self.name = name
        self.portionDescription = portionDescription
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
        self.calories = calories
        self.sortOrder = sortOrder
    }
}

/// A supplement the athlete added themselves, shown alongside (never inside)
/// the curated education library. Deliberately name + note only: user
/// entries carry no evidence badge, because CMSN hasn't reviewed them.
@Model
final class CustomSupplement {
    @Attribute(.unique) var id: UUID
    var name: String
    var note: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, note: String = "", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.note = note
        self.createdAt = createdAt
    }
}
