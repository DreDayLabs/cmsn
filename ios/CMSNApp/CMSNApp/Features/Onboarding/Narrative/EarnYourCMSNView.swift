import SwiftUI

/// The "about"/mission page — shown once, right after the profile wizard,
/// before the athlete builds their first week. Editorial register, matching
/// "The Word" content pillar in `brand/05-content-and-community.md`.
struct EarnYourCMSNView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Image("About")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    CMSNColor.offBlack.opacity(0.3),
                    CMSNColor.offBlack.opacity(0.26),
                    CMSNColor.offBlack.opacity(0.62),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "About")
                    Text("EARN YOUR\nCMSN.")
                        .font(CMSNTypography.display(44))
                        .lineSpacing(-6)
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                }

                Text("CMSN isn't given. It's what's left after the walk to the gym, the set you didn't skip, the rest day you respected. This app is the system of record for that work — before, during, and after.")
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .frame(maxWidth: 300, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 76)

            Spacer()

            Text("EARNED,\nNOT GIVEN.")
                .font(CMSNTypography.display(32))
                .multilineTextAlignment(.center)
                .lineSpacing(-2)
                .foregroundStyle(CMSNColor.Semantic.textPrimary)

            Spacer()

            Button("Continue", action: onContinue)
                .buttonStyle(.cmsnPrimary)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
}

#Preview {
    EarnYourCMSNView(onContinue: {})
}
