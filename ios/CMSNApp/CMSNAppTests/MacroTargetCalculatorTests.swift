import XCTest
@testable import CMSNApp

final class MacroTargetCalculatorTests: XCTestCase {
    private func athlete(goals: [GoalType], frequency: Int = 3) -> Athlete {
        Athlete(age: 30, heightCM: 180, weightKG: 90, trainingFrequencyPerWeek: frequency, goalTypes: goals)
    }

    func testMuscleGainProteinIsHigherThanEnduranceProtein() {
        let muscleGainPerKG = MacroTargetCalculator.proteinGramsPerKG(for: [.muscleGain])
        let endurancePerKG = MacroTargetCalculator.proteinGramsPerKG(for: [.endurance])
        XCTAssertGreaterThan(muscleGainPerKG, endurancePerKG)
    }

    func testFatLossHasHighestProteinTarget() {
        let fatLoss = MacroTargetCalculator.proteinGramsPerKG(for: [.fatLoss])
        let muscleGain = MacroTargetCalculator.proteinGramsPerKG(for: [.muscleGain])
        let general = MacroTargetCalculator.proteinGramsPerKG(for: [.generalFitness])
        XCTAssertGreaterThanOrEqual(fatLoss, muscleGain)
        XCTAssertGreaterThan(fatLoss, general)
        XCTAssertEqual(fatLoss, 2.0)
        XCTAssertEqual(muscleGain, 2.0)
    }

    func testProteinCoefficientsStayInsideACSMAndISSNRanges() {
        for goal in GoalType.allCases {
            let grams = MacroTargetCalculator.proteinGramsPerKG(for: [goal])
            XCTAssertGreaterThanOrEqual(grams, 1.2, "\(goal) is below the ACSM 2016 floor")
            XCTAssertLessThanOrEqual(grams, 2.0, "\(goal) is above the ACSM 2016 and ISSN 2017 ceiling")
        }
    }

    func testWeeklyActivityBandsStayTheUncitedPlaceholders() {
        XCTAssertEqual(MacroTargetCalculator.activityMultiplier(trainingFrequencyPerWeek: 0), 1.2)
        XCTAssertEqual(MacroTargetCalculator.activityMultiplier(trainingFrequencyPerWeek: 3), 1.375)
        XCTAssertEqual(MacroTargetCalculator.activityMultiplier(trainingFrequencyPerWeek: 5), 1.55)
        XCTAssertEqual(MacroTargetCalculator.activityMultiplier(trainingFrequencyPerWeek: 6), 1.725)
        XCTAssertEqual(MacroTargetCalculator.nonExerciseActivityMultiplierPlaceholder, 1.2)
    }

    func testNonExerciseBaselineIgnoresTrainingFrequency() {
        let rare = Athlete(age: 30, heightCM: 180, weightKG: 80, biologicalSexForCalculation: .male, trainingFrequencyPerWeek: 1, goalTypes: [.generalFitness])
        let often = Athlete(age: 30, heightCM: 180, weightKG: 80, biologicalSexForCalculation: .male, trainingFrequencyPerWeek: 6, goalTypes: [.generalFitness])
        XCTAssertEqual(
            MacroTargetCalculator.nonExerciseBaseline(for: rare).calorieEstimate,
            MacroTargetCalculator.nonExerciseBaseline(for: often).calorieEstimate
        )
        XCTAssertGreaterThan(
            MacroTargetCalculator.targets(for: often).calorieEstimate,
            MacroTargetCalculator.nonExerciseBaseline(for: often).calorieEstimate
        )
    }

    func testProteinScalesWithBodyweight() {
        let lighter = Athlete(age: 30, heightCM: 175, weightKG: 70, goalTypes: [.muscleGain])
        let heavier = Athlete(age: 30, heightCM: 175, weightKG: 110, goalTypes: [.muscleGain])
        let lighterTargets = MacroTargetCalculator.targets(for: lighter)
        let heavierTargets = MacroTargetCalculator.targets(for: heavier)
        XCTAssertGreaterThan(heavierTargets.proteinGrams, lighterTargets.proteinGrams)
    }

    func testHigherTrainingFrequencyIncreasesCalorieEstimate() {
        let low = athlete(goals: [.generalFitness], frequency: 1)
        let high = athlete(goals: [.generalFitness], frequency: 6)
        let lowTargets = MacroTargetCalculator.targets(for: low)
        let highTargets = MacroTargetCalculator.targets(for: high)
        XCTAssertGreaterThan(highTargets.calorieEstimate, lowTargets.calorieEstimate)
    }

    func testBMRSexApproximationIsBetweenMaleAndFemale() {
        let male = MacroTargetCalculator.basalMetabolicRate(weightKG: 90, heightCM: 180, age: 30, sex: .male)
        let female = MacroTargetCalculator.basalMetabolicRate(weightKG: 90, heightCM: 180, age: 30, sex: .female)
        let unspecified = MacroTargetCalculator.basalMetabolicRate(weightKG: 90, heightCM: 180, age: 30, sex: .preferNotToSay)
        XCTAssertGreaterThan(unspecified, female)
        XCTAssertLessThan(unspecified, male)
    }

    func testMacrosAreNeverNegative() {
        // A very low-frequency, very light athlete shouldn't produce a
        // negative carb allowance even after protein + fat are subtracted.
        let athlete = Athlete(age: 70, heightCM: 150, weightKG: 45, trainingFrequencyPerWeek: 0, goalTypes: [.muscleGain])
        let targets = MacroTargetCalculator.targets(for: athlete)
        XCTAssertGreaterThanOrEqual(targets.carbGrams, 0)
        XCTAssertGreaterThanOrEqual(targets.fatGrams, 0)
        XCTAssertGreaterThanOrEqual(targets.proteinGrams, 0)
    }
}
