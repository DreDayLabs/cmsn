import XCTest
import SwiftData
@testable import CMSNApp

@MainActor
final class WorkoutRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: WorkoutRepository!

    override func setUp() {
        super.setUp()
        container = CMSNModelContainerFactory.makeInMemory()
        repository = WorkoutRepository(context: container.mainContext)
    }

    override func tearDown() {
        container = nil
        repository = nil
        super.tearDown()
    }

    private func daysAgo(_ days: Int, from reference: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: reference)!
    }

    // MARK: - hasAnyLoggedWork / daysSinceLastLoggedWork

    func testSessionWithNoAttemptedSetsDoesNotCountAsLoggedWork() {
        let session = WorkoutSession(date: daysAgo(2), splitFocus: .push, equipmentProfileUsed: .residentialGym)
        let unattempted = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: nil)
        session.loggedExercises = [LoggedExercise(exerciseID: "smith-bench-press", exerciseNameSnapshot: "Bench", orderIndex: 0, loggedSets: [unattempted])]
        repository.createSession(session)

        XCTAssertNil(repository.daysSinceLastLoggedWork(), "A session with only placeholder, unattempted sets must not count as real work.")
    }

    func testSessionWithAtLeastOneAttemptedSetCountsAsLoggedWork() {
        let session = WorkoutSession(date: daysAgo(5), splitFocus: .push, equipmentProfileUsed: .residentialGym)
        let attempted = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: nil)
        attempted.isAttempted = true
        attempted.completedReps = 10
        attempted.completedWeightKG = 100
        session.loggedExercises = [LoggedExercise(exerciseID: "smith-bench-press", exerciseNameSnapshot: "Bench", orderIndex: 0, loggedSets: [attempted])]
        repository.createSession(session)

        let days = repository.daysSinceLastLoggedWork(referenceDate: Date())
        XCTAssertNotNil(days)
        XCTAssertEqual(days, 5)
    }

    func testDaysSinceLastLoggedWorkIsNeverNegative() {
        // Reference date earlier than the session's own date shouldn't be
        // possible in real use, but the calculation must not go negative.
        let session = WorkoutSession(date: Date(), splitFocus: .push, equipmentProfileUsed: .residentialGym)
        let attempted = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: nil)
        attempted.isAttempted = true
        attempted.completedReps = 5
        session.loggedExercises = [LoggedExercise(exerciseID: "smith-bench-press", exerciseNameSnapshot: "Bench", orderIndex: 0, loggedSets: [attempted])]
        repository.createSession(session)

        let pastReference = daysAgo(1)
        let days = repository.daysSinceLastLoggedWork(referenceDate: pastReference)
        XCTAssertGreaterThanOrEqual(days ?? 0, 0)
    }

    // MARK: - loggedSets(forExerciseID:) ordering

    func testLoggedSetsReturnsMostRecentFirst() {
        let older = WorkoutSession(date: daysAgo(10), splitFocus: .push, equipmentProfileUsed: .residentialGym)
        let olderSet = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: nil)
        olderSet.isAttempted = true
        olderSet.completedReps = 8
        olderSet.completedWeightKG = 80
        olderSet.loggedAt = daysAgo(10)
        older.loggedExercises = [LoggedExercise(exerciseID: "smith-bench-press", exerciseNameSnapshot: "Bench", orderIndex: 0, loggedSets: [olderSet])]

        let newer = WorkoutSession(date: daysAgo(1), splitFocus: .push, equipmentProfileUsed: .residentialGym)
        let newerSet = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: nil)
        newerSet.isAttempted = true
        newerSet.completedReps = 10
        newerSet.completedWeightKG = 90
        newerSet.loggedAt = daysAgo(1)
        newer.loggedExercises = [LoggedExercise(exerciseID: "smith-bench-press", exerciseNameSnapshot: "Bench", orderIndex: 0, loggedSets: [newerSet])]

        repository.createSession(older)
        repository.createSession(newer)

        let history = repository.loggedSets(forExerciseID: "smith-bench-press")
        XCTAssertEqual(history.first?.completedWeightKG, 90, "Most recent set must come first for the suggestion engine to use it.")
    }

    // MARK: - Midnight / timezone boundary

    func testDaysSinceLastLoggedWorkCrossingMidnightCountsAFullDay() {
        // A session logged at 11:55 PM, queried at 12:05 AM the next
        // calendar day, only ~10 minutes later — this must still read as
        // "1 day since," not "0 days since," because the day boundary
        // (not elapsed hours) is what the Return-loop framing keys off.
        // Uses `Calendar.current` (the same calendar `daysSinceLastLoggedWork`
        // uses internally) rather than a hardcoded timezone, so the
        // day-boundary crossing this test relies on is guaranteed to agree
        // with production's notion of "midnight," regardless of which
        // timezone the test happens to run in.
        let calendar = Calendar.current
        let lateNight = calendar.date(bySettingHour: 23, minute: 55, second: 0, of: Date())!
        let justAfterMidnight = calendar.date(byAdding: .minute, value: 10, to: lateNight)!

        let session = WorkoutSession(date: lateNight, splitFocus: .legs, equipmentProfileUsed: .residentialGym)
        let attempted = LoggedSet(setIndex: 0, plannedRepRangeLow: 8, plannedRepRangeHigh: 12, plannedWeightKG: nil)
        attempted.isAttempted = true
        attempted.completedReps = 8
        session.loggedExercises = [LoggedExercise(exerciseID: "smith-bench-press", exerciseNameSnapshot: "Bench", orderIndex: 0, loggedSets: [attempted])]
        repository.createSession(session)

        let days = repository.daysSinceLastLoggedWork(referenceDate: justAfterMidnight)
        XCTAssertEqual(days, 1, "Crossing a calendar-day boundary must count as a day passing, even if only minutes of wall-clock time elapsed.")
    }
}
