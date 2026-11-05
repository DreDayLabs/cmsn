import SwiftUI

/// First screen of the first-run narrative — motivation, not mechanics.
/// Distinct from `WelcomeView` (the cold-launch splash every app open
/// shows briefly): this is a stop the user can actually read, with a
/// deliberate action, shown once, before onboarding begins.
struct NarrativeWelcomeView: View {
    let onContinue: () -> Void

    /// The cold-launch splash mounts this view at opacity 0. Starting the
    /// entrance then drops the delayed `showCTA` update, so "Get Started"
    /// stays at opacity 0 after the film fades and never appears to
    /// VoiceOver or the screenshot harness.
    @Environment(\.cmsnSplashFinished) private var splashFinished

    @State private var showMark = false
    @State private var showHeadline = false
    @State private var showSub = false
    @State private var showCTA = false
    @State private var didStartSequence = false

    var body: some View {
        ZStack {
            CMSNFilmBackground(
                resourceName: CMSNVideo.welcomeName,
                resourceExtension: CMSNVideo.welcomeExtension,
                posterAssetName: CMSNVideo.welcomePoster,
                isActive: true,
                scrim: CMSNWelcomeFilm.scrim
            )
            content
        }
        .onAppear(perform: runSequenceIfNeeded)
        .onChange(of: splashFinished) { _, _ in
            runSequenceIfNeeded()
        }
        .task(id: splashFinished) {
            runSequenceIfNeeded()
        }
    }

    private var content: some View {
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

            // The type block used to sit dead-centre, which put the headline
            // straight across the athlete's chest logo for most of the loop.
            // Capping the lower spacer forces the upper one to absorb the
            // remaining space, dropping the block into the lower third so the
            // chest mark reads clear above it.
            Spacer().frame(maxHeight: 56)

            // Inserted only once it should be visible. An opacity-0 button
            // is omitted from the accessibility tree, which is why the
            // screenshot harness reported that this CTA never appeared.
            ZStack {
                if showCTA {
                    Button("Get Started", action: onContinue)
                        .buttonStyle(.cmsnPrimary)
                        .accessibilityIdentifier("welcome.getStarted")
                        .accessibilityLabel("Get Started")
                        .transition(.opacity.combined(with: .offset(y: 14)))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .animation(.easeOut(duration: 0.6), value: showCTA)
        }
    }

    private func runSequenceIfNeeded() {
        guard splashFinished, !didStartSequence else { return }
        didStartSequence = true
        runSequence()
    }

    private func runSequence() {
        withAnimation(.easeOut(duration: 0.7)) { showMark = true }
        withAnimation(.easeOut(duration: 0.6).delay(0.35)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.6).delay(0.6)) { showSub = true }
        withAnimation(.easeOut(duration: 0.6).delay(0.85)) { showCTA = true }
        // If the delayed animation is discarded, still insert the CTA.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            showMark = true
            showHeadline = true
            showSub = true
            showCTA = true
        }
    }
}

#Preview {
    NarrativeWelcomeView(onContinue: {})
}
