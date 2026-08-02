import Foundation

/// Estimated one-rep max via the Epley formula — the standard, widely-cited
/// (if approximate) estimator, chosen over more complex formulas (Brzycki,
/// Lombardi) because it degrades gracefully at higher rep counts, which is
/// where most hypertrophy-range training in this app actually happens.
enum OneRepMaxEstimator {
    /// `weight * (1 + reps / 30)`. At `reps == 1` this correctly returns
    /// `weight` itself rather than dividing by zero or extrapolating.
    static func epley(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }
}

/// Rounds a suggested weight to whatever increment is actually loadable —
/// there's no point suggesting 187.3 lb on a Smith machine.
enum WeightRounding {
    /// kg increments by equipment type, chosen for realistic gym plate/dumbbell
    /// steps (2.5 kg per side on a barbell/Smith machine = 5 kg per rounding
    /// step at the bar; standard commercial dumbbell runs jump in ~2 kg /
    /// ~2.5–5 lb steps; most selectorized machine stacks step in ~5 kg / ~10 lb).
    static func incrementKG(for equipment: EquipmentType, unitPreference: UnitPreference) -> Double {
        switch equipment {
        case .barbell, .smithMachine:
            return unitPreference == .imperial ? 2.268 : 2.5   // 5 lb or 2.5 kg per side-equivalent step
        case .dumbbells, .kettlebell:
            return unitPreference == .imperial ? 2.268 : 2.0   // 5 lb or 2 kg per hand
        case .machine, .cable:
            return unitPreference == .imperial ? 4.536 : 5.0   // 10 lb or 5 kg per stack step
        case .band, .bodyweight, .cardioMachine, .bench, .other:
            return 1.0
        }
    }

    static func round(_ weightKG: Double, to increment: Double) -> Double {
        guard increment > 0 else { return weightKG }
        return (weightKG / increment).rounded() * increment
    }
}

/// What the engine hands back for one upcoming set. Deliberately includes a
/// plain-language `rationale` — the product spec's "transparent coaching"
/// requirement ("every recommendation needs a Why this?") applies here, not
/// just to the future LLM-backed version.
struct SetSuggestion: Equatable {
    var suggestedWeightKG: Double?
    var suggestedRepRangeLow: Int
    var suggestedRepRangeHigh: Int
    var rationale: String
}

/// The seam a real backend-hosted model (Claude API via a thin service)
/// plugs into for V2 without touching any UI code — every call site depends
/// on this protocol, never on `RuleBasedSuggestionEngine` directly.
protocol SuggestionEngine {
    func suggestNextSet(
        plannedSet: PlannedSet,
        exercise: any ExerciseRepresentable,
        recentHistory: [LoggedSet],
        readiness: ReadinessBand,
        unitPreference: UnitPreference
    ) -> SetSuggestion
}

/// V0's deterministic implementation: Epley e1RM + RPE-adjusted progressive
/// overload. No network call, no cost, fully unit-testable — see the "AI
/// depth" tradeoff in the plan.
struct RuleBasedSuggestionEngine: SuggestionEngine {
    /// If the last set hit the top of its rep range at RPE ≤ this value,
    /// there was room in the tank — progress the weight.
    private let progressRPEThreshold: Double = 8.0
    /// At or above this RPE, treat the set as maximally effortful regardless
    /// of whether the rep target was hit.
    private let maxEffortRPEThreshold: Double = 9.5
    private let progressionIncrementFraction: Double = 0.025 // ~2.5%
    private let regressionFraction: Double = 0.90             // -10% on a missed/overreached set

    func suggestNextSet(
        plannedSet: PlannedSet,
        exercise: any ExerciseRepresentable,
        recentHistory: [LoggedSet],
        readiness: ReadinessBand,
        unitPreference: UnitPreference
    ) -> SetSuggestion {
        let increment = WeightRounding.incrementKG(
            for: exercise.equipmentRequired.first ?? .other,
            unitPreference: unitPreference
        )

        guard let lastSet = recentHistory.first,
              let lastWeight = lastSet.completedWeightKG,
              let lastReps = lastSet.completedReps,
              lastWeight > 0, lastReps > 0
        else {
            // No usable history yet — fall back to the plan's own target, or
            // ask the athlete to establish a baseline. Never invents a number.
            return SetSuggestion(
                suggestedWeightKG: plannedSet.targetWeightKG,
                suggestedRepRangeLow: plannedSet.targetRepRangeLow,
                suggestedRepRangeHigh: plannedSet.targetRepRangeHigh,
                rationale: plannedSet.targetWeightKG != nil
                    ? "Starting weight from your program. Log a set so CMSN can suggest next time."
                    : "No history yet for this exercise — pick a weight you can control for the full rep range."
            )
        }

        var targetWeight = lastWeight
        var rationale: String

        let hitTopOfRange = lastReps >= plannedSet.targetRepRangeHigh
        let missedBottomOfRange = lastReps < plannedSet.targetRepRangeLow
        let rpe = lastSet.rpe

        if missedBottomOfRange || (rpe.map { $0 >= maxEffortRPEThreshold } ?? false) {
            targetWeight = lastWeight * regressionFraction
            rationale = "Last time: \(Int(lastWeight.rounded()))×\(lastReps)\(rpeSuffix(rpe)) — that was a grind. Backing off slightly so you can hit the full range today."
        } else if hitTopOfRange && (rpe.map { $0 <= progressRPEThreshold } ?? true) {
            targetWeight = lastWeight * (1 + progressionIncrementFraction)
            rationale = "Last time: \(Int(lastWeight.rounded()))×\(lastReps)\(rpeSuffix(rpe)) — you had room. Try \(Int(WeightRounding.round(targetWeight, to: increment).rounded())) today."
        } else {
            rationale = "Last time: \(Int(lastWeight.rounded()))×\(lastReps)\(rpeSuffix(rpe)) — same weight, aim for the top of the range."
        }

        if readiness == .low {
            targetWeight *= 0.92
            rationale += " Your readiness is low today, so this is trimmed back a bit — chase the reps, not the number."
        }

        let roundedWeight = WeightRounding.round(targetWeight, to: increment)

        return SetSuggestion(
            suggestedWeightKG: roundedWeight,
            suggestedRepRangeLow: plannedSet.targetRepRangeLow,
            suggestedRepRangeHigh: plannedSet.targetRepRangeHigh,
            rationale: rationale
        )
    }

    private func rpeSuffix(_ rpe: Double?) -> String {
        guard let rpe else { return "" }
        return " @ RPE\(rpe.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(rpe)) : String(rpe))"
    }
}
