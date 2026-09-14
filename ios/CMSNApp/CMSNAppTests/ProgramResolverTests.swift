import XCTest
@testable import CMSNApp

@MainActor
final class ProgramResolverTests: XCTestCase {
    private func makeAthlete(equipment: EquipmentProfile, limitations: [BodyLimitation] = []) -> Athlete {
        Athlete(age: 30, heightCM: 180, weightKG: 90, equipmentProfile: equipment, limitations: limitations)
    }

    private func resolver() -> ProgramResolver {
        ProgramResolver(calendarService: CalendarSplitService())
    }

    // MARK: - Equipment substitution

    func testResidentialGymKeepsSmithMachineExercises() {
        let athlete = makeAthlete(equipment: .residentialGym)
        let resolved = resolver().resolveToday(program: SeedData.pushPullLegs, athlete: athlete, lastCompletedDayIndex: nil)
        XCTAssertTrue(resolved.resolvedExercises.contains { $0.exercise.id == "smith-bench-press" })
    }

    func testTravelProfileSubstitutesAwayFromSmithMachine() {
        let athlete = makeAthlete(equipment: .travel)
        let resolved = resolver().resolveToday(program: SeedData.pushPullLegs, athlete: athlete, lastCompletedDayIndex: nil)
        // Travel only has bands + bodyweight — no exercise requiring a Smith
        // machine or dumbbells should survive resolution untouched.
        let requiresUnavailableEquipment = resolved.resolvedExercises.contains { resolved in
            let required = Set(resolved.exercise.equipmentRequired)
            return !required.isEmpty && required.isDisjoint(with: EquipmentProfile.travel.availableEquipment)
        }
        XCTAssertFalse(requiresUnavailableEquipment)
    }

    func testQuickSessionEquipmentOverrideDoesNotMutateAthlete() {
        let athlete = makeAthlete(equipment: .residentialGym)
        _ = resolver().resolveQuickSession(focus: .push, equipmentOverride: .home, maxExercises: 3, athlete: athlete)
        // The whole point of ResolutionContext existing: a quick-session
        // equipment override must never leak back into the real profile.
        XCTAssertEqual(athlete.equipmentProfile, .residentialGym)
    }

    // MARK: - Injury exclusion / substitution

    func testSignificantLimitationExcludesOrSubstitutesLoadedExercise() {
        let limitation = BodyLimitation(area: .chest, severity: .significant)
        let athlete = makeAthlete(equipment: .residentialGym, limitations: [limitation])
        let resolved = resolver().resolveToday(program: SeedData.pushPullLegs, athlete: athlete, lastCompletedDayIndex: nil)

        let stillHasDirectChestConflict = resolved.resolvedExercises.contains {
            $0.exercise.loadedBodyAreas.contains(.chest) && $0.wasSubstitutedFromExerciseID == nil && !$0.loadReduced
        }
        XCTAssertFalse(stillHasDirectChestConflict, "A significant chest limitation must exclude or substitute chest-loading exercises, not pass them through untouched.")
    }

    func testMildLimitationReducesLoadRatherThanExcluding() {
        let limitation = BodyLimitation(area: .chest, severity: .mild)
        let athlete = makeAthlete(equipment: .residentialGym, limitations: [limitation])
        let resolved = resolver().resolveToday(program: SeedData.pushPullLegs, athlete: athlete, lastCompletedDayIndex: nil)

        let hasReducedLoadEntry = resolved.resolvedExercises.contains { $0.exercise.id == "smith-bench-press" && $0.loadReduced }
        XCTAssertTrue(hasReducedLoadEntry, "A mild limitation should reduce load, not remove the exercise or substitute it.")
    }

    func testAdjustmentNotesAreNeverEmptyWhenSubstitutionOccurs() {
        let limitation = BodyLimitation(area: .chest, severity: .significant)
        let athlete = makeAthlete(equipment: .residentialGym, limitations: [limitation])
        let resolved = resolver().resolveToday(program: SeedData.pushPullLegs, athlete: athlete, lastCompletedDayIndex: nil)
        XCTAssertFalse(resolved.adjustmentNotes.isEmpty, "Every automatic adjustment must be explained — the 'transparent coaching' requirement.")
    }

    // MARK: - Rotation

    func testRotationAdvancesToNextDay() {
        let athlete = makeAthlete(equipment: .residentialGym)
        let resolved = resolver().resolveToday(program: SeedData.pushPullLegs, athlete: athlete, lastCompletedDayIndex: 0)
        XCTAssertEqual(resolved.focus, SeedData.pushPullLegs.days[1].focus)
    }

    func testRotationWrapsAround() {
        let athlete = makeAthlete(equipment: .residentialGym)
        let lastIndex = SeedData.pushPullLegs.days.count - 1
        let resolved = resolver().resolveToday(program: SeedData.pushPullLegs, athlete: athlete, lastCompletedDayIndex: lastIndex)
        XCTAssertEqual(resolved.focus, SeedData.pushPullLegs.days[0].focus)
    }
}
