import Foundation

/// An explicitly labelled example, never a claim about the current athlete.
/// The paywall and truth-test call the same real rule-based engine.
@MainActor
enum PlusPaywallExample {
    struct Example {
        let withoutPlus: String
        let withPlus: String
        let suggestion: SetSuggestion
    }
    static func make() -> Example {
        let exercise = SeedData.exercises.first { $0.id == "smith-bench-press" }!
        let planned = PlannedSet(targetRepRangeLow: 8, targetRepRangeHigh: 12)
        let history = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12,
            plannedWeightKG: 80, isAttempted: true, completedReps: 12, completedWeightKG: 80, rpe: 8)
        let suggestion = RuleBasedSuggestionEngine().suggestNextSet(plannedSet: planned, exercise: exercise,
            recentHistory: [history], readiness: .moderate, unitPreference: .metric)
        let weight = suggestion.suggestedWeightKG.map { String(format: "%.1f", $0) } ?? "—"
        return Example(withoutPlus: "Smith Machine Bench Press — 3 × 8–12. Choose your weight.",
            withPlus: "Smith Machine Bench Press — 3 × 8–12 at \(weight) kg.\n\(suggestion.rationale)", suggestion: suggestion)
    }
}
