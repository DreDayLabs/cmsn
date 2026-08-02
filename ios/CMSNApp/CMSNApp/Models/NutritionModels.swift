import Foundation
import SwiftData

enum DietaryFlag: String, Codable, CaseIterable, Identifiable {
    case vegetarian, vegan, dairyFree, glutenFree, none
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .dairyFree: return "Dairy-Free"
        case .glutenFree: return "Gluten-Free"
        case .none: return "No restriction"
        }
    }
}

enum NutritionEntrySource: String, Codable {
    case quickAddProtein, quickAddShake, mealSuggestion, manual
}

/// One day's nutrition targets + running totals. Protein is the headline
/// metric per the product spec — calorie estimate is stored as context, not
/// surfaced as the primary number in the UI.
@Model
final class NutritionLog {
    @Attribute(.unique) var id: UUID
    var date: Date
    var proteinGramsTarget: Double
    var carbGramsTarget: Double?
    var fatGramsTarget: Double?
    var calorieEstimate: Double?
    var waterOuncesLogged: Double
    var creatineTaken: Bool
    var recoveryShakeTaken: Bool

    @Relationship(deleteRule: .cascade, inverse: \NutritionEntry.log)
    var entries: [NutritionEntry]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        proteinGramsTarget: Double,
        carbGramsTarget: Double? = nil,
        fatGramsTarget: Double? = nil,
        calorieEstimate: Double? = nil,
        waterOuncesLogged: Double = 0,
        creatineTaken: Bool = false,
        recoveryShakeTaken: Bool = false,
        entries: [NutritionEntry] = []
    ) {
        self.id = id
        self.date = date
        self.proteinGramsTarget = proteinGramsTarget
        self.carbGramsTarget = carbGramsTarget
        self.fatGramsTarget = fatGramsTarget
        self.calorieEstimate = calorieEstimate
        self.waterOuncesLogged = waterOuncesLogged
        self.creatineTaken = creatineTaken
        self.recoveryShakeTaken = recoveryShakeTaken
        self.entries = entries
    }

    var proteinGramsLogged: Double { entries.reduce(0) { $0 + $1.proteinGrams } }
    var proteinProgress: Double {
        guard proteinGramsTarget > 0 else { return 0 }
        return min(1, proteinGramsLogged / proteinGramsTarget)
    }
    var hasHitProteinTarget: Bool { proteinGramsLogged >= proteinGramsTarget }
}

@Model
final class NutritionEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var label: String
    var proteinGrams: Double
    var carbGrams: Double?
    var fatGrams: Double?
    var sourceRaw: String

    var log: NutritionLog?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        label: String,
        proteinGrams: Double,
        carbGrams: Double? = nil,
        fatGrams: Double? = nil,
        source: NutritionEntrySource = .manual
    ) {
        self.id = id
        self.timestamp = timestamp
        self.label = label
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
        self.sourceRaw = source.rawValue
    }

    var source: NutritionEntrySource { NutritionEntrySource(rawValue: sourceRaw) ?? .manual }
}

enum CostTier: String, Codable, CaseIterable {
    case low, medium
}

/// A single seeded meal suggestion. Deliberately a static, local dataset in
/// V0 — no barcode database, no restaurant lookup (see plan: nutrition
/// "sweet spot," not a MyFitnessPal clone). Macro figures are approximate
/// ranges, never presented as lab-precise.
struct MealSuggestion: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var ingredients: [String]
    var approxProteinGramsLow: Double
    var approxProteinGramsHigh: Double
    var prepMinutes: Int
    var dietaryFlags: [DietaryFlag]
    var isNoCook: Bool
    var costTier: CostTier
}
