import SwiftUI

/// Step 1: the physiological + training-shape inputs. One form, no
/// gender-exclusive branching — `biologicalSexForCalculation` is presented
/// plainly as "used only for the calorie estimate," never as an identity
/// question, and "prefer not to say" is a fully first-class option.
struct TrainingProfileStepView: View {
    @Binding var draft: OnboardingDraft
    let onNext: () -> Void

    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 10
    @State private var weightLbs: Double = 180

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                fieldGroup(title: "About You") {
                    Stepper("Age: \(draft.age)", value: $draft.age, in: 13...90)
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)

                    HStack {
                        Text("Height").foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Spacer()
                        Picker("Feet", selection: $heightFeet) {
                            ForEach(3...7, id: \.self) { Text("\($0) ft").tag($0) }
                        }
                        Picker("Inches", selection: $heightInches) {
                            ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                        }
                    }
                    .onChange(of: heightFeet) { updateHeight() }
                    .onChange(of: heightInches) { updateHeight() }

                    HStack {
                        Text("Weight").foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Spacer()
                        TextField("lbs", value: $weightLbs, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Text("lb").foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                    .onChange(of: weightLbs) { draft.weightKG = weightLbs / 2.2046226 }

                    Picker("Used only for the calorie estimate", selection: $draft.biologicalSexForCalculation) {
                        Text("Prefer not to say").tag(BiologicalSexForCalculation.preferNotToSay)
                        Text("Male").tag(BiologicalSexForCalculation.male)
                        Text("Female").tag(BiologicalSexForCalculation.female)
                    }
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                }

                fieldGroup(title: "Goals") {
                    goalToggleGrid
                }

                fieldGroup(title: "Experience & Availability") {
                    Picker("Experience", selection: $draft.experienceLevel) {
                        ForEach(ExperienceLevel.allCases) { Text($0.displayName).tag($0) }
                    }
                    Stepper("Training \(draft.trainingFrequencyPerWeek)x/week", value: $draft.trainingFrequencyPerWeek, in: 0...7)
                    Stepper("Session length: \(draft.preferredSessionLengthMinutes) min", value: $draft.preferredSessionLengthMinutes, in: 10...120, step: 5)
                }
                .foregroundStyle(CMSNColor.Semantic.textPrimary)

                fieldGroup(title: "Preferred Styles") {
                    styleToggleGrid
                }

                Button("Continue") { onNext() }
                    .buttonStyle(.cmsnPrimary)
            }
            .padding(24)
        }
        .onAppear { updateHeight(); draft.weightKG = weightLbs / 2.2046226 }
        .background(CMSNColor.offBlack.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Step 1 of 3")
            Text("Your Training Profile")
                .font(CMSNTypography.displaySmall(34))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }

    private var goalToggleGrid: some View {
        FlowToggleGrid(items: GoalType.allCases, isOn: { draft.goalTypes.contains($0) }, label: \.displayName) { goal in
            if draft.goalTypes.contains(goal) { draft.goalTypes.remove(goal) } else { draft.goalTypes.insert(goal) }
        }
    }

    private var styleToggleGrid: some View {
        FlowToggleGrid(items: TrainingStyle.allCases, isOn: { draft.preferredStyles.contains($0) }, label: \.displayName) { style in
            if draft.preferredStyles.contains(style) { draft.preferredStyles.remove(style) } else { draft.preferredStyles.insert(style) }
        }
    }

    private func updateHeight() {
        let totalInches = Double(heightFeet * 12 + heightInches)
        draft.heightCM = totalInches * 2.54
    }

    @ViewBuilder
    private func fieldGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: title)
            content()
        }
    }
}

/// Simple wrapping multi-select grid used for goal types and training
/// styles — generic over any `Hashable` case list.
struct FlowToggleGrid<Item: Hashable>: View {
    let items: [Item]
    let isOn: (Item) -> Bool
    let label: (Item) -> String
    let toggle: (Item) -> Void

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    toggle(item)
                } label: {
                    Text(label(item))
                        .font(CMSNTypography.eyebrow())
                        .kerning(1.2)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(isOn(item) ? CMSNColor.offBlack : CMSNColor.Semantic.textPrimary)
                        .background(isOn(item) ? CMSNColor.offWhite : Color.clear)
                        .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
