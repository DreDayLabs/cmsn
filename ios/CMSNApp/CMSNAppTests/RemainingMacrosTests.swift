import XCTest
@testable import CMSNApp

final class RemainingMacrosTests: XCTestCase {
    private let targets = MacroTargets(
        proteinGrams: 180,
        carbGrams: 250,
        fatGrams: 70,
        calorieEstimate: 2600
    )

    func testNothingLoggedLeavesFullTargets() {
        let remaining = RemainingMacros.calculate(targets: targets, entries: [LoggedFoodContribution]())

        XCTAssertFalse(remaining.hasLoggedFood)
        XCTAssertEqual(remaining.entryCount, 0)
        XCTAssertEqual(remaining.entriesMissingCalories, 0)
        XCTAssertEqual(remaining.proteinLoggedGrams, 0)
        XCTAssertEqual(remaining.caloriesLogged, 0)
        XCTAssertEqual(remaining.proteinTargetGrams, targets.proteinGrams)
        XCTAssertEqual(remaining.calorieTarget, targets.calorieEstimate)
        XCTAssertEqual(remaining.proteinRemainingGrams, 180)
        XCTAssertEqual(remaining.caloriesRemaining, 2600)
        XCTAssertFalse(remaining.isOverProteinTarget)
        XCTAssertFalse(remaining.isOverCalorieTarget)
    }

    func testPartialLogSubtractsOnlyWhatWasLogged() {
        let remaining = RemainingMacros.calculate(targets: targets, entries: [
            LoggedFoodContribution(proteinGrams: 25.5, calories: 150),
            LoggedFoodContribution(proteinGrams: 30, calories: 400),
        ])

        XCTAssertTrue(remaining.hasLoggedFood)
        XCTAssertEqual(remaining.entryCount, 2)
        XCTAssertEqual(remaining.proteinLoggedGrams, 55.5)
        XCTAssertEqual(remaining.caloriesLogged, 550)
        XCTAssertEqual(remaining.proteinRemainingGrams, 124.5)
        XCTAssertEqual(remaining.caloriesRemaining, 2050)
        XCTAssertEqual(remaining.entriesMissingCalories, 0)
        XCTAssertFalse(remaining.isOverProteinTarget)
        XCTAssertFalse(remaining.isOverCalorieTarget)
    }

    func testOverTargetRemainingIsNegative() {
        let remaining = RemainingMacros.calculate(targets: targets, entries: [
            LoggedFoodContribution(proteinGrams: 100, calories: 1500),
            LoggedFoodContribution(proteinGrams: 90, calories: 1300),
        ])

        XCTAssertEqual(remaining.proteinLoggedGrams, 190)
        XCTAssertEqual(remaining.caloriesLogged, 2800)
        XCTAssertEqual(remaining.proteinRemainingGrams, -10)
        XCTAssertEqual(remaining.caloriesRemaining, -200)
        XCTAssertTrue(remaining.isOverProteinTarget)
        XCTAssertTrue(remaining.isOverCalorieTarget)
        XCTAssertTrue(remaining.hasLoggedFood)
    }

    func testProteinCanBeOverWhileCaloriesRemain() {
        let remaining = RemainingMacros.calculate(targets: targets, entries: [
            LoggedFoodContribution(proteinGrams: 200, calories: 800),
        ])

        XCTAssertEqual(remaining.proteinRemainingGrams, -20)
        XCTAssertEqual(remaining.caloriesRemaining, 1800)
        XCTAssertTrue(remaining.isOverProteinTarget)
        XCTAssertFalse(remaining.isOverCalorieTarget)
    }

    func testCaloriesCanBeOverWhileProteinRemains() {
        let remaining = RemainingMacros.calculate(targets: targets, entries: [
            LoggedFoodContribution(proteinGrams: 40, calories: 3000),
        ])

        XCTAssertEqual(remaining.proteinRemainingGrams, 140)
        XCTAssertEqual(remaining.caloriesRemaining, -400)
        XCTAssertFalse(remaining.isOverProteinTarget)
        XCTAssertTrue(remaining.isOverCalorieTarget)
    }

    func testExactlyOnTargetIsZeroRemainingAndStillLogged() {
        let onTarget = MacroTargets(proteinGrams: 100, carbGrams: 120, fatGrams: 50, calorieEstimate: 1500)
        let remaining = RemainingMacros.calculate(targets: onTarget, entries: [
            LoggedFoodContribution(proteinGrams: 60, calories: 900),
            LoggedFoodContribution(proteinGrams: 40, calories: 600),
        ])

        XCTAssertEqual(remaining.proteinRemainingGrams, 0)
        XCTAssertEqual(remaining.caloriesRemaining, 0)
        XCTAssertTrue(remaining.hasLoggedFood)
        XCTAssertFalse(remaining.isOverProteinTarget)
        XCTAssertFalse(remaining.isOverCalorieTarget)
    }

    func testEntriesWithoutCaloriesDoNotReduceCalorieRemainder() {
        let remaining = RemainingMacros.calculate(targets: targets, entries: [
            LoggedFoodContribution(proteinGrams: 25, calories: nil),
            LoggedFoodContribution(proteinGrams: 25, calories: nil),
            LoggedFoodContribution(proteinGrams: 40, calories: 500),
        ])

        XCTAssertEqual(remaining.proteinLoggedGrams, 90)
        XCTAssertEqual(remaining.proteinRemainingGrams, 90)
        XCTAssertEqual(remaining.caloriesLogged, 500)
        XCTAssertEqual(remaining.caloriesRemaining, 2100)
        XCTAssertEqual(remaining.entriesMissingCalories, 2)
        XCTAssertEqual(remaining.entryCount, 3)
        XCTAssertTrue(remaining.hasLoggedFood)
    }

    func testZeroMacroEntryStillCountsAsLogged() {
        let remaining = RemainingMacros.calculate(targets: targets, entries: [
            LoggedFoodContribution(proteinGrams: 0, calories: 0),
        ])

        XCTAssertTrue(remaining.hasLoggedFood)
        XCTAssertEqual(remaining.entriesMissingCalories, 0)
        XCTAssertEqual(remaining.proteinRemainingGrams, targets.proteinGrams)
        XCTAssertEqual(remaining.caloriesRemaining, targets.calorieEstimate)
    }

    func testZeroTargetsWithLoggedFoodGoNegative() {
        let emptyTargets = MacroTargets(proteinGrams: 0, carbGrams: 0, fatGrams: 0, calorieEstimate: 0)
        let remaining = RemainingMacros.calculate(targets: emptyTargets, entries: [
            LoggedFoodContribution(proteinGrams: 10, calories: 100),
        ])

        XCTAssertEqual(remaining.proteinRemainingGrams, -10)
        XCTAssertEqual(remaining.caloriesRemaining, -100)
        XCTAssertTrue(remaining.isOverProteinTarget)
        XCTAssertTrue(remaining.isOverCalorieTarget)
    }

    func testNutritionEntriesMapProteinAndOptionalCalories() {
        let bowl = NutritionEntry(label: "Bowl", proteinGrams: 35, calories: 420, source: .mealBuilder)
        let shake = NutritionEntry(label: "Protein Shake", proteinGrams: 25, source: .quickAddShake)
        let remaining = RemainingMacros.calculate(targets: targets, entries: [bowl, shake])

        XCTAssertEqual(remaining.proteinLoggedGrams, 60)
        XCTAssertEqual(remaining.caloriesLogged, 420)
        XCTAssertEqual(remaining.proteinRemainingGrams, 120)
        XCTAssertEqual(remaining.caloriesRemaining, 2180)
        XCTAssertEqual(remaining.entriesMissingCalories, 1)
        XCTAssertEqual(remaining.entryCount, 2)
    }

    func testFinishedSessionDoesNotChangeTheSuppliedTargets() {
        // Weekly activity is already inside the supplied `calorieEstimate`
        // only when the caller put it there. This step must not add a
        // per-session burn of its own. Pass `TrainingDayAdjustment` targets
        // in when the day should reflect the session.
        let remaining = RemainingMacros.calculate(targets: targets, entries: [
            LoggedFoodContribution(proteinGrams: 30, calories: 200),
        ])

        XCTAssertEqual(remaining.proteinTargetGrams, targets.proteinGrams)
        XCTAssertEqual(remaining.calorieTarget, targets.calorieEstimate)
        XCTAssertEqual(remaining.proteinRemainingGrams, 150)
        XCTAssertEqual(remaining.caloriesRemaining, 2400)
    }
}
