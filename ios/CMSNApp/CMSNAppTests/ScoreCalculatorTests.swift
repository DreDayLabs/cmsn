import XCTest
@testable import CMSNApp

final class ScoreCalculatorTests: XCTestCase {
    private func makeSession(endedAt: Date?) -> WorkoutSession {
        WorkoutSession(splitFocus: .push, equipmentProfileUsed: .residentialGym, endedAt: endedAt)
    }

    private func makeLoggedExercise(exerciseID: String = "smith-bench-press", sets: [LoggedSet]) -> LoggedExercise {
        LoggedExercise(exerciseID: exerciseID, exerciseNameSnapshot: "Smith Machine Bench Press", orderIndex: 0, loggedSets: sets)
    }

    private func attemptedSet(reps: Int, weight: Double, withinRange: Bool = true) -> LoggedSet {
        let set = LoggedSet(
            setIndex: 0,
            plannedRepRangeLow: withinRange ? reps : reps + 5,
            plannedRepRangeHigh: reps + 4,
            plannedWeightKG: nil
        )
        set.isAttempted = true
        set.completedReps = reps
        set.completedWeightKG = weight
        return set
    }

    // MARK: - Partial-session handling

    func testPartialSessionWithNoCompletionStillEarnsWorkPoints() {
        let session = makeSession(endedAt: nil) // never formally ended
        let set = attemptedSet(reps: 7, weight: 80)
        session.loggedExercises = [makeLoggedExercise(sets: [set])]

        let events = ScoreCalculator.events(forSession: session)
        let workEvents = events.filter { $0.dimension == .work }

        XCTAssertFalse(workEvents.isEmpty, "A partial session with attempted sets must earn work points, never zero.")
        XCTAssertTrue(events.contains { $0.points == ScorePoints.partialSessionBonus })
        XCTAssertFalse(events.contains { $0.points == ScorePoints.sessionCompletionBonus })
    }

    func testCompletedSessionEarnsFullCompletionBonusNotPartial() {
        let session = makeSession(endedAt: Date())
        session.loggedExercises = [makeLoggedExercise(sets: [attemptedSet(reps: 10, weight: 100)])]

        let events = ScoreCalculator.events(forSession: session)
        XCTAssertTrue(events.contains { $0.points == ScorePoints.sessionCompletionBonus })
        XCTAssertFalse(events.contains { $0.points == ScorePoints.partialSessionBonus })
    }

    func testUnattemptedSetsEarnNothingButDoNotReduceScore() {
        let session = makeSession(endedAt: nil)
        let unattempted = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: nil)
        session.loggedExercises = [makeLoggedExercise(sets: [unattempted])]

        let events = ScoreCalculator.events(forSession: session)
        // No attempted sets and no completion => no work events at all, but
        // critically nothing negative either.
        XCTAssertTrue(events.allSatisfy { $0.points >= 0 })
    }

    // MARK: - PR detection

    func testNewEstimatedOneRepMaxAwardsProgressPoints() {
        let session = makeSession(endedAt: Date())
        session.loggedExercises = [makeLoggedExercise(sets: [attemptedSet(reps: 10, weight: 100)])]

        let events = ScoreCalculator.events(forSession: session, previousBestE1RMByExercise: ["smith-bench-press": 50])
        XCTAssertTrue(events.contains { $0.dimension == .progress && $0.points == ScorePoints.estimatedOneRepMaxPR })
    }

    func testNoImprovementAwardsNoProgressPoints() {
        let session = makeSession(endedAt: Date())
        let set = attemptedSet(reps: 10, weight: 100)
        session.loggedExercises = [makeLoggedExercise(sets: [set])]
        let previousBest = OneRepMaxEstimator.epley(weight: 100, reps: 10) + 50

        let events = ScoreCalculator.events(forSession: session, previousBestE1RMByExercise: ["smith-bench-press": previousBest])
        XCTAssertFalse(events.contains { $0.dimension == .progress })
    }

    // MARK: - Rest day / return-after-inactivity (Discipline & Consistency)

    func testRestDayAdherenceEarnsDisciplinePoints() {
        let events = ScoreCalculator.eventsForRestDayAdherence()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.dimension, .discipline)
    }

    func testReturnAfterShortBreakDoesNotScore() {
        XCTAssertTrue(ScoreCalculator.eventsForReturnAfterInactivity(daysInactive: 3).isEmpty)
    }

    func testReturnScalesWithLengthOfBreak() {
        let short = ScoreCalculator.eventsForReturnAfterInactivity(daysInactive: 8).first!.points
        let medium = ScoreCalculator.eventsForReturnAfterInactivity(daysInactive: 15).first!.points
        let long = ScoreCalculator.eventsForReturnAfterInactivity(daysInactive: 30).first!.points
        XCTAssertLessThan(short, medium)
        XCTAssertLessThan(medium, long)
    }

    // MARK: - Composite weighting

    func testDisciplineWeighsMoreThanEqualRawWork() {
        let workEvent = ScoreEvent(dimension: .work, points: 10, reason: "work")
        let disciplineEvent = ScoreEvent(dimension: .discipline, points: 10, reason: "discipline")

        let workOnly = ScoreCalculator.compositeScore(from: [workEvent])
        let disciplineOnly = ScoreCalculator.compositeScore(from: [disciplineEvent])

        XCTAssertGreaterThan(disciplineOnly.total, workOnly.total, "Equal raw points in Discipline must contribute more to the total than in Work, per the 30%/25% weighting.")
    }

    func testWeightsSumToOne() {
        XCTAssertEqual(ScoreWeights.sum, 1.0, accuracy: 0.0001)
    }
}
