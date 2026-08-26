import Foundation

/// What the minimum user actually asks for: "high protein," "low cost,"
/// "no cook," "under 15 minutes." Every field optional/nil-means-"don't
/// care" so a one-tap quick-path query ("show me a post-workout meal") and
/// a fully-specified one both work through the same engine.
struct MealSuggestionQuery {
    var minimumProteinGrams: Double?
    var maxPrepMinutes: Int?
    var requireNoCook: Bool?
    var dietaryFlag: DietaryFlag?
    var maxCostTier: CostTier?
}

/// Constraint-based filtering over the static, local `SeedData.meals` list —
/// deliberately not a barcode/restaurant database (see nutrition
/// "sweet spot" scope in the plan). Macro figures returned are the seeded
/// approximate ranges, never presented as lab-precise.
enum MealSuggestionEngine {
    static func suggestions(matching query: MealSuggestionQuery, limit: Int = 6) -> [MealSuggestion] {
        let costOrder: [CostTier: Int] = [.low: 0, .medium: 1]

        let filtered = SeedData.meals.filter { meal in
            if let minimumProteinGrams = query.minimumProteinGrams, meal.approxProteinGramsHigh < minimumProteinGrams {
                return false
            }
            if let maxPrepMinutes = query.maxPrepMinutes, meal.prepMinutes > maxPrepMinutes {
                return false
            }
            if let requireNoCook = query.requireNoCook, requireNoCook, !meal.isNoCook {
                return false
            }
            if let dietaryFlag = query.dietaryFlag, dietaryFlag != .none, !meal.dietaryFlags.contains(dietaryFlag) {
                return false
            }
            if let maxCostTier = query.maxCostTier,
               let mealOrder = costOrder[meal.costTier], let maxOrder = costOrder[maxCostTier],
               mealOrder > maxOrder {
                return false
            }
            return true
        }

        // Highest-protein-first: the app's nutrition headline is protein,
        // so that's what "best match first" means here.
        return Array(filtered.sorted { $0.approxProteinGramsHigh > $1.approxProteinGramsHigh }.prefix(limit))
    }

    /// Convenience presets matching the quick-path phrasing from the product
    /// spec ("show me an inexpensive high-protein dinner").
    static func highProteinLowCostNoCook(limit: Int = 6) -> [MealSuggestion] {
        suggestions(matching: MealSuggestionQuery(minimumProteinGrams: 25, requireNoCook: true, maxCostTier: .low), limit: limit)
    }

    static func under15Minutes(limit: Int = 6) -> [MealSuggestion] {
        suggestions(matching: MealSuggestionQuery(maxPrepMinutes: 15), limit: limit)
    }
}
