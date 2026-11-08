import SwiftUI
import SwiftData

/// Always available. Free users choose and log their own exercises; the paid
/// resolver/suggestion engine is never invoked to create a manual workout.
struct FreeTrainingView: View {
    let athlete: Athlete
    @Environment(AppState.self) private var appState
    @State private var started = false
    @State private var showingRecovery = false
    private var manualDay: ResolvedProgramDay {
        ResolvedProgramDay(focus: .fullBody, resolvedExercises: [], isCalendarOverride: false,
                           sourceCalendarEventIdentifier: nil, adjustmentNotes: [], estimatedMinutes: 0)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your training. Your record.")
                .font(CMSNTypography.displaySmall(36)).foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text("Choose your exercises, log your sets, and keep your complete history.")
                .font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textSecondary)
            Button(appState.workoutRepository.openSession() == nil ? "Log a workout" : "Resume session") { started = true }
                .buttonStyle(.cmsnPrimary).accessibilityIdentifier("free.startWorkout")
            Button("Log recovery day") { showingRecovery = true }.buttonStyle(.cmsnGhost)
            PlusFeature(capability: .planning, title: "Sessions planned around your equipment") { EmptyView() }
        }
        .sheet(isPresented: $showingRecovery) { RecoveryLogView() }
        .navigationDestination(isPresented: $started) {
            WorkoutSessionView(resolvedDay: manualDay, readiness: ReadinessDraft().makeReadinessCheck(), athlete: athlete, manualMode: true)
        }
    }
}

/// Unconditionally readable, including all prior coaching explanations.
struct WorkoutHistoryView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var coaching: [PlusSessionRecord]
    var body: some View {
        List(sessions) { session in
            NavigationLink {
                List {
                    Text(session.date.formatted())
                    ForEach(session.loggedExercises.sorted { $0.orderIndex < $1.orderIndex }) { exercise in
                        Section(exercise.exerciseNameSnapshot) {
                            ForEach(exercise.loggedSets.sorted { $0.setIndex < $1.setIndex }) { set in
                                Text("Set \(set.setIndex + 1): \(set.completedReps.map(String.init) ?? "—") reps · \(set.completedWeightKG.map { String(format: "%.1f kg", $0) } ?? "—")")
                                if let saved = coaching.first(where: { $0.sessionID == session.id })?.explanations[set.id.uuidString] {
                                    Text(saved.rationale).font(.caption)
                                }
                            }
                        }
                    }
                }.navigationTitle("Workout record")
            } label: {
                VStack(alignment: .leading) {
                    Text(session.splitFocus.displayName)
                    Text(session.date.formatted()).font(.caption)
                }
            }
        }.navigationTitle("Workout history")
    }
}
