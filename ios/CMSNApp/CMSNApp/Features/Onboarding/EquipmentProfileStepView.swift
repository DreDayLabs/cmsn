import SwiftUI

/// Step 2: where the athlete actually trains. First-class in onboarding
/// (not buried in settings) because it's the input that resolves "I only
/// have dumbbells" — see `ProgramResolver`.
struct EquipmentProfileStepView: View {
    @Binding var draft: OnboardingDraft
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    EyebrowLabel(text: "Step 2 of 3")
                    Text("Where Do You Train?")
                        .font(CMSNTypography.displaySmall(34))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                }

                ForEach(EquipmentProfile.allCases) { profile in
                    Button {
                        draft.equipmentProfile = profile
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(profile.displayName)
                                    .font(CMSNTypography.body())
                                Spacer()
                                if draft.equipmentProfile == profile {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            Text(profile.summary)
                                .font(CMSNTypography.bodyQuiet())
                                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        }
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        .padding(16)
                        .overlay(
                            Rectangle().strokeBorder(
                                draft.equipmentProfile == profile ? CMSNColor.offWhite : CMSNColor.Semantic.divider,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 16) {
                    Button("Back") { onBack() }.buttonStyle(.cmsnGhost)
                    Button("Continue") { onNext() }.buttonStyle(.cmsnPrimary)
                }
            }
            .padding(24)
        }
        .background(CMSNColor.offBlack.ignoresSafeArea())
    }
}
