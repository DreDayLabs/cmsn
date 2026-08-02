import Foundation

/// One exercise slot after resolution — the plan, plus whatever
/// substitution/exclusion reasoning was applied to get there.
struct ResolvedPlannedExercise: Identifiable {
    var id: UUID { plannedExercise.id }
    var plannedExercise: PlannedExercise
    var exercise: any ExerciseRepresentable
    var wasSubstitutedFromExerciseID: String?
    var substitutionReason: String?
    var loadReduced: Bool = false
}

/// Today's fully-resolved session — what `TodayView` displays and what
/// `WorkoutSessionView` is initialized from.
struct ResolvedProgramDay {
    var focus: SplitFocus
    var resolvedExercises: [ResolvedPlannedExercise]
    var isCalendarOverride: Bool
    var sourceCalendarEventIdentifier: String?
    /// Plain-language notes surfaced in the UI — the "transparent coaching"
    /// requirement: every adjustment says why.
    var adjustmentNotes: [String]
    var estimatedMinutes: Int
}

/// The subset of an `Athlete` that resolution actually needs. A plain value
/// type on purpose: `Athlete` is a SwiftData `@Model` reference type, and a
/// quick-session equipment override must never risk mutating the athlete's
/// real, persisted profile just to answer "what if I only had dumbbells today."
struct ResolutionContext {
    var equipmentProfile: EquipmentProfile
    var limitations: [BodyLimitation]

    init(equipmentProfile: EquipmentProfile, limitations: [BodyLimitation]) {
        self.equipmentProfile = equipmentProfile
        self.limitations = limitations
    }

    init(athlete: Athlete) {
        self.equipmentProfile = athlete.equipmentProfile
        self.limitations = athlete.limitations
    }

    /// A copy with the equipment profile overridden — used by quick-path
    /// sessions ("I only have dumbbells today") without touching the real profile.
    func overridingEquipment(_ profile: EquipmentProfile) -> ResolutionContext {
        ResolutionContext(equipmentProfile: profile, limitations: limitations)
    }

    var activeLimitations: [BodyLimitation] {
        limitations.filter { $0.severity >= .mild }
    }
}

/// Resolves "what should today's session actually be" from: the active
/// program's rotation, a possible calendar override, the athlete's
/// equipment profile, and any reported body-area limitations. This is the
/// single place all four inputs meet — no feature reimplements this logic.
@MainActor
struct ProgramResolver {
    let calendarService: CalendarSplitService
    let customExercises: [CustomExercise]

    init(calendarService: CalendarSplitService, customExercises: [CustomExercise] = []) {
        self.calendarService = calendarService
        self.customExercises = customExercises
    }

    /// - Parameters:
    ///   - program: the athlete's active rotation.
    ///   - athlete: drives equipment substitution and injury exclusion.
    ///   - lastCompletedDayIndex: index within `program.days` of the last
    ///     completed session, used to advance the rotation. `nil` starts at day 0.
    func resolveToday(program: TrainingProgram, athlete: Athlete, lastCompletedDayIndex: Int?) -> ResolvedProgramDay {
        let context = ResolutionContext(athlete: athlete)

        if let overrideFocus = calendarService.todaysOverrideFocus() {
            let overrideEvent = calendarService.todaysOverrideEvent()
            let day = program.days.first(where: { $0.focus == overrideFocus }) ?? adHocDay(for: overrideFocus)
            var resolved = resolve(day: day, context: context)
            resolved.isCalendarOverride = true
            resolved.sourceCalendarEventIdentifier = overrideEvent?.eventIdentifier
            resolved.adjustmentNotes.insert("Your calendar has \"\(overrideEvent?.title ?? overrideFocus.displayName)\" today — using that instead of the default rotation.", at: 0)
            return resolved
        }

        let nextIndex = program.days.isEmpty ? 0 : ((lastCompletedDayIndex ?? -1) + 1) % program.days.count
        guard let day = program.days[safe: nextIndex] else {
            return ResolvedProgramDay(focus: .restDay, resolvedExercises: [], isCalendarOverride: false, sourceCalendarEventIdentifier: nil, adjustmentNotes: ["No program configured — showing a rest day."], estimatedMinutes: 0)
        }
        return resolve(day: day, context: context)
    }

    /// Standalone "give me a short/equipment-limited session" path for the
    /// minimum user — bypasses the rotation entirely and builds a session
    /// directly from a focus + equipment override + a time cap. Never
    /// mutates the athlete's real profile, even when an equipment override
    /// is supplied.
    func resolveQuickSession(
        focus: SplitFocus,
        equipmentOverride: EquipmentProfile?,
        maxExercises: Int,
        athlete: Athlete
    ) -> ResolvedProgramDay {
        var context = ResolutionContext(athlete: athlete)
        if let equipmentOverride {
            context = context.overridingEquipment(equipmentOverride)
        }
        var day = adHocDay(for: focus, equipmentProfile: context.equipmentProfile)
        day.plannedExercises = Array(day.plannedExercises.prefix(maxExercises))
        var resolved = resolve(day: day, context: context)
        resolved.adjustmentNotes.insert("Quick session — \(maxExercises) exercise\(maxExercises == 1 ? "" : "s"), built for \(context.equipmentProfile.displayName.lowercased()).", at: 0)
        return resolved
    }

    // MARK: - Core resolution

    private func resolve(day: ProgramDay, context: ResolutionContext) -> ResolvedProgramDay {
        var notes: [String] = []
        let activeLimitations = context.activeLimitations

        let resolvedExercises: [ResolvedPlannedExercise] = day.plannedExercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { planned in
                guard let original = ExerciseCatalog.find(id: planned.exerciseID, customExercises: customExercises) else {
                    return nil
                }

                // 1. Injury/limitation check first — an excluded exercise
                // never even reaches equipment substitution.
                if let conflict = limitationConflict(for: original, limitations: activeLimitations) {
                    if conflict.severity.requiresExclusionRatherThanSubstitution {
                        if let alt = substitute(for: original, context: context, avoiding: conflict.area) {
                            notes.append("Swapped \(original.name) → \(alt.name): you reported \(conflict.severity.displayName.lowercased()) in your \(conflict.area.displayName.lowercased()).")
                            return ResolvedPlannedExercise(plannedExercise: planned, exercise: alt, wasSubstitutedFromExerciseID: original.id, substitutionReason: "limitation")
                        } else {
                            notes.append("Removed \(original.name): you reported \(conflict.severity.displayName.lowercased()) in your \(conflict.area.displayName.lowercased()). \(InjurySafetyLanguage.professionalCue)")
                            return nil
                        }
                    } else {
                        notes.append("Reduced load on \(original.name): you reported \(conflict.severity.displayName.lowercased()) in your \(conflict.area.displayName.lowercased()).")
                        return ResolvedPlannedExercise(plannedExercise: reducedLoad(planned), exercise: original, wasSubstitutedFromExerciseID: nil, substitutionReason: nil, loadReduced: true)
                    }
                }

                // 2. Equipment check.
                let available = context.equipmentProfile.availableEquipment
                let hasEquipment = original.equipmentRequired.isEmpty || original.equipmentRequired.contains { available.contains($0) }
                if !hasEquipment {
                    if let alt = substitute(for: original, context: context, avoiding: nil) {
                        notes.append("Swapped \(original.name) → \(alt.name): \(context.equipmentProfile.displayName) doesn't have the equipment for \(original.name).")
                        return ResolvedPlannedExercise(plannedExercise: planned, exercise: alt, wasSubstitutedFromExerciseID: original.id, substitutionReason: "equipment")
                    } else {
                        notes.append("Removed \(original.name): no equipment match and no substitute found in the catalog.")
                        return nil
                    }
                }

                return ResolvedPlannedExercise(plannedExercise: planned, exercise: original)
            }

        let estimatedMinutes = estimateMinutes(for: resolvedExercises)

        return ResolvedProgramDay(
            focus: day.focus,
            resolvedExercises: resolvedExercises,
            isCalendarOverride: false,
            sourceCalendarEventIdentifier: nil,
            adjustmentNotes: notes,
            estimatedMinutes: estimatedMinutes
        )
    }

    private func limitationConflict(for exercise: any ExerciseRepresentable, limitations: [BodyLimitation]) -> BodyLimitation? {
        limitations
            .filter { exercise.loadedBodyAreas.contains($0.area) }
            .sorted { $0.severity > $1.severity }
            .first
    }

    private func substitute(for exercise: any ExerciseRepresentable, context: ResolutionContext, avoiding area: BodyArea?) -> (any ExerciseRepresentable)? {
        if let easierID = exercise.easierAlternativeExerciseID,
           let easier = ExerciseCatalog.find(id: easierID, customExercises: customExercises),
           isUsable(easier, context: context, avoiding: area) {
            return easier
        }
        // Fall back to any catalog exercise sharing a muscle group that is
        // both equipment-available and doesn't load the area being avoided.
        let candidates = SeedData.exercises.filter { candidate in
            candidate.id != exercise.id
                && !Set(candidate.primaryMuscleGroups).isDisjoint(with: Set(exercise.primaryMuscleGroups))
                && isUsable(candidate, context: context, avoiding: area)
        }
        return candidates.first
    }

    private func isUsable(_ exercise: any ExerciseRepresentable, context: ResolutionContext, avoiding area: BodyArea?) -> Bool {
        let available = context.equipmentProfile.availableEquipment
        let equipmentOK = exercise.equipmentRequired.isEmpty || exercise.equipmentRequired.contains { available.contains($0) }
        let areaOK = area.map { !exercise.loadedBodyAreas.contains($0) } ?? true
        return equipmentOK && areaOK
    }

    private func reducedLoad(_ planned: PlannedExercise) -> PlannedExercise {
        var copy = planned
        copy.plannedSets = planned.plannedSets.map { set in
            var s = set
            if let weight = s.targetWeightKG {
                s.targetWeightKG = weight * 0.8
            }
            return s
        }
        return copy
    }

    private func estimateMinutes(for exercises: [ResolvedPlannedExercise]) -> Int {
        let totalSets = exercises.reduce(0) { $0 + $1.plannedExercise.plannedSets.count }
        // ~1.5 min working time + average rest per set — a rough estimate,
        // not a promise; shown as "about N minutes" in the UI.
        return max(10, totalSets * 3)
    }

    /// Builds a day on the fly for a focus with no explicit program entry
    /// (used for calendar overrides and quick-path sessions).
    private func adHocDay(for focus: SplitFocus, equipmentProfile: EquipmentProfile = .residentialGym) -> ProgramDay {
        let muscleGroups = SeedData.muscleGroups(for: focus)
        let candidates = SeedData.exercises.filter { !Set($0.primaryMuscleGroups).isDisjoint(with: Set(muscleGroups)) }
        let plannedExercises = candidates.enumerated().map { index, exercise in
            PlannedExercise(
                exerciseID: exercise.id,
                plannedSets: [
                    PlannedSet(setType: .working, targetRepRangeLow: 8, targetRepRangeHigh: 12, targetWeightKG: nil),
                    PlannedSet(setType: .working, targetRepRangeLow: 8, targetRepRangeHigh: 12, targetWeightKG: nil),
                    PlannedSet(setType: .working, targetRepRangeLow: 8, targetRepRangeHigh: 12, targetWeightKG: nil),
                ],
                orderIndex: index
            )
        }
        return ProgramDay(focus: focus, plannedExercises: plannedExercises, authoredForEquipmentProfile: equipmentProfile)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
