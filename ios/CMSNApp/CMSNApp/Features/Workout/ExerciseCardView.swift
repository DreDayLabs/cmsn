import SwiftUI
import SwiftData

/// One exercise's full in-session card: setup/cues/why-this-exercise up
/// top, then the set list. Every set logs immediately on tap — no
/// "finish workout to save" batching, per the offline-reliability rule.
struct ExerciseCardView: View {
    @Bindable var loggedExercise: LoggedExercise
    let exercise: any ExerciseRepresentable
    let suggestionEngine: SuggestionEngine
    let recentHistory: [LoggedSet]
    let readiness: ReadinessBand
    let unitPreference: UnitPreference
    let onRequestSubstitution: () -> Void
    let onRestStart: (Int) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showingCues = false

    private var nextPlannedSet: PlannedSet {
        let firstUnattempted = loggedExercise.loggedSets.first(where: { !$0.isAttempted })
        let setIndex = firstUnattempted?.setIndex ?? 0
        let template = loggedExercise.loggedSets.first(where: { $0.setIndex == setIndex })
        return PlannedSet(
            setType: template?.setType ?? .working,
            targetRepRangeLow: template?.plannedRepRangeLow ?? 8,
            targetRepRangeHigh: template?.plannedRepRangeHigh ?? 12,
            targetWeightKG: template?.plannedWeightKG
        )
    }

    private var suggestion: SetSuggestion {
        suggestionEngine.suggestNextSet(
            plannedSet: nextPlannedSet,
            exercise: exercise,
            recentHistory: recentHistory,
            readiness: readiness,
            unitPreference: unitPreference
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if showingCues {
                cuesSection
            }

            Text(suggestion.rationale)
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)

            ForEach(loggedExercise.loggedSets.sorted(by: { $0.setIndex < $1.setIndex })) { set in
                SetRowView(
                    set: set,
                    suggestedWeightKG: suggestion.suggestedWeightKG,
                    unitPreference: unitPreference,
                    onLogged: { restSeconds in
                        try? modelContext.save()
                        onRestStart(restSeconds)
                    }
                )
            }
        }
        .padding(20)
        .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise.name)
                    .font(CMSNTypography.displaySmall(24))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Spacer()
                Button("Swap") { onRequestSubstitution() }.buttonStyle(.cmsnText)
            }
            Button(showingCues ? "Hide setup & cues" : "Show setup & cues") {
                showingCues.toggle()
            }
            .buttonStyle(.cmsnText)
        }
    }

    private var cuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.whyThisExercise).font(CMSNTypography.bodyQuiet()).foregroundStyle(CMSNColor.Semantic.textSecondary)
            Text(exercise.setupInstructions).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
            ForEach(exercise.formCues, id: \.self) { cue in
                Text("· \(cue)").font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
            }
            Text("Common mistake: \(exercise.commonMistake)")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.gray)
            if exercise.demonstrationVideoAssetName == nil {
                Text("Video demo coming in a future update — for now, follow the setup notes above.")
                    .font(.system(size: 11))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
        }
    }
}

/// One planned/logged set row. Partial completion is native here: reps can
/// be logged below the planned range and the set still saves as attempted.
private struct SetRowView: View {
    @Bindable var set: LoggedSet
    let suggestedWeightKG: Double?
    let unitPreference: UnitPreference
    let onLogged: (Int) -> Void

    @State private var repsInput: Int = 0
    @State private var weightInput: Double = 0
    @State private var rpeInput: Double = 8
    @State private var discomfort = false

    var body: some View {
        HStack(spacing: 12) {
            Text("Set \(set.setIndex + 1)")
                .font(CMSNTypography.numeric(15))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .frame(width: 56, alignment: .leading)

            if set.isAttempted {
                Text("\(displayWeight(set.completedWeightKG ?? 0))×\(set.completedReps ?? 0)")
                    .font(CMSNTypography.numeric(16))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                if let rpe = set.rpe {
                    Text("RPE \(String(format: "%.0f", rpe))").font(CMSNTypography.bodyQuiet()).foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                Spacer()
                Image(systemName: "checkmark").foregroundStyle(CMSNColor.Semantic.scorePositive)
            } else {
                Text("\(set.plannedRepRangeLow)–\(set.plannedRepRangeHigh) reps")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                Spacer()
                Stepper("\(repsInput)", value: $repsInput, in: 0...50).fixedSize()
                TextField("wt", value: $weightInput, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Button("Log") {
                    logSet()
                }
                .buttonStyle(.cmsnGhost)
                .fixedSize()
            }
        }
        .onAppear {
            if repsInput == 0 { repsInput = set.plannedRepRangeLow }
            if weightInput == 0 { weightInput = displayWeight(suggestedWeightKG ?? set.plannedWeightKG ?? 0) }
        }
    }

    private func logSet() {
        set.isAttempted = true
        set.completedReps = repsInput
        set.completedWeightKG = unitPreference == .imperial ? weightInput / 2.2046226 : weightInput
        set.rpe = rpeInput
        set.discomfortReported = discomfort
        set.loggedAt = Date()
        onLogged(currentPlannedRestSeconds())
    }

    private func currentPlannedRestSeconds() -> Int { 90 }

    private func displayWeight(_ kg: Double) -> Double {
        unitPreference == .imperial ? (kg * 2.2046226).rounded() : kg.rounded()
    }
}
