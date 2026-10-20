import SwiftUI

/// The cold-launch welcome/loading screen. Wraps `RootView` rather than
/// gating it behind a separate navigation state — `RootView` mounts
/// immediately underneath (so its SwiftData query is already warm by the
/// time the splash dismisses), covered by the welcome film until the
/// reveal sequence finishes, then cross-fades away.
///
/// The film is the founder's welcome loop: a woman in the beige cropped
/// CMSN hoodie and high-waisted leggings. It holds long enough for the
/// hood to come off, then cross-fades into the app. No spinner — V0's
/// local SwiftData launch has nothing worth showing progress for.
struct WelcomeView: View {
    @State private var showMark = false
    @State private var showTagline = false
    @State private var isFinished = false

    var body: some View {
        ZStack {
            RootView()
                .opacity(isFinished ? 1 : 0)

            if !isFinished {
                splash
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: isFinished)
        .onAppear(perform: runSequence)
    }

    private var splash: some View {
        ZStack {
            CMSNFilmBackground(
                resourceName: CMSNVideo.welcomeName,
                resourceExtension: CMSNVideo.welcomeExtension,
                posterAssetName: CMSNVideo.welcomePoster,
                isActive: true,
                scrim: CMSNWelcomeFilm.scrim
            )
            VStack(spacing: 20) {
                CMSNWordmark(height: 46, color: CMSNColor.offWhite)
                    .scaleEffect(showMark ? 1 : 0.92)
                    .opacity(showMark ? 1 : 0)
                EyebrowLabel(text: "Earn Your CMSN", color: CMSNColor.Semantic.textSecondary)
                    .opacity(showTagline ? 1 : 0)
            }
            // The film does not take hits, so the splash itself has to,
            // or a tap falls through onto the app underneath.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
        }
    }

    private func runSequence() {
        withAnimation(.easeOut(duration: 0.7)) {
            showMark = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.55)) {
            showTagline = true
        }
        // The hood comes off and she stands around three seconds in.
        // Hold through that beat, then fade.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            isFinished = true
        }
    }
}

#Preview {
    WelcomeView()
        .modelContainer(CMSNModelContainerFactory.makeInMemory())
        .environment(AppState(modelContainer: CMSNModelContainerFactory.makeInMemory()))
}
