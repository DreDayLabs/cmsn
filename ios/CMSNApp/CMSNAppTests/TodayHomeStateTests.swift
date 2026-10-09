import XCTest
@testable import CMSNApp

final class TodayHomeStateTests: XCTestCase {
    private func plan(
        focus: SplitFocus = .push,
        names: [String] = ["Bench Press", "Shoulder Press"],
        minutes: Int = 36,
        calendar: Bool = false,
        notes: [String] = []
    ) -> TodayPlannedSession {
        TodayPlannedSession(
            focus: focus,
            exerciseNames: names,
            estimatedMinutes: minutes,
            isCalendarOverride: calendar,
            notes: notes
        )
    }

    private func work(
        id: UUID = UUID(),
        focus: SplitFocus = .push,
        names: [String] = ["Bench Press"],
        attempted: Int = 6,
        plannedSets: Int = 9,
        minutes: Int? = 45,
        complete: Bool = true
    ) -> TodayLoggedWork {
        TodayLoggedWork(
            id: id,
            focus: focus,
            exerciseNames: names,
            attemptedSets: attempted,
            plannedSets: plannedSets,
            minutes: minutes,
            isComplete: complete
        )
    }

    private func athlete(weight: Double = 80) -> Athlete {
        Athlete(
            age: 30,
            heightCM: 180,
            weightKG: weight,
            biologicalSexForCalculation: .male,
            trainingFrequencyPerWeek: 3,
            goalTypes: [.generalFitness]
        )
    }

    private func resistanceSession(minutes: Int) -> TrainingSessionRecord {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        return TrainingSessionRecord(
            startedAt: start,
            endedAt: start.addingTimeInterval(TimeInterval(minutes * 60)),
            splitFocus: .push,
            exercises: [
                TrainingExerciseRecord(
                    exerciseID: "smith-bench-press",
                    name: "Smith Machine Bench Press",
                    sets: [
                        TrainingSetRecord(
                            setType: .working,
                            plannedRepRangeLow: 8,
                            plannedRepRangeHigh: 12,
                            isAttempted: true,
                            completedWeightKG: 40,
                            plannedWeightKG: 40
                        )
                    ]
                )
            ]
        )
    }

    private func adjustment(sessions: [TrainingSessionRecord]) -> TrainingDayAdjustment {
        TrainingDayAdjustment.adjust(
            weightKG: 80,
            baseline: MacroTargetCalculator.nonExerciseBaseline(for: athlete()),
            sessions: sessions
        )
    }

    private func trainedAdjustment() -> TrainingDayAdjustment {
        adjustment(sessions: [resistanceSession(minutes: 45)])
    }

    private func restAdjustment() -> TrainingDayAdjustment {
        adjustment(sessions: [])
    }

    private func remaining(
        _ adjustment: TrainingDayAdjustment,
        entries: [LoggedFoodContribution] = []
    ) -> RemainingMacros {
        RemainingMacros.calculate(targets: adjustment.adjusted, entries: entries)
    }

    private func resolve(
        hasProgram: Bool = true,
        plan: TodayPlannedSession? = nil,
        logged: [TodayLoggedWork] = [],
        adjustment: TrainingDayAdjustment? = nil,
        entries: [LoggedFoodContribution] = []
    ) -> TodayHomeState {
        let resolvedAdjustment = adjustment ?? restAdjustment()
        return TodayHomeState.resolve(
            hasProgram: hasProgram,
            plan: plan,
            logged: logged,
            adjustment: resolvedAdjustment,
            remaining: remaining(resolvedAdjustment, entries: entries)
        )
    }

    private func whole(_ value: Double) -> Int {
        Int(value.rounded())
    }

    // MARK: - Required states

    func testPreWorkoutAsksToStartThePlannedSession() {
        let state = resolve(plan: plan(notes: ["Reduced load on Bench Press."]))

        XCTAssertEqual(state.phase, .preWorkout)
        XCTAssertEqual(state.fuel, .nothingLogged)
        XCTAssertEqual(state.primaryAction, .startWorkout)
        XCTAssertEqual(state.primaryAction.title, "Start Workout")
        XCTAssertEqual(state.headline, "PUSH")
        XCTAssertEqual(state.sessionEyebrow, "Planned")
        XCTAssertEqual(state.sessionTitle, "Push")
        XCTAssertEqual(state.sessionDetail, "2 exercises · about 36 min")
        XCTAssertEqual(state.sessionLines, ["· Bench Press", "· Shoulder Press"])
        XCTAssertEqual(state.sessionNotes, ["Reduced load on Bench Press."])
        XCTAssertTrue(state.showsReadinessCheck)
        XCTAssertFalse(state.showsRecoveryLog)
        XCTAssertEqual(state.articleID, "fuel-after-training")
        XCTAssertEqual(state.articleID, TrainingDayAdjustment.articleID)
    }

    func testPreWorkoutStillStartsWhenNothingIsLoggedOrTheDiaryIsAlreadyOver() {
        let empty = resolve(plan: plan())
        XCTAssertEqual(empty.fuel, .nothingLogged)
        XCTAssertEqual(empty.primaryAction, .startWorkout)

        let trained = trainedAdjustment()
        let over = resolve(
            plan: plan(),
            adjustment: trained,
            entries: [LoggedFoodContribution(proteinGrams: trained.adjusted.proteinGrams + 20, calories: 100)]
        )
        XCTAssertEqual(over.fuel, .overTarget)
        XCTAssertEqual(over.phase, .preWorkout)
        XCTAssertEqual(over.primaryAction, .startWorkout)
    }

    func testPostWorkoutShowsTheFinishedSessionNotTheNextPlan() {
        let trained = trainedAdjustment()
        let state = resolve(
            plan: plan(focus: .pull, names: ["Row"]),
            logged: [work(names: ["Bench Press", "Shoulder Press"])],
            adjustment: trained,
            entries: [LoggedFoodContribution(proteinGrams: 40, calories: 300)]
        )

        XCTAssertEqual(state.phase, .postWorkout)
        XCTAssertEqual(state.fuel, .withinTarget)
        XCTAssertEqual(state.primaryAction, .logFood)
        XCTAssertEqual(state.primaryAction.title, "Log Food")
        XCTAssertEqual(state.headline, "PUSH")
        XCTAssertEqual(state.sessionEyebrow, "Finished")
        XCTAssertEqual(state.sessionTitle, "Push")
        XCTAssertEqual(state.sessionDetail, "6 of 9 sets · 45 min")
        XCTAssertEqual(state.sessionLines, ["· Bench Press", "· Shoulder Press"])
        XCTAssertNotEqual(state.sessionTitle, "Pull")
        XCTAssertFalse(state.sessionLines.contains("· Row"))
        XCTAssertFalse(state.showsReadinessCheck)
        XCTAssertEqual(state.fuelFigure, "\(whole(trained.adjusted.proteinGrams - 40))g")
        XCTAssertEqual(state.fuelCaption, "protein left")
        XCTAssertTrue(state.fuelDetail.contains("\(whole(trained.adjusted.calorieEstimate - 300)) kcal left"))
        XCTAssertTrue(state.fuelDetail.contains("\(whole(trained.adjusted.carbGrams))g carb target"))
        XCTAssertGreaterThan(trained.adjusted.carbGrams, trained.baseline.carbGrams)
        XCTAssertTrue(state.fuelNote.contains("Today's training is included"))
        XCTAssertEqual(state.adjustment.explanation, trained.explanation)
    }

    func testPostWorkoutWithNothingLoggedLeavesTheFullAdjustedTarget() {
        let trained = trainedAdjustment()
        let state = resolve(
            plan: plan(),
            logged: [work()],
            adjustment: trained
        )

        XCTAssertEqual(state.phase, .postWorkout)
        XCTAssertEqual(state.fuel, .nothingLogged)
        XCTAssertEqual(state.primaryAction, .logFood)
        XCTAssertEqual(state.remaining.proteinRemainingGrams, trained.adjusted.proteinGrams)
        XCTAssertEqual(state.remaining.caloriesRemaining, trained.adjusted.calorieEstimate)
        XCTAssertEqual(state.fuelFigure, "\(whole(trained.adjusted.proteinGrams))g")
        XCTAssertEqual(state.fuelCaption, "protein today")
        XCTAssertEqual(
            state.fuelDetail,
            "~\(whole(trained.adjusted.calorieEstimate)) kcal · \(whole(trained.adjusted.carbGrams))g carb target · \(whole(trained.adjusted.fatGrams))g fat target"
        )
        XCTAssertFalse(state.fuelDetail.contains("~\(whole(trained.baseline.calorieEstimate)) kcal"))
        XCTAssertTrue(state.fuelNote.contains("Nothing logged yet"))
        XCTAssertTrue(state.fuelNote.contains("Sources for these targets are on the card below."))
    }

    func testRestDayKeepsUnchangedTargetsAndDoesNotStartAWorkout() {
        let rest = restAdjustment()
        let state = resolve(plan: plan(focus: .restDay, names: [], minutes: 0), adjustment: rest)

        XCTAssertEqual(state.phase, .restDay)
        XCTAssertEqual(state.fuel, .nothingLogged)
        XCTAssertEqual(state.primaryAction, .logFood)
        XCTAssertNotEqual(state.primaryAction, .startWorkout)
        XCTAssertEqual(state.headline, "REST DAY")
        XCTAssertEqual(state.sessionEyebrow, "Rest Day")
        XCTAssertEqual(state.sessionTitle, "No Session")
        XCTAssertEqual(state.sessionDetail, "Nothing is planned. Fuel stays on the day with no training added.")
        XCTAssertTrue(state.sessionLines.isEmpty)
        XCTAssertFalse(state.showsReadinessCheck)
        XCTAssertTrue(state.showsRecoveryLog)
        XCTAssertFalse(rest.targetsChanged)
        XCTAssertEqual(state.adjustment.adjusted, rest.baseline)
        XCTAssertTrue(state.fuelNote.contains("These targets are unchanged."))
        XCTAssertTrue(state.fuelNote.contains("Nothing logged yet"))
        XCTAssertEqual(state.articleID, "fuel-after-training")
    }

    func testRestDayWithFoodLoggedAndProteinMetReadsWhy() {
        let rest = restAdjustment()
        let state = resolve(
            plan: plan(focus: .restDay, names: [], minutes: 0),
            adjustment: rest,
            entries: [
                LoggedFoodContribution(
                    proteinGrams: rest.adjusted.proteinGrams,
                    calories: rest.adjusted.calorieEstimate - 100
                )
            ]
        )

        XCTAssertEqual(state.phase, .restDay)
        XCTAssertEqual(state.fuel, .withinTarget)
        XCTAssertEqual(state.primaryAction, .readWhy)
        XCTAssertEqual(state.primaryAction.title, "Read Why")
        XCTAssertEqual(state.fuelCaption, "protein target met")
        XCTAssertEqual(state.fuelFigure, "\(whole(rest.adjusted.proteinGrams))g")
    }

    func testOverProteinReadsWhyAndNamesTheOverage() {
        let trained = trainedAdjustment()
        let loggedProtein = trained.adjusted.proteinGrams + 32
        let state = resolve(
            logged: [work()],
            adjustment: trained,
            entries: [LoggedFoodContribution(proteinGrams: loggedProtein, calories: 400)]
        )

        XCTAssertEqual(state.phase, .postWorkout)
        XCTAssertEqual(state.fuel, .overTarget)
        XCTAssertEqual(state.primaryAction, .readWhy)
        XCTAssertEqual(state.fuelFigure, "32g over")
        XCTAssertEqual(state.fuelCaption, "today's protein")
        XCTAssertTrue(state.fuelNote.contains("\(whole(loggedProtein))g protein logged of \(whole(trained.adjusted.proteinGrams))g."))
        XCTAssertTrue(state.fuelDetail.contains("\(whole(trained.adjusted.calorieEstimate - 400)) kcal left"))
    }

    func testOverCaloriesReadsWhyWithoutInventingCarbLeft() {
        let trained = trainedAdjustment()
        let calories = trained.adjusted.calorieEstimate + 180
        let state = resolve(
            logged: [work()],
            adjustment: trained,
            entries: [LoggedFoodContribution(proteinGrams: 40, calories: calories)]
        )

        XCTAssertEqual(state.fuel, .overTarget)
        XCTAssertEqual(state.primaryAction, .readWhy)
        XCTAssertEqual(state.fuelFigure, "\(whole(trained.adjusted.proteinGrams - 40))g")
        XCTAssertEqual(state.fuelCaption, "protein left")
        XCTAssertTrue(state.fuelDetail.contains("180 kcal over today's estimate"))
        XCTAssertTrue(state.fuelDetail.contains("\(whole(trained.adjusted.carbGrams))g carb target"))
        XCTAssertFalse(state.fuelDetail.contains("carb left"))
        XCTAssertFalse(state.fuelDetail.contains("fat left"))
    }

    func testNoProgramDoesNotOfferAWorkout() {
        let fallback = plan(
            focus: .restDay,
            names: [],
            minutes: 0,
            notes: ["No program configured — showing a rest day."]
        )
        let state = resolve(hasProgram: false, plan: fallback)

        XCTAssertEqual(state.phase, .noProgram)
        XCTAssertEqual(state.session, .noProgram)
        XCTAssertNotEqual(state.headline, "REST DAY")
        XCTAssertEqual(state.headline, "TODAY")
        XCTAssertEqual(state.sessionEyebrow, "Program")
        XCTAssertEqual(state.sessionTitle, "No Program")
        XCTAssertEqual(state.sessionDetail, "No rotation is set, so there is no session to start.")
        XCTAssertEqual(state.primaryAction, .logFood)
        XCTAssertNotEqual(state.primaryAction, .startWorkout)
        XCTAssertFalse(state.showsReadinessCheck)
        XCTAssertFalse(state.showsRecoveryLog)
        XCTAssertTrue(state.sessionNotes.isEmpty)
        XCTAssertEqual(state.fuel, .nothingLogged)
    }

    func testNoProgramStillShowsWorkThatWasAlreadyLogged() {
        let state = resolve(
            hasProgram: false,
            plan: nil,
            logged: [work()],
            adjustment: trainedAdjustment(),
            entries: [LoggedFoodContribution(proteinGrams: 10, calories: 80)]
        )

        XCTAssertEqual(state.phase, .postWorkout)
        XCTAssertEqual(state.sessionTitle, "Push")
        XCTAssertEqual(state.primaryAction, .logFood)
    }

    // MARK: - Surrounding cases

    func testCalendarOverrideUsesThePlannedSessionCopy() {
        let state = resolve(
            plan: plan(calendar: true, notes: ["Your calendar has \"Leg Day\" today."])
        )

        XCTAssertEqual(state.phase, .preWorkout)
        XCTAssertEqual(state.sessionEyebrow, "From Your Calendar")
        XCTAssertEqual(state.sessionNotes, ["Your calendar has \"Leg Day\" today."])
        XCTAssertEqual(state.primaryAction, .startWorkout)
    }

    func testOpenSessionIsPreWorkoutAndSaysItWillResume() {
        let state = resolve(
            plan: plan(focus: .legs, names: ["Squat"]),
            logged: [work(focus: .push, names: ["Bench Press"], attempted: 1, plannedSets: 3, minutes: nil, complete: false)]
        )

        XCTAssertEqual(state.phase, .preWorkout)
        XCTAssertEqual(state.primaryAction, .startWorkout)
        XCTAssertEqual(state.sessionEyebrow, "In Progress")
        XCTAssertEqual(state.headline, "PUSH")
        XCTAssertEqual(state.sessionTitle, "Push")
        XCTAssertEqual(state.sessionDetail, "1 of 3 sets logged. Starting again resumes this session.")
        XCTAssertEqual(state.sessionLines, ["· Bench Press"])
        XCTAssertTrue(state.showsReadinessCheck)
        XCTAssertNotEqual(state.sessionTitle, "Legs")
    }

    func testOpenSessionWithNoSetsYetDoesNotPretendWorkHappened() {
        let state = resolve(
            plan: plan(),
            logged: [work(attempted: 0, plannedSets: 9, minutes: nil, complete: false)]
        )

        XCTAssertEqual(state.phase, .preWorkout)
        XCTAssertEqual(state.sessionDetail, "Started, nothing logged yet. Starting again resumes this session.")
        XCTAssertEqual(state.primaryAction, .startWorkout)
    }

    func testFinishedSessionWithAnOpenOneWarnsThatStartResumes() {
        let state = resolve(
            logged: [
                work(),
                work(focus: .pull, attempted: 0, plannedSets: 3, minutes: nil, complete: false)
            ],
            adjustment: trainedAdjustment(),
            entries: [LoggedFoodContribution(proteinGrams: 10, calories: 50)]
        )

        XCTAssertEqual(state.phase, .postWorkout)
        XCTAssertEqual(state.sessionNotes, ["A session is still open. Starting a workout resumes it."])
    }

    func testTwoFinishedSessionsSummarizeWithoutDroppingAPartialClock() {
        let state = resolve(
            logged: [
                work(focus: .push, attempted: 4, plannedSets: 6, minutes: 30),
                work(focus: .pull, names: ["Row"], attempted: 2, plannedSets: 3, minutes: nil)
            ],
            adjustment: trainedAdjustment()
        )

        XCTAssertEqual(state.phase, .postWorkout)
        XCTAssertEqual(state.headline, "TRAINED")
        XCTAssertEqual(state.sessionEyebrow, "Logged Today")
        XCTAssertEqual(state.sessionTitle, "Trained")
        XCTAssertEqual(state.sessionDetail, "2 sessions · 6 of 9 sets")
        XCTAssertFalse(state.sessionDetail.contains("min"))
        XCTAssertEqual(state.sessionLines, ["· Push: 4/6 · 30 min", "· Pull: 2/3"])
    }

    func testTwoFinishedSessionsAddClockMinutesWhenBothHaveThem() {
        let state = resolve(
            logged: [
                work(focus: .push, attempted: 4, plannedSets: 6, minutes: 30),
                work(focus: .pull, attempted: 2, plannedSets: 3, minutes: 15)
            ]
        )

        XCTAssertEqual(state.sessionDetail, "2 sessions · 6 of 9 sets · 45 min")
    }

    func testRecoveryWithExercisesCanStartAndStillOffersTheRecoveryLog() {
        let state = resolve(plan: plan(focus: .recovery, names: ["Walk"], minutes: 20))

        XCTAssertEqual(state.phase, .preWorkout)
        XCTAssertEqual(state.primaryAction, .startWorkout)
        XCTAssertEqual(state.sessionDetail, "1 exercise · about 20 min")
        XCTAssertTrue(state.showsReadinessCheck)
        XCTAssertTrue(state.showsRecoveryLog)
    }

    func testEmptyRecoveryDayIsARestDay() {
        let state = resolve(plan: plan(focus: .recovery, names: [], minutes: 0))

        XCTAssertEqual(state.phase, .restDay)
        XCTAssertNotEqual(state.primaryAction, .startWorkout)
        XCTAssertTrue(state.showsRecoveryLog)
        XCTAssertFalse(state.showsReadinessCheck)
    }

    func testMissingCaloriesAreCalledOutAndNotTreatedAsZeroFood() {
        let rest = restAdjustment()
        let state = resolve(
            plan: plan(focus: .restDay, names: [], minutes: 0),
            adjustment: rest,
            entries: [LoggedFoodContribution(proteinGrams: 25, calories: nil)]
        )

        XCTAssertEqual(state.fuel, .withinTarget)
        XCTAssertEqual(state.remaining.entriesMissingCalories, 1)
        XCTAssertEqual(state.remaining.caloriesLogged, 0)
        XCTAssertTrue(state.fuelNote.contains("Some foods have no calories recorded"))
        XCTAssertEqual(state.primaryAction, .logFood)
        XCTAssertEqual(state.fuelFigure, "\(whole(rest.adjusted.proteinGrams - 25))g")
    }

    func testSingleSetUsesTheSingularNoun() {
        let state = resolve(logged: [work(attempted: 1, plannedSets: 1, minutes: 10)])
        XCTAssertEqual(state.sessionDetail, "1 of 1 set · 10 min")
    }

    func testPlannedSessionWithNoExercisesDoesNotInventADuration() {
        let state = resolve(plan: plan(focus: .push, names: [], minutes: 10))
        XCTAssertEqual(state.phase, .preWorkout)
        XCTAssertEqual(state.sessionDetail, "No exercises matched this session.")
        XCTAssertFalse(state.sessionDetail.contains("10"))
    }

    // MARK: - Session mapping

    func testLoggedWorkKeepsTodaysFinishAndOnlyTheNewestOpenSession() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let start = calendar.startOfDay(for: day)

        let finishedToday = WorkoutSession(
            date: start.addingTimeInterval(8 * 3600),
            splitFocus: .push,
            equipmentProfileUsed: .residentialGym,
            endedAt: start.addingTimeInterval(9 * 3600)
        )
        let yesterdayFinished = WorkoutSession(
            date: start.addingTimeInterval(-20 * 3600),
            splitFocus: .legs,
            equipmentProfileUsed: .residentialGym,
            endedAt: start.addingTimeInterval(-19 * 3600)
        )
        let olderOpen = WorkoutSession(
            date: start.addingTimeInterval(-30 * 3600),
            splitFocus: .pull,
            equipmentProfileUsed: .home
        )
        let newerOpen = WorkoutSession(
            date: start.addingTimeInterval(12 * 3600),
            splitFocus: .fullBody,
            equipmentProfileUsed: .home
        )
        let attempted = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: 40)
        attempted.isAttempted = true
        attempted.completedReps = 8
        attempted.completedWeightKG = 40
        finishedToday.loggedExercises = [
            LoggedExercise(
                exerciseID: "smith-bench-press",
                exerciseNameSnapshot: "Smith Machine Bench Press",
                orderIndex: 0,
                loggedSets: [attempted]
            )
        ]

        let works = TodayHomeState.loggedWork(
            on: day,
            from: [olderOpen, yesterdayFinished, finishedToday, newerOpen],
            calendar: calendar
        )

        XCTAssertEqual(Set(works.map(\.id)), Set([finishedToday.id, newerOpen.id]))
        let finished = try XCTUnwrap(works.first { $0.id == finishedToday.id })
        let open = try XCTUnwrap(works.first { $0.id == newerOpen.id })
        XCTAssertEqual(finished.minutes, 60)
        XCTAssertEqual(finished.attemptedSets, 1)
        XCTAssertEqual(finished.plannedSets, 1)
        XCTAssertEqual(finished.exerciseNames, ["Smith Machine Bench Press"])
        XCTAssertFalse(open.isComplete)
        XCTAssertNil(open.minutes)
    }

    func testLoggedWorkPullsForwardAnUnfinishedSessionFromAnEarlierDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let start = calendar.startOfDay(for: day)
        let staleOpen = WorkoutSession(
            date: start.addingTimeInterval(-5 * 3600),
            splitFocus: .pull,
            equipmentProfileUsed: .home
        )

        let works = TodayHomeState.loggedWork(on: day, from: [staleOpen], calendar: calendar)
        let open = try XCTUnwrap(works.first)
        XCTAssertEqual(works.map(\.id), [staleOpen.id])
        XCTAssertEqual(open.focus, .pull)
        XCTAssertFalse(open.isComplete)
    }

    func testMapperOmitsAClockThatRoundsUnderAMinute() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(
            date: start,
            splitFocus: .push,
            equipmentProfileUsed: .residentialGym,
            endedAt: start.addingTimeInterval(20)
        )
        let mapped = TodayLoggedWork(session)
        XCTAssertNil(mapped.minutes)
        XCTAssertTrue(mapped.isComplete)
        XCTAssertEqual(mapped.attemptedSets, 0)
    }
}
