import SwiftUI
import SwiftData

/// One exercise's full in-session card: setup/cues/why-this-exercise up
/// top, then the set list. Every set logs immediately on tap — no
/// "finish workout to save" batching, per the offline-reliability rule.
struct ExerciseCardView: View {
    @Bindable var loggedExercise: LoggedExercise
    let exercise: any ExerciseRepresentable
    var position: Int = 1
    var exerciseCount: Int = 1
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
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(loggedExercise.loggedSets.sorted(by: { $0.setIndex < $1.setIndex })) { set in
                SetRowView(
                    set: set,
                    isActive: set.id == activeSetID,
                    suggestedWeightKG: suggestion.suggestedWeightKG,
                    unitPreference: unitPreference,
                    onLogged: { restSeconds in
                        try? modelContext.save()
                        onRestStart(restSeconds)
                    }
                )
            }
        }
    }

    private var activeSetID: UUID? {
        loggedExercise.loggedSets
            .sorted { $0.setIndex < $1.setIndex }
            .first { !$0.isAttempted }?
            .id
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercise \(position) of \(exerciseCount)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            HStack(alignment: .top, spacing: 12) {
                Text(exercise.name)
                    .font(CMSNTypography.display(40))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button {
                    onRequestSubstitution()
                } label: {
                    Text("Swap")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Capsule().fill(CMSNColor.Semantic.surfacePressed))
                }
                .buttonStyle(.plain)
            }
            Button(showingCues ? "Hide setup & cues" : "Setup & cues") {
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
                    .font(CMSNTypography.caption())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
        }
    }
}

/// One planned/logged set row. Partial completion is native here: reps can
/// be logged below the planned range and the set still saves as attempted.
private struct SetRowView: View {
    @Bindable var set: LoggedSet
    var isActive: Bool = false
    let suggestedWeightKG: Double?
    let unitPreference: UnitPreference
    let onLogged: (Int) -> Void

    @State private var repsInput: Int = 0
    @State private var weightInput: Double = 0
    @State private var rpeInput: Double = 8
    @State private var discomfort = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Set \(set.setIndex + 1)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Spacer(minLength: 8)
                Text("Target \(set.plannedRepRangeLow)–\(set.plannedRepRangeHigh) reps")
                    .font(.system(size: 14))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if set.isAttempted {
                loggedSummary
            } else {
                loggingControls
                Button {
                    discomfort.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: discomfort ? "circle.inset.filled" : "circle")
                        Text("Felt discomfort on this set")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Felt discomfort on this set")
                .accessibilityValue(discomfort ? "On" : "Off")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CMSNColor.Semantic.surface)
        )
        .onAppear {
            if repsInput == 0 { repsInput = set.plannedRepRangeLow }
            if weightInput == 0 { weightInput = displayWeight(suggestedWeightKG ?? set.plannedWeightKG ?? 0) }
        }
    }

    private var loggedSummary: some View {
        HStack(spacing: 10) {
            Text("\(set.completedReps ?? 0) × \(Int(displayWeight(set.completedWeightKG ?? 0))) \(unitPreference.weightUnitLabel)")
                .font(CMSNTypography.numeric(18))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            if let rpe = set.rpe {
                Text("RPE \(String(format: "%.0f", rpe))")
                    .font(.system(size: 13))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            if set.discomfortReported {
                Image(systemName: "bandage")
                    .foregroundStyle(CMSNColor.gray)
                    .accessibilityLabel("Discomfort reported")
            }
            Spacer()
            Image(systemName: "checkmark")
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .accessibilityLabel("Logged")
        }
    }

    private var loggingControls: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Reps")
                    .font(.system(size: 13))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                HStack(spacing: 8) {
                    stepButton(systemName: "minus", label: "Decrease reps") {
                        repsInput = max(0, repsInput - 1)
                    }
                    Text("\(repsInput)")
                        .font(CMSNTypography.numeric(20))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        .frame(minWidth: 28)
                    stepButton(systemName: "plus", label: "Increase reps") {
                        repsInput = min(50, repsInput + 1)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Weight")
                    .font(.system(size: 13))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                HStack(spacing: 6) {
                    TextField("0", value: $weightInput, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(CMSNTypography.numeric(18))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        .frame(width: 56, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(CMSNColor.black)
                        )
                        .accessibilityLabel("Weight")
                    Text(unitPreference.weightUnitLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
            }

            Spacer(minLength: 4)

            if isActive {
                Button("Log") { logSet() }
                    .buttonStyle(.cmsnCompactPrimary)
            } else {
                Button("Log") { logSet() }
                    .buttonStyle(.cmsnCompactQuiet)
            }
        }
    }

    private func stepButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(CMSNColor.black))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func logSet() {
        set.isAttempted = true
        set.completedReps = repsInput
        set.completedWeightKG = unitPreference.kilograms(fromDisplay: weightInput)
        set.rpe = rpeInput
        set.discomfortReported = discomfort
        set.loggedAt = Date()
        onLogged(currentPlannedRestSeconds())
    }

    private func currentPlannedRestSeconds() -> Int { 90 }

    private func displayWeight(_ kg: Double) -> Double {
        unitPreference.displayWeight(fromKilograms: kg).rounded()
    }
}
