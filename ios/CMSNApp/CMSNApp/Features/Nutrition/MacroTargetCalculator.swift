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

    /// PLACEHOLDER. These bands (1.2 / 1.375 / 1.55 / 1.725) have no
    /// citation in the repo. TODO: replace them with a cited activity model.
    ///
    /// They stay on the weekly-average path only. A training day must not
    /// stack Compendium session energy on top of 1.375+, because those
    /// bands already spread training across every day. `TrainingDayAdjustment`
    /// starts from `nonExerciseActivityMultiplierPlaceholder` and adds the
    /// session on top of that.
    static let nonExerciseActivityMultiplierPlaceholder: Double = 1.2

    static func activityMultiplier(trainingFrequencyPerWeek: Int) -> Double {
        switch trainingFrequencyPerWeek {
        case ..<2: return nonExerciseActivityMultiplierPlaceholder
        case 2...3: return 1.375 // PLACEHOLDER light band
        case 4...5: return 1.55  // PLACEHOLDER moderate band
        default: return 1.725    // PLACEHOLDER active band (6+ sessions/week)
        }
    }

    /// Grams of protein per kg bodyweight, by primary goal.
    ///
    /// ACSM / AND / DC 2016 (Thomas, Erdman & Burke, MSSE 2016;48(3):543-568,
    /// https://pubmed.ncbi.nlm.nih.gov/26891166/): 1.2–2.0 g/kg/d.
    /// ISSN 2017 (Jäger et al., JISSN 2017;14:20,
    /// https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8):
    /// 1.4–2.0 g/kg/d for most exercisers. ISSN also notes 2.3–3.1 g/kg may
    /// help resistance-trained people keep lean mass in a deficit; this
    /// calculator stays at or below 2.0 so every goal remains inside the
    /// ACSM range. Fat loss uses that 2.0 ceiling, tied with muscle gain.
    static func proteinGramsPerKG(for goalTypes: [GoalType]) -> Double {
        if goalTypes.contains(.muscleGain) || goalTypes.contains(.recomposition) { return 2.0 }
        if goalTypes.contains(.fatLoss) { return 2.0 }
        if goalTypes.contains(.strength) { return 1.8 }
        if goalTypes.contains(.endurance) { return 1.4 }
        return 1.6 // general fitness / mobility / consistency / default
    }

    static func targets(for athlete: Athlete) -> MacroTargets {
        targets(
            for: athlete,
            activityMultiplier: activityMultiplier(trainingFrequencyPerWeek: athlete.trainingFrequencyPerWeek)
        )
    }

    /// Resting-day starting point for `TrainingDayAdjustment`.
    /// Mifflin–St Jeor times the uncited 1.2 factor. Session energy is added
    /// later, so the weekly bands are not applied again.
    static func nonExerciseBaseline(for athlete: Athlete) -> MacroTargets {
        targets(for: athlete, activityMultiplier: nonExerciseActivityMultiplierPlaceholder)
    }

    static func targets(for athlete: Athlete, activityMultiplier: Double) -> MacroTargets {
        let bmr = basalMetabolicRate(
            weightKG: athlete.weightKG,
            heightCM: athlete.heightCM,
            age: athlete.age,
            sex: athlete.biologicalSexForCalculation
        )
        let tdee = bmr * activityMultiplier

        let proteinGrams = athlete.weightKG * proteinGramsPerKG(for: athlete.goalTypes)
        let proteinCalories = proteinGrams * 4

        // Fat is 25% of energy. That sits inside the NIH / National Academies
        // adult AMDR of 20–35% of energy
        // (https://ods.od.nih.gov/HealthInformation/nutrientrecommendations.aspx).
        // The rest of the calories, after protein, go to carbohydrate.
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
