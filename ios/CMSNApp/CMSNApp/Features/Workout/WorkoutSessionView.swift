import SwiftUI
import SwiftData

/// Perform. Builds a real `WorkoutSession` + `LoggedExercise`/`LoggedSet`
/// rows the moment the session starts (not when it ends) so partial
/// completion is never at risk of being lost, then hosts one
/// `ExerciseCardView` per exercise in a scroll list.
struct WorkoutSessionView: View {
    let resolvedDay: ResolvedProgramDay
    let readiness: ReadinessCheck
    let athlete: Athlete
    /// Passed through from `TodayView` so "return after inactivity" scoring
    /// reflects the gap that existed *before* this session, not zero.
    var daysInactiveAtStart: Int? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var session: WorkoutSession?
    @State private var substitutionTarget: LoggedExercise?
    @State private var activeRestSeconds: Int?
    @State private var navigateToSummary = false
    @State private var completedScoreBreakdown: ScoreBreakdown?

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let activeRestSeconds {
                        RestTimerView(totalSeconds: activeRestSeconds) {
                            self.activeRestSeconds = nil
                        }
                    }

                    if let session {
                        ForEach(session.loggedExercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { loggedExercise in
                            if let exercise = ExerciseCatalog.find(id: loggedExercise.exerciseID) {
                                ExerciseCardView(
                                    loggedExercise: loggedExercise,
                                    exercise: exercise,
                                    suggestionEngine: appState.suggestionEngine,
                                    recentHistory: appState.workoutRepository.loggedSets(forExerciseID: loggedExercise.exerciseID, limit: 5),
                                    readiness: readiness.readinessBand,
                                    unitPreference: athlete.unitPreference,
                                    onRequestSubstitution: { substitutionTarget = loggedExercise },
                                    onRestStart: { seconds in activeRestSeconds = seconds }
                                )
                            }
                        }
                    }

                    Button("Finish Session") { finishSession() }
                        .buttonStyle(.cmsnPrimary)
                }
                .padding(24)
            }
        }
        .navigationDestination(isPresented: $navigateToSummary) {
            if let session, let completedScoreBreakdown {
                SessionSummaryView(session: session, scoreBreakdown: completedScoreBreakdown, athlete: athlete)
            }
        }
        .sheet(item: $substitutionTarget) { loggedExercise in
            if let original = ExerciseCatalog.find(id: loggedExercise.exerciseID) {
                SubstitutionPicker(original: original, equipmentProfile: athlete.equipmentProfile) { replacement in
                    substitute(loggedExercise, with: replacement)
                }
            }
        }
        .task {
            if session == nil { buildSession() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowLabel(text: resolvedDay.focus.displayName)
            Text("Let's Work")
                .font(CMSNTypography.displaySmall(36))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }

    private func buildSession() {
        let newSession = WorkoutSession(
            splitFocus: resolvedDay.focus,
            equipmentProfileUsed: athlete.equipmentProfile,
            sourceCalendarEventIdentifier: resolvedDay.sourceCalendarEventIdentifier
        )
        readiness.session = newSession
        newSession.readiness = readiness

        newSession.loggedExercises = resolvedDay.resolvedExercises.enumerated().map { index, resolved in
            let loggedSets = resolved.plannedExercise.plannedSets.enumerated().map { setIndex, planned in
                LoggedSet(
                    setIndex: setIndex,
                    setType: planned.setType,
                    plannedRepRangeLow: planned.targetRepRangeLow,
                    plannedRepRangeHigh: planned.targetRepRangeHigh,
                    plannedWeightKG: planned.targetWeightKG
                )
            }
            return LoggedExercise(
                exerciseID: resolved.exercise.id,
                exerciseNameSnapshot: resolved.exercise.name,
                orderIndex: index,
                wasSubstitutedFromExerciseID: resolved.wasSubstitutedFromExerciseID,
                loggedSets: loggedSets
            )
        }

        appState.workoutRepository.createSession(newSession)
        session = newSession
    }

    private func substitute(_ loggedExercise: LoggedExercise, with replacement: Exercise) {
        loggedExercise.wasSubstitutedFromExerciseID = loggedExercise.exerciseID
        loggedExercise.exerciseID = replacement.id
        loggedExercise.exerciseNameSnapshot = replacement.name
        appState.workoutRepository.saveImmediately()
    }

    private func finishSession() {
        guard let session else { return }
        session.endedAt = Date()

        var events = ScoreCalculator.events(forSession: session, previousBestE1RMByExercise: previousBestE1RMByExercise(excluding: session))
        events.append(contentsOf: ScoreCalculator.eventsForOnScheduleConsistency(sessionID: session.id))
        if let daysInactiveAtStart, daysInactiveAtStart >= 7 {
            events.append(contentsOf: ScoreCalculator.eventsForReturnAfterInactivity(daysInactive: daysInactiveAtStart, sessionID: session.id))
        }

        appState.scoreRepository.record(events)
        appState.workoutRepository.saveImmediately()

        completedScoreBreakdown = ScoreCalculator.compositeScore(from: events)
        navigateToSummary = true
    }

    private func previousBestE1RMByExercise(excluding currentSession: WorkoutSession) -> [String: Double] {
        var result: [String: Double] = [:]
        for exercise in currentSession.loggedExercises {
            let history = appState.workoutRepository.loggedSets(forExerciseID: exercise.exerciseID, limit: 50)
                .filter { $0.exercise?.session?.id != currentSession.id }
            let best = history.compactMap { set -> Double? in
                guard let reps = set.completedReps, let weight = set.completedWeightKG else { return nil }
                return OneRepMaxEstimator.epley(weight: weight, reps: reps)
            }.max() ?? 0
            result[exercise.exerciseID] = best
        }
        return result
    }
}
