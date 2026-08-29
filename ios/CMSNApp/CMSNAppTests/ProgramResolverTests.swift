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

    func testSignificantQuadricepsLimitationExcludesOrSubstitutesSquats() {
        // Regression test: `.quadriceps`/`.glute` were previously never
        // present in any seeded exercise's `loadedBodyAreas` (only the joint
        // areas — knee, hip — were tagged), so a reported quad/glute
        // limitation silently matched nothing and heavy squats/leg press
        // were prescribed unmodified.
        let limitation = BodyLimitation(area: .quadriceps, severity: .significant)
        let athlete = makeAthlete(equipment: .residentialGym, limitations: [limitation])
        let resolved = resolver().resolveToday(program: SeedData.pushPullLegs, athlete: athlete, lastCompletedDayIndex: 1)

        let stillHasDirectQuadConflict = resolved.resolvedExercises.contains {
            $0.exercise.loadedBodyAreas.contains(.quadriceps) && $0.wasSubstitutedFromExerciseID == nil && !$0.loadReduced
        }
        XCTAssertFalse(stillHasDirectQuadConflict, "A significant quadriceps limitation must exclude or substitute quad-dominant lifts like squats and leg press, not pass them through untouched.")
    }

    func testSubstituteNeverLoadsASecondActiveLimitationArea() {
        // Regression test: substitution used to only avoid the single area
        // that triggered the swap (`conflict.area`), never the athlete's
        // full limitation list — so a substitute picked to dodge a shoulder
        // limitation could land squarely on a separately-reported lower-back
        // limitation with no check at all.
        let shoulderLimitation = BodyLimitation(area: .shoulder, severity: .significant)
        let lowerBackLimitation = BodyLimitation(area: .lowerBack, severity: .significant)
        let athlete = makeAthlete(equipment: .residentialGym, limitations: [shoulderLimitation, lowerBackLimitation])
        let resolved = resolver().resolveToday(program: SeedData.pushPullLegs, athlete: athlete, lastCompletedDayIndex: 0)

        let unsafeSubstitute = resolved.resolvedExercises.contains { entry in
            entry.wasSubstitutedFromExerciseID != nil
                && (entry.exercise.loadedBodyAreas.contains(.shoulder) || entry.exercise.loadedBodyAreas.contains(.lowerBack))
        }
        XCTAssertFalse(unsafeSubstitute, "A substitute chosen to dodge one limitation must not land on a different area the athlete also has an active limitation on.")
    }

    func testEquipmentSubstitutionAlsoRespectsActiveLimitations() {
        // Regression test: the equipment-substitution path called
        // `substitute(..., avoiding: nil)`, so it never consulted the
        // athlete's limitations at all — an exercise swapped purely for
        // equipment availability could still land on an actively injured area.
        let shoulderLimitation = BodyLimitation(area: .shoulder, severity: .significant)
        let athlete = makeAthlete(equipment: .travel, limitations: [shoulderLimitation])
        let resolved = resolver().resolveToday(program: SeedData.pushPullLegs, athlete: athlete, lastCompletedDayIndex: 0)

        let unsafeSubstitute = resolved.resolvedExercises.contains {
            $0.exercise.loadedBodyAreas.contains(.shoulder)
        }
        XCTAssertFalse(unsafeSubstitute, "Equipment-driven substitution must still avoid an athlete's actively reported limitation areas, not just check equipment availability.")
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
