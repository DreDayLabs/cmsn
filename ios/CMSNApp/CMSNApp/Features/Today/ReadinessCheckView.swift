import SwiftUI

/// Draft readiness inputs before they become a persisted `ReadinessCheck`.
/// Every field is a simple 1–5 scale or a coarse minute count — fast enough
/// to clear in a few taps, per the minimum-user requirement.
struct ReadinessDraft {
    var energyLevel: Int = 3
    var soreness: Int = 2
    var sleepQuality: Int = 3
    var motivation: Int = 3
    var availableMinutes: Int = 45
    var jointDiscomfortAreas: Set<BodyArea> = []

    func makeReadinessCheck() -> ReadinessCheck {
        ReadinessCheck(
            energyLevel: energyLevel,
            soreness: soreness,
            jointDiscomfortAreas: Array(jointDiscomfortAreas),
            sleepQuality: sleepQuality,
            motivation: motivation,
            availableMinutes: availableMinutes
        )
    }
}

/// The pre-session readiness check — fast, mostly-optional-feeling even
/// though every field has a sane default, so a rushed tap through it still
/// produces a reasonable readiness band.
struct ReadinessCheckView: View {
    @Binding var draft: ReadinessDraft
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            EyebrowLabel(text: "Before You Start")

            scaleRow(title: "Energy", value: $draft.energyLevel)
            scaleRow(title: "Soreness", value: $draft.soreness)
            scaleRow(title: "Sleep Quality", value: $draft.sleepQuality)
            scaleRow(title: "Motivation", value: $draft.motivation)

            HStack {
                Text("Time available").foregroundStyle(CMSNColor.Semantic.textPrimary)
                Spacer()
                Stepper("\(draft.availableMinutes) min", value: $draft.availableMinutes, in: 10...120, step: 5)
                    .fixedSize()
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
            }
            .font(CMSNTypography.body())

            Button("Ready — Let's Go") { onSubmit() }
                .buttonStyle(.cmsnPrimary)
        }
        .padding(20)
        .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
    }

    private func scaleRow(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
                Spacer()
                Text("\(value.wrappedValue)/5").font(CMSNTypography.numeric(14)).foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { level in
                    Rectangle()
                        .fill(level <= value.wrappedValue ? CMSNColor.offWhite : CMSNColor.Semantic.divider)
                        .frame(height: 6)
                        .onTapGesture { value.wrappedValue = level }
                }
            }
        }
    }
}
