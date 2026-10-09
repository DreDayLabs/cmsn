import Foundation

/// One glance at today: the session, the fuel still open, and the single
/// next action. Pure on purpose so the home states can be tested without
/// SwiftUI or a simulator.
///
/// Action order is train, then fuel, then the reason. A planned session
/// that is not finished yet is always "Start Workout", even when the diary
/// is empty or already past a target. After that, an empty diary or protein
/// still open (and calories not past the estimate) is "Log Food". Once
/// protein is met, or either target is past, the action is "Read Why".
///
/// This type does not estimate energy. Targets and the "why" come from
/// `TrainingDayAdjustment` (Mifflin–St Jeor, 2024 Adult Compendium NET METs,
/// ACSM 2016, ISSN 2017, NIH fat AMDR). What's left comes from
/// `RemainingMacros`. Minutes on a finished session are the clock from
/// start to finish, not a guessed burn. "About N min" on a planned session
/// is `ProgramResolver`'s existing rough schedule estimate.
struct TodayHomeState: Equatable {
    enum Phase: Equatable {
        case preWorkout
        case postWorkout
        case restDay
        case noProgram
    }

    enum Fuel: Equatable {
        case nothingLogged
        case withinTarget
        case overTarget
    }

    enum PrimaryAction: Equatable {
        case startWorkout
        case logFood
        case readWhy

        var title: String {
            switch self {
            case .startWorkout: return "Start Workout"
            case .logFood: return "Log Food"
            case .readWhy: return "Read Why"
            }
        }
    }

    enum SessionFocus: Equatable {
        case planned(TodayPlannedSession)
        case inProgress(TodayLoggedWork)
        case finished([TodayLoggedWork])
        case rest
        case noProgram
    }

    var phase: Phase
    var fuel: Fuel
    var primaryAction: PrimaryAction
    var session: SessionFocus
    var headline: String
    var sessionEyebrow: String
    var sessionTitle: String
    var sessionDetail: String
    var sessionLines: [String]
    var sessionNotes: [String]
    var fuelEyebrow: String
    var fuelFigure: String
    var fuelCaption: String
    var fuelDetail: String
    var fuelNote: String
    var showsReadinessCheck: Bool
    var showsRecoveryLog: Bool
    /// Education-library slug from Slice A. This screen does not open that library.
    var articleID: String
    var adjustment: TrainingDayAdjustment
    var remaining: RemainingMacros

    static func resolve(
        hasProgram: Bool,
        plan: TodayPlannedSession?,
        logged: [TodayLoggedWork],
        adjustment: TrainingDayAdjustment,
        remaining: RemainingMacros
    ) -> TodayHomeState {
        let finished = logged.filter { $0.isComplete && $0.attemptedSets > 0 }
        let open = logged.filter { !$0.isComplete }
        let phase = phase(hasProgram: hasProgram, plan: plan, finished: finished, open: open)
        let session = sessionFocus(plan: plan, finished: finished, open: open, phase: phase)
        let fuel = fuelState(remaining)
        let action = primaryAction(phase: phase, fuel: fuel, remaining: remaining)
        let protein = proteinCopy(remaining: remaining, fuel: fuel)

        return TodayHomeState(
            phase: phase,
            fuel: fuel,
            primaryAction: action,
            session: session,
            headline: headline(for: session),
            sessionEyebrow: sessionEyebrow(for: session),
            sessionTitle: sessionTitle(for: session),
            sessionDetail: sessionDetail(for: session),
            sessionLines: sessionLines(for: session),
            sessionNotes: sessionNotes(for: session, plan: plan, open: open),
            fuelEyebrow: "Fuel",
            fuelFigure: protein.figure,
            fuelCaption: protein.caption,
            fuelDetail: fuelDetail(remaining: remaining, adjustment: adjustment),
            fuelNote: fuelNote(adjustment: adjustment, remaining: remaining, fuel: fuel),
            showsReadinessCheck: phase == .preWorkout,
            showsRecoveryLog: phase == .restDay || featuredFocus(session) == .recovery,
            articleID: adjustment.articleID,
            adjustment: adjustment,
            remaining: remaining
        )
    }

    /// Sessions the home should consider.
    ///
    /// Finished work counts only when it ended today. An open session counts
    /// even if it started on an earlier day, because starting again resumes
    /// the newest unfinished session instead of building a second one. Older
    /// open sessions are left out; only the newest one would resume.
    static func loggedWork(
        on day: Date,
        from sessions: [WorkoutSession],
        calendar: Calendar = .current
    ) -> [TodayLoggedWork] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let finishedToday = sessions.filter { session in
            guard let ended = session.endedAt else { return false }
            return ended >= start && ended < end
        }
        let newestOpen = sessions
            .filter { $0.endedAt == nil }
            .max { $0.date < $1.date }

        var chosen: [WorkoutSession] = finishedToday
        if let newestOpen, !chosen.contains(where: { $0.id == newestOpen.id }) {
            chosen.append(newestOpen)
        }
        return chosen
            .sorted { $0.date < $1.date }
            .map { TodayLoggedWork($0) }
    }

    // MARK: - Phase

    private static func phase(
        hasProgram: Bool,
        plan: TodayPlannedSession?,
        finished: [TodayLoggedWork],
        open: [TodayLoggedWork]
    ) -> Phase {
        if !finished.isEmpty { return .postWorkout }
        if !open.isEmpty { return .preWorkout }
        if !hasProgram { return .noProgram }
        if let plan, isTrainable(plan) { return .preWorkout }
        return .restDay
    }

    /// Rest has no session to start. An empty recovery day is the same.
    /// A recovery day that still has exercises is a session, so it stays
    /// in the pre-workout path and keeps the recovery log beside it.
    private static func isTrainable(_ plan: TodayPlannedSession) -> Bool {
        if plan.focus == .restDay { return false }
        if plan.focus == .recovery && plan.exerciseNames.isEmpty { return false }
        return true
    }

    private static func sessionFocus(
        plan: TodayPlannedSession?,
        finished: [TodayLoggedWork],
        open: [TodayLoggedWork],
        phase: Phase
    ) -> SessionFocus {
        switch phase {
        case .postWorkout:
            return .finished(finished)
        case .preWorkout:
            if let current = open.first {
                return .inProgress(current)
            }
            if let plan {
                return .planned(plan)
            }
            return .noProgram
        case .noProgram:
            return .noProgram
        case .restDay:
            return .rest
        }
    }

    private static func featuredFocus(_ session: SessionFocus) -> SplitFocus? {
        switch session {
        case .planned(let plan): return plan.focus
        case .inProgress(let work): return work.focus
        case .finished(let works): return works.count == 1 ? works.first?.focus : nil
        case .rest, .noProgram: return nil
        }
    }

    // MARK: - Fuel and action

    static func fuelState(_ remaining: RemainingMacros) -> Fuel {
        if !remaining.hasLoggedFood { return .nothingLogged }
        if remaining.proteinRemainingGrams.rounded() < 0 || remaining.caloriesRemaining.rounded() < 0 {
            return .overTarget
        }
        return .withinTarget
    }

    /// Train first. Then log food while protein is still open and calories
    /// are not past the estimate. Otherwise read the reason.
    static func primaryAction(phase: Phase, fuel: Fuel, remaining: RemainingMacros) -> PrimaryAction {
        if phase == .preWorkout { return .startWorkout }
        if fuel == .nothingLogged { return .logFood }
        if fuel == .overTarget { return .readWhy }
        if remaining.proteinRemainingGrams.rounded() > 0 && remaining.caloriesRemaining.rounded() >= 0 {
            return .logFood
        }
        return .readWhy
    }

    // MARK: - Session copy

    private static func headline(for session: SessionFocus) -> String {
        switch session {
        case .planned(let plan):
            return plan.focus.displayName.uppercased()
        case .inProgress(let work):
            return work.focus.displayName.uppercased()
        case .finished(let works):
            if works.count == 1, let only = works.first {
                return only.focus.displayName.uppercased()
            }
            return "TRAINED"
        case .rest:
            return "REST DAY"
        case .noProgram:
            return "TODAY"
        }
    }

    private static func sessionEyebrow(for session: SessionFocus) -> String {
        switch session {
        case .planned(let plan):
            return plan.isCalendarOverride ? "From Your Calendar" : "Planned"
        case .inProgress:
            return "In Progress"
        case .finished(let works):
            return works.count > 1 ? "Logged Today" : "Finished"
        case .rest:
            return "Rest Day"
        case .noProgram:
            return "Program"
        }
    }

    private static func sessionTitle(for session: SessionFocus) -> String {
        switch session {
        case .planned(let plan):
            return plan.focus.displayName
        case .inProgress(let work):
            return work.focus.displayName
        case .finished(let works):
            return works.count == 1 ? (works.first?.focus.displayName ?? "Trained") : "Trained"
        case .rest:
            return "No Session"
        case .noProgram:
            return "No Program"
        }
    }

    private static func sessionDetail(for session: SessionFocus) -> String {
        switch session {
        case .planned(let plan):
            if plan.exerciseNames.isEmpty {
                return "No exercises matched this session."
            }
            return "\(exercisePhrase(plan.exerciseNames.count)) · about \(plan.estimatedMinutes) min"
        case .inProgress(let work):
            if work.attemptedSets == 0 {
                return "Started, nothing logged yet. Starting again resumes this session."
            }
            return "\(setPhrase(attempted: work.attemptedSets, planned: work.plannedSets)) logged. Starting again resumes this session."
        case .finished(let works):
            return finishedDetail(works)
        case .rest:
            return "Nothing is planned. Fuel stays on the day with no training added."
        case .noProgram:
            return "No rotation is set, so there is no session to start."
        }
    }

    private static func sessionLines(for session: SessionFocus) -> [String] {
        switch session {
        case .planned(let plan):
            return plan.exerciseNames.map { "· \($0)" }
        case .inProgress(let work):
            return work.exerciseNames.map { "· \($0)" }
        case .finished(let works):
            if works.count == 1, let only = works.first {
                return only.exerciseNames.map { "· \($0)" }
            }
            return works.map { work in
                var line = "· \(work.focus.displayName): \(work.attemptedSets)/\(work.plannedSets)"
                if let minutes = work.minutes, minutes > 0 {
                    line += " · \(minutes) min"
                }
                return line
            }
        case .rest, .noProgram:
            return []
        }
    }

    private static func sessionNotes(for session: SessionFocus, plan: TodayPlannedSession?, open: [TodayLoggedWork]) -> [String] {
        var notes: [String] = []
        if case .planned = session {
            notes.append(contentsOf: plan?.notes ?? [])
        }
        if case .finished = session, !open.isEmpty {
            notes.append("A session is still open. Starting a workout resumes it.")
        }
        return notes
    }

    private static func finishedDetail(_ works: [TodayLoggedWork]) -> String {
        let attempted = works.reduce(0) { $0 + $1.attemptedSets }
        let planned = works.reduce(0) { $0 + $1.plannedSets }
        let sets = setPhrase(attempted: attempted, planned: planned)
        let minuteValues = works.compactMap(\.minutes).filter { $0 > 0 }
        let minutesSuffix: String
        if minuteValues.count == works.count, !minuteValues.isEmpty {
            let total = minuteValues.reduce(0, +)
            minutesSuffix = " · \(total) min"
        } else {
            minutesSuffix = ""
        }
        if works.count > 1 {
            return "\(works.count) sessions · \(sets)\(minutesSuffix)"
        }
        return "\(sets)\(minutesSuffix)"
    }

    private static func exercisePhrase(_ count: Int) -> String {
        count == 1 ? "1 exercise" : "\(count) exercises"
    }

    private static func setPhrase(attempted: Int, planned: Int) -> String {
        let noun = planned == 1 ? "set" : "sets"
        return "\(attempted) of \(planned) \(noun)"
    }

    // MARK: - Fuel copy

    private static func proteinCopy(remaining: RemainingMacros, fuel: Fuel) -> (figure: String, caption: String) {
        if fuel == .nothingLogged || !remaining.hasLoggedFood {
            return ("\(whole(remaining.proteinTargetGrams))g", "protein today")
        }
        let left = remaining.proteinRemainingGrams
        if left.rounded() < 0 {
            return ("\(whole(abs(left)))g over", "today's protein")
        }
        if left.rounded() == 0 {
            return ("\(whole(remaining.proteinTargetGrams))g", "protein target met")
        }
        return ("\(whole(left))g", "protein left")
    }

    /// Carb and fat are the day's targets. `RemainingMacros` does not
    /// subtract them, so this line does not invent carb or fat "left".
    private static func fuelDetail(remaining: RemainingMacros, adjustment: TrainingDayAdjustment) -> String {
        let targets = adjustment.adjusted
        let macros = "\(whole(targets.carbGrams))g carb target · \(whole(targets.fatGrams))g fat target"
        return "\(caloriePhrase(remaining)) · \(macros)"
    }

    private static func caloriePhrase(_ remaining: RemainingMacros) -> String {
        if !remaining.hasLoggedFood {
            return "~\(whole(remaining.calorieTarget)) kcal"
        }
        let left = remaining.caloriesRemaining
        if left.rounded() < 0 {
            return "\(whole(abs(left))) kcal over today's estimate"
        }
        if left.rounded() == 0 {
            return "on today's calorie estimate"
        }
        return "\(whole(left)) kcal left"
    }

    private static func fuelNote(adjustment: TrainingDayAdjustment, remaining: RemainingMacros, fuel: Fuel) -> String {
        var parts: [String] = []
        if adjustment.targetsChanged {
            parts.append("Today's training is included in these targets.")
        } else {
            parts.append("These targets are unchanged.")
        }
        if fuel == .nothingLogged {
            parts.append("Nothing logged yet. What's left is this full target.")
        } else {
            parts.append("\(whole(remaining.proteinLoggedGrams))g protein logged of \(whole(remaining.proteinTargetGrams))g.")
        }
        if remaining.entriesMissingCalories > 0 {
            parts.append("Some foods have no calories recorded, so the calorie line only counts what was entered.")
        }
        parts.append("Sources for these targets are on the card below.")
        return parts.joined(separator: " ")
    }

    private static func whole(_ value: Double) -> Int {
        Int(value.rounded())
    }
}

/// The planned day, reduced to what the home renders. Built from
/// `ProgramResolver` / `CalendarSplitService` output.
struct TodayPlannedSession: Equatable {
    var focus: SplitFocus
    var exerciseNames: [String]
    var estimatedMinutes: Int
    var isCalendarOverride: Bool
    var notes: [String]
}

extension TodayPlannedSession {
    init(_ day: ResolvedProgramDay) {
        focus = day.focus
        exerciseNames = day.resolvedExercises.map { $0.exercise.name }
        estimatedMinutes = day.estimatedMinutes
        isCalendarOverride = day.isCalendarOverride
        notes = day.adjustmentNotes
    }
}

/// One logged session, reduced to what the home renders.
struct TodayLoggedWork: Equatable, Identifiable {
    var id: UUID
    var focus: SplitFocus
    var exerciseNames: [String]
    var attemptedSets: Int
    var plannedSets: Int
    /// Clock minutes from start to finish. `nil` when the session has no
    /// finish time, or the clock rounds to under a minute. Not an energy estimate.
    var minutes: Int?
    var isComplete: Bool
}

extension TodayLoggedWork {
    init(_ session: WorkoutSession) {
        id = session.id
        focus = session.splitFocus
        let exercises = session.loggedExercises.sorted { $0.orderIndex < $1.orderIndex }
        exerciseNames = exercises.map(\.exerciseNameSnapshot)
        let sets = exercises.flatMap(\.loggedSets)
        attemptedSets = sets.filter(\.isAttempted).count
        plannedSets = sets.count
        if let ended = session.endedAt, ended > session.date {
            let rounded = Int((ended.timeIntervalSince(session.date) / 60).rounded())
            minutes = rounded > 0 ? rounded : nil
        } else {
            minutes = nil
        }
        isComplete = session.isComplete
    }
}
