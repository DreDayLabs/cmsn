import XCTest
@testable import CMSNApp

final class TrainingDayAdjustmentTests: XCTestCase {
    private func athlete(weight: Double = 80, goals: [GoalType] = [.generalFitness], frequency: Int = 3) -> Athlete {
        Athlete(
            age: 30,
            heightCM: 180,
            weightKG: weight,
            biologicalSexForCalculation: .male,
            trainingFrequencyPerWeek: frequency,
            goalTypes: goals
        )
    }

    private func baseline(weight: Double = 80, goals: [GoalType] = [.generalFitness]) -> MacroTargets {
        MacroTargetCalculator.nonExerciseBaseline(for: athlete(weight: weight, goals: goals))
    }

    private func adjust(
        weight: Double = 80,
        goals: [GoalType] = [.generalFitness],
        sessions: [TrainingSessionRecord],
        baseline override: MacroTargets? = nil
    ) -> TrainingDayAdjustment {
        TrainingDayAdjustment.adjust(
            weightKG: weight,
            baseline: override ?? baseline(weight: weight, goals: goals),
            sessions: sessions
        )
    }

    private func workingSet(
        low: Int = 8,
        high: Int = 12,
        type: SetType = .working,
        weight: Double? = 40,
        attempted: Bool = true
    ) -> TrainingSetRecord {
        TrainingSetRecord(
            setType: type,
            plannedRepRangeLow: low,
            plannedRepRangeHigh: high,
            isAttempted: attempted,
            completedWeightKG: weight,
            plannedWeightKG: weight
        )
    }

    private func exercise(id: String, name: String, sets: [TrainingSetRecord]) -> TrainingExerciseRecord {
        TrainingExerciseRecord(exerciseID: id, name: name, sets: sets)
    }

    private func session(
        minutes: Int?,
        focus: SplitFocus,
        exercises: [TrainingExerciseRecord],
        startedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> TrainingSessionRecord {
        let endedAt = minutes.map { startedAt.addingTimeInterval(TimeInterval($0 * 60)) }
        return TrainingSessionRecord(startedAt: startedAt, endedAt: endedAt, splitFocus: focus, exercises: exercises)
    }

    private func bench(high: Int = 12, type: SetType = .working) -> TrainingExerciseRecord {
        exercise(id: "smith-bench-press", name: "Smith Machine Bench Press", sets: [workingSet(high: high, type: type)])
    }

    private func squat() -> TrainingExerciseRecord {
        exercise(id: "smith-squat", name: "Smith Machine Squat", sets: [workingSet()])
    }

    private func swing() -> TrainingExerciseRecord {
        exercise(id: "kb-swing", name: "Kettlebell Swing", sets: [workingSet(weight: 16)])
    }

    private func pushUp(type: SetType = .working) -> TrainingExerciseRecord {
        exercise(id: "pushup", name: "Push-Up", sets: [workingSet(type: type, weight: nil)])
    }

    private func assertSentenceCount(_ result: TrainingDayAdjustment, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(result.explanationSentences.count, 2, file: file, line: line)
        XCTAssertLessThanOrEqual(result.explanationSentences.count, 4, file: file, line: line)
        XCTAssertFalse(result.explanation.isEmpty, file: file, line: line)
    }

    private func assertHTTPSCitations(_ result: TrainingDayAdjustment, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(result.citations.isEmpty, file: file, line: line)
        for citation in result.citations {
            XCTAssertEqual(citation.url.scheme, "https", citation.label, file: file, line: line)
        }
    }

    // MARK: - Energy

    func testNetMetEnergyForAResistanceSession() {
        let result = adjust(sessions: [session(minutes: 45, focus: .push, exercises: [bench()])])

        // (3.5 − 1) × 80 kg × 0.75 h = 150 kcal. Gross METs would be 210.
        XCTAssertEqual(result.extraKcal, 150, accuracy: 0.001)
        XCTAssertNotEqual(result.extraKcal, 3.5 * 80 * 0.75, accuracy: 0.001)
        XCTAssertEqual(result.appliedCodes, ["02054"])
        XCTAssertEqual(result.trainingMinutes, 45)
        XCTAssertEqual(result.carbLoad, .light)
        XCTAssertFalse(result.carbClampedToFloor)
        XCTAssertFalse(result.carbClampedToCeiling)
        XCTAssertEqual(result.adjusted.proteinGrams, result.baseline.proteinGrams)
        XCTAssertEqual(result.adjusted.carbGrams, (result.baseline.carbGrams + 150.0 / 4).rounded())
    }

    func testTwoSessionsAddTheSameEnergyAsOneCombinedSession() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let first = session(minutes: 30, focus: .push, exercises: [bench()], startedAt: start)
        let second = session(minutes: 30, focus: .pull, exercises: [bench()], startedAt: start.addingTimeInterval(3600))
        let combined = session(minutes: 60, focus: .push, exercises: [bench()])

        let split = adjust(sessions: [first, second])
        let single = adjust(sessions: [combined])

        XCTAssertEqual(split.extraKcal, 200, accuracy: 0.001)
        XCTAssertEqual(split.extraKcal, single.extraKcal, accuracy: 0.001)
        XCTAssertEqual(split.trainingMinutes, 60)
        XCTAssertEqual(split.appliedCodes, ["02054", "02054"])
        XCTAssertTrue(split.explanation.contains("across 2 sessions"))
        assertSentenceCount(split)
    }

    func testMissingDurationAddsNoEnergyAndSaysPlaceholder() {
        let result = adjust(sessions: [session(minutes: nil, focus: .push, exercises: [bench()])])

        XCTAssertEqual(result.extraKcal, 0)
        XCTAssertEqual(result.adjusted, result.baseline)
        XCTAssertTrue(result.durationMissing)
        XCTAssertFalse(result.targetsChanged)
        XCTAssertEqual(result.trainingMinutes, 0)
        XCTAssertEqual(result.appliedCodes, [])
        XCTAssertTrue(result.explanation.contains("PLACEHOLDER"))
        XCTAssertTrue(result.explanation.contains("no finish time"))
        XCTAssertFalse(result.explanation.contains("45 min"))
        assertSentenceCount(result)
        assertHTTPSCitations(result)
    }

    func testRestDayLeavesTargetsUnchanged() {
        let result = adjust(sessions: [])

        XCTAssertFalse(result.targetsChanged)
        XCTAssertEqual(result.extraKcal, 0)
        XCTAssertEqual(result.adjusted, result.baseline)
        XCTAssertEqual(result.carbLoad, .none)
        XCTAssertTrue(result.explanation.localizedCaseInsensitiveContains("unchanged"))
        XCTAssertTrue(result.explanation.contains("\(Int(result.baseline.calorieEstimate.rounded())) kcal"))
        XCTAssertTrue(result.explanation.contains("\(Int(result.baseline.proteinGrams.rounded())) g protein"))
        XCTAssertEqual(result.articleID, "fuel-after-training")
        XCTAssertEqual(result.articleID, TrainingDayAdjustment.articleID)
        assertSentenceCount(result)
        assertHTTPSCitations(result)
        XCTAssertTrue(result.citations.contains { $0.id == "mifflin-1990" })
    }

    func testFinishedSessionWithNoAttemptedSetsDoesNotInventEnergy() {
        let untouched = exercise(
            id: "smith-bench-press",
            name: "Smith Machine Bench Press",
            sets: [workingSet(attempted: false)]
        )
        let result = adjust(sessions: [session(minutes: 45, focus: .push, exercises: [untouched])])

        XCTAssertEqual(result.extraKcal, 0)
        XCTAssertEqual(result.adjusted, result.baseline)
        XCTAssertTrue(result.explanation.contains("no sets were completed"))
        XCTAssertTrue(result.explanation.localizedCaseInsensitiveContains("unchanged"))
        assertSentenceCount(result)
    }

    func testUncitedActivityDoesNotInventAMet() {
        let spin = exercise(id: "bike", name: "Bike", sets: [workingSet(weight: nil)])
        let result = adjust(sessions: [session(minutes: 45, focus: .cycling, exercises: [spin])])

        XCTAssertEqual(result.extraKcal, 0)
        XCTAssertTrue(result.activityUncited)
        XCTAssertEqual(result.appliedCodes, [])
        XCTAssertEqual(result.adjusted, result.baseline)
        XCTAssertTrue(result.explanation.contains("PLACEHOLDER"))
        XCTAssertTrue(result.explanation.contains("45 min"))
        XCTAssertTrue(result.explanation.contains("cycling"))
        assertSentenceCount(result)
    }

    // MARK: - Classification

    func testApprovedCompendiumCodes() {
        let hour = 60
        let weight = 80.0
        let cases: [(TrainingSessionRecord, String, Double)] = [
            (session(minutes: hour, focus: .push, exercises: [bench()]), "02054", (3.5 - 1) * weight),
            (session(minutes: hour, focus: .legs, exercises: [squat()]), "02052", (5.0 - 1) * weight),
            (session(minutes: hour, focus: .legs, exercises: [squat(), bench()]), "02054", (3.5 - 1) * weight),
            (session(minutes: hour, focus: .kettlebell, exercises: [swing()]), "02058", (9.8 - 1) * weight),
            (session(minutes: hour, focus: .kettlebell, exercises: [swing(), squat()]), "02054", (3.5 - 1) * weight),
            (session(minutes: hour, focus: .push, exercises: [bench(type: .superset)]), "02055", (5.8 - 1) * weight),
            (session(minutes: hour, focus: .legs, exercises: [exercise(id: "smith-squat", name: "Smith Machine Squat", sets: [workingSet(type: .superset)])]), "02052", (5.0 - 1) * weight),
            (session(minutes: hour, focus: .push, exercises: [pushUp()]), "02056", (3.0 - 1) * weight),
            (session(minutes: hour, focus: .push, exercises: [pushUp(type: .failure)]), "02057", (6.5 - 1) * weight),
            (session(minutes: hour, focus: .push, exercises: [bench(high: 5)]), "02050", (6.0 - 1) * weight),
        ]

        for (record, code, kcal) in cases {
            let result = adjust(weight: weight, sessions: [record])
            XCTAssertEqual(result.appliedCodes, [code], code)
            XCTAssertEqual(result.extraKcal, kcal, accuracy: 0.001, code)
        }
    }

    func testCarbLoadFollowsTheNamedACSMExamples() {
        XCTAssertEqual(TrainingDayAdjustment.carbLoad(trainingHours: 0), .none)
        XCTAssertEqual(TrainingDayAdjustment.carbLoad(trainingHours: 0.75), .light)
        XCTAssertNil(TrainingCarbLoad.none.gramsPerKilogram)
        XCTAssertEqual(TrainingCarbLoad.light.gramsPerKilogram, Optional(3.0...5.0))
        XCTAssertEqual(TrainingDayAdjustment.carbLoad(trainingHours: 1), .moderate)
        XCTAssertEqual(TrainingDayAdjustment.carbLoad(trainingHours: 1.99), .moderate)
        XCTAssertEqual(TrainingCarbLoad.moderate.gramsPerKilogram, Optional(5.0...7.0))
        XCTAssertEqual(TrainingDayAdjustment.carbLoad(trainingHours: 2), .high)
        XCTAssertEqual(TrainingDayAdjustment.carbLoad(trainingHours: 3), .high)
        XCTAssertEqual(TrainingCarbLoad.high.gramsPerKilogram, Optional(6.0...10.0))
        XCTAssertEqual(TrainingDayAdjustment.carbLoad(trainingHours: 3.01), .veryHigh)
        XCTAssertEqual(TrainingCarbLoad.veryHigh.gramsPerKilogram, Optional(8.0...12.0))
    }

    // MARK: - Bounds

    func testShortSessionStaysInsideTheLightCarbBand() {
        let result = adjust(sessions: [session(minutes: 45, focus: .push, exercises: [bench()])])
        assertMacrosInsideCitedBounds(result, weightKG: 80)
        XCTAssertEqual(result.carbLoad, .light)
        let perKg = result.adjusted.carbGrams / 80
        XCTAssertGreaterThanOrEqual(perKg, 3)
        XCTAssertLessThanOrEqual(perKg, 5)
    }

    func testModerateLoadRaisesCarbsToTheACSMFloor() {
        let result = adjust(
            weight: 90,
            goals: [.muscleGain],
            sessions: [session(minutes: 60, focus: .push, exercises: [bench()])]
        )

        XCTAssertEqual(result.extraKcal, (3.5 - 1) * 90, accuracy: 0.001)
        XCTAssertEqual(result.carbLoad, .moderate)
        XCTAssertTrue(result.carbClampedToFloor)
        XCTAssertFalse(result.carbClampedToCeiling)
        assertMacrosInsideCitedBounds(result, weightKG: 90)
        let perKg = result.adjusted.carbGrams / 90
        XCTAssertGreaterThanOrEqual(perKg, 5 - 0.02)
        XCTAssertLessThanOrEqual(perKg, 7 + 0.02)
    }

    func testVeryLongKettlebellSessionStopsAtTheCarbCeiling() {
        let result = adjust(
            weight: 90,
            goals: [.muscleGain],
            sessions: [session(minutes: 360, focus: .kettlebell, exercises: [swing()])]
        )

        XCTAssertEqual(result.extraKcal, (9.8 - 1) * 90 * 6, accuracy: 0.001)
        XCTAssertEqual(result.appliedCodes, ["02058"])
        XCTAssertEqual(result.carbLoad, .veryHigh)
        XCTAssertTrue(result.carbClampedToCeiling)
        assertMacrosInsideCitedBounds(result, weightKG: 90)
        XCTAssertLessThanOrEqual(result.adjusted.carbGrams / 90, 12 + 0.02)
        XCTAssertGreaterThanOrEqual(result.adjusted.carbGrams / 90, 8)
    }

    func testProteinAboveTheACSMCeilingIsBroughtBackInside() {
        let inflated = MacroTargets(proteinGrams: 300, carbGrams: 200, fatGrams: 60, calorieEstimate: 2500)
        let result = adjust(
            sessions: [session(minutes: 45, focus: .push, exercises: [bench()])],
            baseline: inflated
        )

        XCTAssertLessThanOrEqual(result.adjusted.proteinGrams / 80, 2.0)
        XCTAssertGreaterThanOrEqual(result.adjusted.proteinGrams / 80, 1.2)
        assertMacrosInsideCitedBounds(result, weightKG: 80)
    }

    func testSessionEnergyIsNotStackedOnTheWeeklyMultiplier() {
        let frequent = athlete(frequency: 6)
        let weekly = MacroTargetCalculator.targets(for: frequent)
        let resting = MacroTargetCalculator.nonExerciseBaseline(for: frequent)
        XCTAssertGreaterThan(weekly.calorieEstimate, resting.calorieEstimate)

        let result = TrainingDayAdjustment.adjust(
            weightKG: frequent.weightKG,
            baseline: resting,
            sessions: [session(minutes: 45, focus: .push, exercises: [bench()])]
        )

        XCTAssertEqual(result.baseline, resting)
        XCTAssertEqual(result.extraKcal, 150, accuracy: 0.001)
        XCTAssertLessThan(result.adjusted.calorieEstimate, weekly.calorieEstimate + result.extraKcal - 50)
    }

    // MARK: - Reason text

    func testReasonNamesTheMinutesKcalAndCarbChange() {
        let result = adjust(sessions: [session(minutes: 45, focus: .push, exercises: [bench()])])
        let kcal = Int(result.extraKcal.rounded())
        let delta = Int((result.adjusted.carbGrams - result.baseline.carbGrams).rounded())

        XCTAssertEqual(kcal, 150)
        XCTAssertGreaterThan(delta, 0)
        XCTAssertTrue(result.explanation.contains("45 min"))
        XCTAssertTrue(result.explanation.contains("\(kcal) kcal"))
        XCTAssertTrue(result.explanation.contains("\(delta) g"))
        XCTAssertTrue(result.explanation.contains("02054"))
        XCTAssertTrue(result.explanation.contains("3.5"))
        XCTAssertEqual(result.articleID, "fuel-after-training")
        XCTAssertTrue(result.targetsChanged)
        assertSentenceCount(result)
        assertHTTPSCitations(result)
        XCTAssertTrue(result.citations.contains { $0.id == "compendium-2024" })
        XCTAssertTrue(result.citations.contains { $0.id == "acsm-2016" })
        XCTAssertTrue(result.citations.contains { $0.id == "issn-2017" })
        XCTAssertTrue(result.citations.contains { $0.id == "nih-amdr" })
    }

    func testFloorReasonStillNamesTheSessionEnergyAndTheCarbChange() {
        let result = adjust(
            weight: 90,
            goals: [.muscleGain],
            sessions: [session(minutes: 60, focus: .push, exercises: [bench()])]
        )
        let delta = Int((result.adjusted.carbGrams - result.baseline.carbGrams).rounded())
        XCTAssertTrue(result.explanation.contains("60 min"))
        XCTAssertTrue(result.explanation.contains("\(Int(result.extraKcal.rounded())) kcal"))
        XCTAssertTrue(result.explanation.contains("\(delta) g"))
        XCTAssertTrue(result.explanation.contains("ACSM 2016"))
        assertSentenceCount(result)
    }

    func testMixedKnownAndMissingDurationMentionsThePlaceholder() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let done = session(minutes: 45, focus: .push, exercises: [bench()], startedAt: start)
        let open = session(minutes: nil, focus: .pull, exercises: [bench()], startedAt: start.addingTimeInterval(7200))
        let result = adjust(sessions: [done, open])

        XCTAssertEqual(result.extraKcal, 150, accuracy: 0.001)
        XCTAssertTrue(result.durationMissing)
        XCTAssertTrue(result.explanation.contains("150 kcal"))
        XCTAssertTrue(result.explanation.contains("PLACEHOLDER"))
        assertSentenceCount(result)
    }

    // MARK: - Remaining macros and session mapping

    func testRemainingMacrosUsesTheAdjustedTargets() {
        let result = adjust(sessions: [session(minutes: 45, focus: .push, exercises: [bench()])])
        let remaining = RemainingMacros.calculate(
            targets: result.adjusted,
            entries: [LoggedFoodContribution(proteinGrams: 30, calories: 200)]
        )

        XCTAssertEqual(remaining.calorieTarget, result.adjusted.calorieEstimate)
        XCTAssertEqual(remaining.proteinTargetGrams, result.adjusted.proteinGrams)
        XCTAssertEqual(remaining.caloriesRemaining, result.adjusted.calorieEstimate - 200)
        XCTAssertEqual(remaining.proteinRemainingGrams, result.adjusted.proteinGrams - 30)
        XCTAssertGreaterThan(remaining.calorieTarget, result.baseline.calorieEstimate)
    }

    func testWorkoutSessionMapperUsesTheClockAndAttemptedSets() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let workout = WorkoutSession(
            date: start,
            splitFocus: .push,
            equipmentProfileUsed: .residentialGym,
            endedAt: start.addingTimeInterval(45 * 60)
        )
        let attempted = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: 40)
        attempted.isAttempted = true
        attempted.completedReps = 10
        attempted.completedWeightKG = 40
        let skipped = LoggedSet(setIndex: 1, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: 40)
        workout.loggedExercises = [
            LoggedExercise(
                exerciseID: "smith-bench-press",
                exerciseNameSnapshot: "Smith Machine Bench Press",
                orderIndex: 0,
                loggedSets: [attempted, skipped]
            )
        ]

        let result = adjust(sessions: [TrainingSessionRecord(workout)])
        XCTAssertEqual(result.extraKcal, 150, accuracy: 0.001)
        XCTAssertEqual(result.appliedCodes, ["02054"])
    }

    func testTodayFilterKeepsLoggedOrFinishedSessionsFromThatDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let start = calendar.startOfDay(for: day)

        let finished = WorkoutSession(
            date: start.addingTimeInterval(8 * 3600),
            splitFocus: .push,
            equipmentProfileUsed: .residentialGym,
            endedAt: start.addingTimeInterval(9 * 3600)
        )
        let yesterday = WorkoutSession(
            date: start.addingTimeInterval(-20 * 3600),
            splitFocus: .pull,
            equipmentProfileUsed: .residentialGym,
            endedAt: start.addingTimeInterval(-19 * 3600)
        )
        let openEmpty = WorkoutSession(
            date: start.addingTimeInterval(3600),
            splitFocus: .legs,
            equipmentProfileUsed: .home
        )
        let openWithWork = WorkoutSession(
            date: start.addingTimeInterval(12 * 3600),
            splitFocus: .pull,
            equipmentProfileUsed: .home
        )
        let attempted = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: nil)
        attempted.isAttempted = true
        openWithWork.loggedExercises = [
            LoggedExercise(exerciseID: "db-row", exerciseNameSnapshot: "Dumbbell Row", orderIndex: 0, loggedSets: [attempted])
        ]

        let kept = TrainingDayAdjustment.sessions(
            on: day,
            from: [yesterday, openEmpty, openWithWork],
            alsoIncluding: finished,
            calendar: calendar
        )
        XCTAssertEqual(Set(kept.map(\.id)), Set([finished.id, openWithWork.id]))
    }

    private func assertMacrosInsideCitedBounds(_ result: TrainingDayAdjustment, weightKG: Double, file: StaticString = #filePath, line: UInt = #line) {
        let proteinPerKg = result.adjusted.proteinGrams / weightKG
        XCTAssertGreaterThanOrEqual(proteinPerKg, 1.2 - 0.02, file: file, line: line)
        XCTAssertLessThanOrEqual(proteinPerKg, 2.0 + 0.02, file: file, line: line)

        if let band = result.carbLoad.gramsPerKilogram {
            let carbPerKg = result.adjusted.carbGrams / weightKG
            XCTAssertGreaterThanOrEqual(carbPerKg, band.lowerBound - 0.02, file: file, line: line)
            XCTAssertLessThanOrEqual(carbPerKg, band.upperBound + 0.02, file: file, line: line)
        }

        let fatKcal = result.adjusted.fatGrams * 9
        let total = result.adjusted.proteinGrams * 4 + result.adjusted.carbGrams * 4 + fatKcal
        XCTAssertEqual(result.adjusted.calorieEstimate, total, accuracy: 0.01, file: file, line: line)
        let share = fatKcal / total
        XCTAssertGreaterThanOrEqual(share, 0.20 - 0.001, file: file, line: line)
        XCTAssertLessThanOrEqual(share, 0.35 + 0.001, file: file, line: line)
    }
}
