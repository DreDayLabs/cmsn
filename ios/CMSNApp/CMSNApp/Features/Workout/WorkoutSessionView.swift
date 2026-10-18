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
        // Background ignores the safe area. The scroll view must not: on a
        // pushed screen the leading safe area is inset, and a ZStack sibling
        // that ignores it lays the first row out under that inset. The title
        // lives in the navigation bar. The form video stays in the scroll view.
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                CMSNVideoHero(height: 220, badge: nil) {
                    Text("Form video")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                }

                if let activeRestSeconds {
                    RestTimerView(totalSeconds: activeRestSeconds) {
                        self.activeRestSeconds = nil
                    }
                }

                if let session {
                    let exercises = session.loggedExercises.sorted(by: { $0.orderIndex < $1.orderIndex })
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, loggedExercise in
                        if let exercise = ExerciseCatalog.find(id: loggedExercise.exerciseID) {
                            ExerciseCardView(
                                loggedExercise: loggedExercise,
                                exercise: exercise,
                                position: index + 1,
                                exerciseCount: exercises.count,
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

                Button("Finish session") { finishSession() }
                    .buttonStyle(.cmsnGhost)
                    .accessibilityLabel("Finish Session")
                    .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerRelativeFrame(.horizontal, alignment: .leading)
        }
        .background(CMSNColor.Semantic.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(CMSNColor.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("\(resolvedDay.focus.displayName) · Let's work")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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

    private func buildSession() {
        if let existing = appState.workoutRepository.openSession() {
            // Resume the abandoned in-progress session instead of building
            // a duplicate — starting fresh here would orphan any real work
            // already logged against it.
            session = existing
            return
        }

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
        // Consistency credit is for showing up and doing real work, not for
        // creating-then-immediately-ending an empty session.
        if session.hasAnyLoggedWork {
            events.append(contentsOf: ScoreCalculator.eventsForOnScheduleConsistency(sessionID: session.id))
        }
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
