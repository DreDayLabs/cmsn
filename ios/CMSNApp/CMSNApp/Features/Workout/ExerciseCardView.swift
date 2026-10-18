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
        .cmsnCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(exercise.name)
                    .font(CMSNTypography.displaySmall(24))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Spacer(minLength: 12)
                Button("Swap") { onRequestSubstitution() }
                    .buttonStyle(.cmsnText)
                    .fixedSize()
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
                    .font(CMSNTypography.caption())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
        }
    }
}

/// One planned/logged set row. Partial completion is native here: reps can
/// be logged below the planned range and the set still saves as attempted.
///
/// The target ("8–12 reps") stays on one line at every Dynamic Type size.
/// `ViewThatFits` tries a single row, then two rows, then a stack. Candidates
/// above the fallback are fixed on the horizontal axis so a flexible spacer
/// cannot pretend to fit by crushing the target into a one-character column.
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
        VStack(alignment: .leading, spacing: 10) {
            if set.isAttempted {
                completedSummary
            } else {
                pendingEntry
                discomfortToggle
            }
        }
        .onAppear {
            if repsInput == 0 { repsInput = set.plannedRepRangeLow }
            if weightInput == 0 { weightInput = displayWeight(suggestedWeightKG ?? set.plannedWeightKG ?? 0) }
        }
    }

    private var pendingEntry: some View {
        ViewThatFits(in: .horizontal) {
            pendingRow.fixedSize(horizontal: true, vertical: false)
            pendingTwoLines.fixedSize(horizontal: true, vertical: false)
            pendingStacked
        }
    }

    private var pendingRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            setIdentity
            repsControl
            weightControl
            logButton
        }
    }

    private var pendingTwoLines: some View {
        VStack(alignment: .leading, spacing: 10) {
            setIdentity
            HStack(alignment: .bottom, spacing: 8) {
                repsControl
                weightControl
                logButton
            }
        }
    }

    /// Last resort for accessibility sizes. The target stays one line, and
    /// the controls stack under this set's own label.
    private var pendingStacked: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                setIdentity.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 2) {
                    setLabel
                    targetLabel
                }
            }
            repsControl
            HStack(alignment: .bottom, spacing: 8) {
                weightControl
                Spacer(minLength: 8)
                logButton
            }
        }
    }

    private var setIdentity: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            setLabel
            targetLabel
        }
    }

    private var setLabel: some View {
        Text("Set \(set.setIndex + 1)")
            .font(CMSNTypography.label())
            .foregroundStyle(CMSNColor.Semantic.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var targetLabel: some View {
        Text("\(set.plannedRepRangeLow)–\(set.plannedRepRangeHigh) reps")
            .font(CMSNTypography.numeric(17))
            .foregroundStyle(CMSNColor.Semantic.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityLabel("\(set.plannedRepRangeLow) to \(set.plannedRepRangeHigh) reps")
            .accessibilityIdentifier("workout.repTarget")
    }

    private var repsControl: some View {
        LabeledValueControl(title: "Reps") {
            HStack(spacing: 0) {
                stepButton(systemName: "minus", label: "Decrease reps") {
                    repsInput = max(0, repsInput - 1)
                }
                Text("\(repsInput)")
                    .font(CMSNTypography.numeric(17))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .frame(minWidth: 28)
                    .lineLimit(1)
                    .accessibilityLabel("Reps")
                    .accessibilityValue("\(repsInput)")
                stepButton(systemName: "plus", label: "Increase reps") {
                    repsInput = min(50, repsInput + 1)
                }
            }
        }
    }

    private var weightControl: some View {
        LabeledValueControl(title: "Weight") {
            HStack(spacing: 4) {
                TextField("0", value: $weightInput, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .font(CMSNTypography.numeric(17))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .lineLimit(1)
                    .accessibilityLabel("Weight")
                Text(unitPreference.weightUnitLabel)
                    .font(CMSNTypography.label())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var logButton: some View {
        Button("Log", action: logSet)
            .buttonStyle(.cmsnCompactPrimary)
    }

    private var discomfortToggle: some View {
        Button {
            discomfort.toggle()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: discomfort ? "checkmark.square" : "square")
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text("Felt discomfort on this set")
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .font(CMSNTypography.caption())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(discomfort ? .isSelected : AccessibilityTraits())
    }

    private var completedSummary: some View {
        ViewThatFits(in: .horizontal) {
            completedRow.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 6) {
                setLabel
                completedDetails
            }
        }
    }

    private var completedRow: some View {
        HStack(alignment: .center, spacing: 10) {
            setLabel
            completedDetails
        }
    }

    private var completedDetails: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("\(Int(displayWeight(set.completedWeightKG ?? 0))) \(unitPreference.weightUnitLabel) × \(set.completedReps ?? 0)")
                .font(CMSNTypography.numeric(17))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let rpe = set.rpe {
                Text("RPE \(String(format: "%.0f", rpe))")
                    .font(CMSNTypography.label())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .lineLimit(1)
            }
            if set.discomfortReported {
                Image(systemName: "bandage")
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .accessibilityLabel("Discomfort reported")
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .accessibilityLabel("Logged")
        }
    }

    private func stepButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .frame(minWidth: 36, minHeight: 36)
                .contentShape(Rectangle())
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

/// Caption over a single-line value. The stroke is white so the field
/// reads on the card instead of disappearing into the surface.
private struct LabeledValueControl<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CMSNTypography.label())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            content
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(
                    RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                        .strokeBorder(CMSNColor.Semantic.textPrimary, lineWidth: CMSNSpacing.hairline)
                )
        }
    }
}
