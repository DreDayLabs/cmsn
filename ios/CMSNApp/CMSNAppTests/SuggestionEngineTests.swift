import XCTest
@testable import CMSNApp

final class SuggestionEngineTests: XCTestCase {
    private let engine = RuleBasedSuggestionEngine()
    private let benchPress = SeedData.exercises.first { $0.id == "smith-bench-press" }!
    private let plannedSet = PlannedSet(setType: .working, targetRepRangeLow: 8, targetRepRangeHigh: 12, targetWeightKG: nil)

    private func loggedSet(reps: Int, weightKG: Double, rpe: Double?) -> LoggedSet {
        let set = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: nil)
        set.isAttempted = true
        set.completedReps = reps
        set.completedWeightKG = weightKG
        set.rpe = rpe
        return set
    }

    func testNoHistoryFallsBackToPlannedTarget() {
        let suggestion = engine.suggestNextSet(
            plannedSet: PlannedSet(setType: .working, targetRepRangeLow: 8, targetRepRangeHigh: 12, targetWeightKG: 100),
            exercise: benchPress,
            recentHistory: [],
            readiness: .moderate,
            unitPreference: .metric
        )
        XCTAssertEqual(suggestion.suggestedWeightKG, 100)
    }

    func testHittingTopOfRangeAtLowRPESuggestsIncrease() {
        let history = [loggedSet(reps: 12, weightKG: 100, rpe: 7)]
        let suggestion = engine.suggestNextSet(plannedSet: plannedSet, exercise: benchPress, recentHistory: history, readiness: .moderate, unitPreference: .metric)
        XCTAssertGreaterThan(suggestion.suggestedWeightKG ?? 0, 100)
    }

    func testMissingBottomOfRangeSuggestsDecrease() {
        let history = [loggedSet(reps: 5, weightKG: 100, rpe: 9)]
        let suggestion = engine.suggestNextSet(plannedSet: plannedSet, exercise: benchPress, recentHistory: history, readiness: .moderate, unitPreference: .metric)
        XCTAssertLessThan(suggestion.suggestedWeightKG ?? 0, 100)
    }

    func testMidRangeHoldsWeight() {
        let history = [loggedSet(reps: 10, weightKG: 100, rpe: 8)]
        let suggestion = engine.suggestNextSet(plannedSet: plannedSet, exercise: benchPress, recentHistory: history, readiness: .moderate, unitPreference: .metric)
        // Held (not decreased) — should stay close to 100, not drop.
        XCTAssertEqual(suggestion.suggestedWeightKG ?? 0, 100, accuracy: 3)
    }

    func testLowReadinessReducesSuggestedWeight() {
        let history = [loggedSet(reps: 12, weightKG: 100, rpe: 7)]
        let normalReadiness = engine.suggestNextSet(plannedSet: plannedSet, exercise: benchPress, recentHistory: history, readiness: .high, unitPreference: .metric)
        let lowReadiness = engine.suggestNextSet(plannedSet: plannedSet, exercise: benchPress, recentHistory: history, readiness: .low, unitPreference: .metric)
        XCTAssertLessThan(lowReadiness.suggestedWeightKG ?? 0, normalReadiness.suggestedWeightKG ?? 0)
    }

    func testRationaleIsNeverEmpty() {
        let suggestion = engine.suggestNextSet(plannedSet: plannedSet, exercise: benchPress, recentHistory: [], readiness: .moderate, unitPreference: .metric)
        XCTAssertFalse(suggestion.rationale.isEmpty)
    }
}
