import Foundation
import SwiftData

// MARK: - Program templates (Codable value types — the "plan", not the "log")

/// One planned set within a planned exercise. Templates, not history — the
/// actual logged outcome lives in `LoggedSet` below, which is intentionally
/// a separate type so a planned 3×8–12 can diverge from what really happened
/// without mutating the plan.
struct PlannedSet: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var setType: SetType = .working
    var targetRepRangeLow: Int
    var targetRepRangeHigh: Int
    /// `nil` means "let the suggestion engine propose it" — the common case
    /// for a working set after the first session on record.
    var targetWeightKG: Double?
    var restSeconds: Int = 90
}

struct PlannedExercise: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var exerciseID: String
    var plannedSets: [PlannedSet]
    var supersetGroupID: String? = nil
    var orderIndex: Int
}

struct ProgramDay: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var focus: SplitFocus
    var plannedExercises: [PlannedExercise]
    /// Equipment profile(s) this day was authored for; `ProgramResolver`
    /// swaps exercises when the athlete's active profile doesn't match.
    var authoredForEquipmentProfile: EquipmentProfile
}

/// A named rotation of `ProgramDay`s (e.g. Push/Pull/Legs). `SeedData` ships
/// a couple of these; V1 adds a custom program builder.
struct TrainingProgram: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var days: [ProgramDay]
}

// MARK: - Logged history (SwiftData models — mutable, the actual record)

/// A single completed-or-partial workout. Partial completion is native: a
/// session with zero fully-completed sets is still a valid, saved,
/// score-contributing `WorkoutSession` — never coerced into "didn't happen."
@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var splitFocus: SplitFocus
    var equipmentProfileUsed: EquipmentProfile
    var notes: String
    /// `nil` while in progress; set the moment the user ends the session
    /// (whether everything planned was completed or not).
    var endedAt: Date?
    /// The calendar event (if any) that determined today's focus — lets
    /// `ProgramResolver`/analytics distinguish "calendar override" days from
    /// "default rotation" days.
    var sourceCalendarEventIdentifier: String?

    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.session)
    var loggedExercises: [LoggedExercise]

    @Relationship(deleteRule: .cascade, inverse: \ReadinessCheck.session)
    var readiness: ReadinessCheck?

    @Relationship(deleteRule: .cascade, inverse: \ApparelFeedback.session)
    var apparelFeedback: ApparelFeedback?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        splitFocus: SplitFocus,
        equipmentProfileUsed: EquipmentProfile,
        notes: String = "",
        endedAt: Date? = nil,
        sourceCalendarEventIdentifier: String? = nil,
        loggedExercises: [LoggedExercise] = []
    ) {
        self.id = id
        self.date = date
        self.splitFocus = splitFocus
        self.equipmentProfileUsed = equipmentProfileUsed
        self.notes = notes
        self.endedAt = endedAt
        self.sourceCalendarEventIdentifier = sourceCalendarEventIdentifier
        self.loggedExercises = loggedExercises
    }

    var isComplete: Bool { endedAt != nil }

    /// True only once a set has actually been attempted — used by
    /// Return-state logic to distinguish "opened the app" from "did
    /// something." NOT merely whether placeholder `LoggedSet` rows exist:
    /// `WorkoutSessionView` pre-creates every planned set (unattempted) the
    /// moment a session starts, so checking array emptiness here would make
    /// every session count as "worked" the instant it's opened.
    var hasAnyLoggedWork: Bool {
        loggedExercises.contains { $0.loggedSets.contains { $0.isAttempted } }
    }
}

@Model
final class LoggedExercise {
    @Attribute(.unique) var id: UUID
    var exerciseID: String
    /// Denormalized name snapshot — history must still read correctly if the
    /// catalog entry is later renamed or removed.
    var exerciseNameSnapshot: String
    var orderIndex: Int
    var wasSubstitutedFromExerciseID: String?

    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.exercise)
    var loggedSets: [LoggedSet]

    init(
        id: UUID = UUID(),
        exerciseID: String,
        exerciseNameSnapshot: String,
        orderIndex: Int,
        wasSubstitutedFromExerciseID: String? = nil,
        loggedSets: [LoggedSet] = []
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.orderIndex = orderIndex
        self.wasSubstitutedFromExerciseID = wasSubstitutedFromExerciseID
        self.loggedSets = loggedSets
    }
}

/// The core partial-completion-native record. `plannedReps`/`plannedWeightKG`
/// capture the target; `completedReps`/`completedWeightKG` capture reality —
/// they are allowed to differ, including "attempted but 0 reps" (`isAttempted
/// == true, completedReps == 0`) vs. "never reached" (`isAttempted == false`).
/// Both states are saved immediately on entry, not batched to session end.
@Model
final class LoggedSet {
    @Attribute(.unique) var id: UUID
    var setIndex: Int
    var setType: SetType
    var plannedRepRangeLow: Int
    var plannedRepRangeHigh: Int
    var plannedWeightKG: Double?

    var isAttempted: Bool
    var completedReps: Int?
    var completedWeightKG: Double?
    var rpe: Double?

    var discomfortReported: Bool
    var discomfortBodyArea: BodyArea?

    var loggedAt: Date

    var exercise: LoggedExercise?

    init(
        id: UUID = UUID(),
        setIndex: Int,
        setType: SetType = .working,
        plannedRepRangeLow: Int,
        plannedRepRangeHigh: Int,
        plannedWeightKG: Double?,
        isAttempted: Bool = false,
        completedReps: Int? = nil,
        completedWeightKG: Double? = nil,
        rpe: Double? = nil,
        discomfortReported: Bool = false,
        discomfortBodyArea: BodyArea? = nil,
        loggedAt: Date = Date()
    ) {
        self.id = id
        self.setIndex = setIndex
        self.setType = setType
        self.plannedRepRangeLow = plannedRepRangeLow
        self.plannedRepRangeHigh = plannedRepRangeHigh
        self.plannedWeightKG = plannedWeightKG
        self.isAttempted = isAttempted
        self.completedReps = completedReps
        self.completedWeightKG = completedWeightKG
        self.rpe = rpe
        self.discomfortReported = discomfortReported
        self.discomfortBodyArea = discomfortBodyArea
        self.loggedAt = loggedAt
    }

    /// A set counts as "hit" for PR/progression math only if it was
    /// attempted with a recorded rep count — a partial 7-of-10 still counts
    /// at 7 reps, it just isn't a "hit the top of the range" set.
    var isWithinPlannedRange: Bool {
        guard let reps = completedReps else { return false }
        return reps >= plannedRepRangeLow
    }
}
