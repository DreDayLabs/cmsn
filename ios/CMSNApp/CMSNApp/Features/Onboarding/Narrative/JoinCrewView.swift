import SwiftUI

/// Transition screen before the existing profile-intake wizard
/// (`OnboardingFlowView`). New framing only — the wizard itself, and the
/// data it collects, are unchanged.
struct JoinCrewView: View {
    let onBegin: () -> Void

    private let previewSteps = ["Training profile", "Equipment access", "Injuries & limitations"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                EyebrowLabel(text: "Join the Crew")
                Text("JOIN THE\nCREW.")
                    .font(CMSNTypography.display(38))
                    .lineSpacing(-4)
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text("A few questions, then we build around you. Nothing here gates who this app is for.")
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .frame(maxWidth: 300, alignment: .leading)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 32)
            .padding(.top, 80)

            VStack(spacing: 0) {
                ForEach(Array(previewSteps.enumerated()), id: \.offset) { index, label in
                    HStack(spacing: 16) {
                        Text(String(format: "%02d", index + 1))
                            .font(CMSNTypography.displaySmall(18))
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                            .frame(width: 20, alignment: .leading)
                        Text(label)
                            .font(CMSNTypography.body())
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 18)
                    .overlay(alignment: .bottom) {
                        if index < previewSteps.count - 1 {
                            Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 44)

            Spacer()

            // No "skip for now" option: V0 assumes exactly one Athlete
            // profile exists once past onboarding (see AthleteRepository),
            // and every screen from Today onward reads it directly — there's
            // no supported partial/guest state to skip into.
            Button("Begin", action: onBegin)
                .buttonStyle(.cmsnPrimary)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(CMSNColor.offBlack.ignoresSafeArea())
    }
}

#Preview {
    JoinCrewView(onBegin: {})
}
