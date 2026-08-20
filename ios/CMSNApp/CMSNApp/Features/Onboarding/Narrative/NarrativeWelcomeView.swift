import SwiftUI

/// First screen of the first-run narrative — motivation, not mechanics.
/// Distinct from `WelcomeView` (the cold-launch splash every app open
/// shows briefly): this is a stop the user can actually read, with a
/// deliberate action, shown once, before onboarding begins.
struct NarrativeWelcomeView: View {
    let onContinue: () -> Void

    @State private var showMark = false
    @State private var showHeadline = false
    @State private var showSub = false
    @State private var showCTA = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                CMSNWordmark(height: 46, color: CMSNColor.offWhite)
                    .opacity(showMark ? 1 : 0)
                    .offset(y: showMark ? 0 : 14)

                VStack(spacing: 18) {
                    Text("EARN YOUR\nCMSN.")
                        .font(CMSNTypography.display(40))
                        .multilineTextAlignment(.center)
                        .lineSpacing(-4)
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        .opacity(showHeadline ? 1 : 0)
                        .offset(y: showHeadline ? 0 : 14)

                    Text("Nobody hands this out. You put in the work — the app just keeps score.")
                        .font(CMSNTypography.body())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        .frame(maxWidth: 280)
                        .opacity(showSub ? 1 : 0)
                        .offset(y: showSub ? 0 : 14)
                }
            }
            .padding(.horizontal, 40)
            Spacer()

            Button("Get Started", action: onContinue)
                .buttonStyle(.cmsnPrimary)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(showCTA ? 1 : 0)
                .offset(y: showCTA ? 0 : 14)
        }
        .background(CMSNColor.offBlack.ignoresSafeArea())
        .onAppear(perform: runSequence)
    }

    private func runSequence() {
        withAnimation(.easeOut(duration: 0.7)) { showMark = true }
        withAnimation(.easeOut(duration: 0.6).delay(0.35)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.6).delay(0.6)) { showSub = true }
        withAnimation(.easeOut(duration: 0.6).delay(0.85)) { showCTA = true }
    }
}

#Preview {
    NarrativeWelcomeView(onContinue: {})
}
