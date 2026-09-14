import Foundation

/// Daily macro targets. Protein is the headline number the UI leads with —
/// `calorieEstimate` is retained as context only, per the product spec's
/// "protein is the headline metric" nutrition-sweet-spot rule.
struct MacroTargets: Equatable {
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double
    var calorieEstimate: Double
}

/// Mifflin-St Jeor BMR + an activity multiplier derived from training
/// frequency (there's no separate "activity level" field on `Athlete` —
/// reusing `trainingFrequencyPerWeek` avoids adding a second, easily
/// inconsistent input) + goal-driven protein g/kg.
///
/// This is intentionally a transparent formula, not a black box — the
/// "why this number" is always answerable from the inputs alone, matching
/// the deterministic, LLM-ready architecture the rest of the suggestion
/// layer uses.
enum MacroTargetCalculator {
    /// kcal/day at complete rest, before any activity multiplier.
    static func basalMetabolicRate(weightKG: Double, heightCM: Double, age: Int, sex: BiologicalSexForCalculation) -> Double {
        let base = 10 * weightKG + 6.25 * heightCM - 5 * Double(age)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        case .preferNotToSay: return base + (5 + -161) / 2 // documented midpoint approximation
        }
    }

    static func activityMultiplier(trainingFrequencyPerWeek: Int) -> Double {
        switch trainingFrequencyPerWeek {
        case ..<2: return 1.2    // sedentary / minimal structured training
        case 2...3: return 1.375 // light
        case 4...5: return 1.55  // moderate
        default: return 1.725    // active (6+ sessions/week)
        }
    }

    /// Grams of protein per kg bodyweight, by primary goal. Ranges cited in
    /// `brand/08-app-strategy.md` (1.6–2.2 g/kg for hypertrophy/recomp);
    /// fat loss skews to the top of the range to help preserve lean mass
    /// during a deficit.
    static func proteinGramsPerKG(for goalTypes: [GoalType]) -> Double {
        if goalTypes.contains(.muscleGain) || goalTypes.contains(.recomposition) { return 2.0 }
        if goalTypes.contains(.fatLoss) { return 2.2 }
        if goalTypes.contains(.strength) { return 1.8 }
        if goalTypes.contains(.endurance) { return 1.4 }
        return 1.6 // general fitness / mobility / consistency / default
    }

    static func targets(for athlete: Athlete) -> MacroTargets {
        let bmr = basalMetabolicRate(
            weightKG: athlete.weightKG,
            heightCM: athlete.heightCM,
            age: athlete.age,
            sex: athlete.biologicalSexForCalculation
        )
        let tdee = bmr * activityMultiplier(trainingFrequencyPerWeek: athlete.trainingFrequencyPerWeek)

        let proteinGrams = athlete.weightKG * proteinGramsPerKG(for: athlete.goalTypes)
        let proteinCalories = proteinGrams * 4

        // Remaining calories split fat/carb: ~25% of total TDEE to fat, the
        // rest to carbs — a simple, explainable default, not a clinical plan.
        let fatCalories = tdee * 0.25
        let fatGrams = fatCalories / 9
        let remainingCalories = max(0, tdee - proteinCalories - fatCalories)
        let carbGrams = remainingCalories / 4

        return MacroTargets(
            proteinGrams: proteinGrams.rounded(),
            carbGrams: carbGrams.rounded(),
            fatGrams: fatGrams.rounded(),
            calorieEstimate: tdee.rounded()
        )
    }
}
