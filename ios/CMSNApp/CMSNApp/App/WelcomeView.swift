import SwiftUI

/// The cold-launch welcome/loading screen. Wraps `RootView` rather than
/// gating it behind a separate navigation state — `RootView` mounts
/// immediately underneath (so its SwiftData query is already warm by the
/// time the splash dismisses), fully hidden by the opaque black splash on
/// top until the reveal sequence finishes, then cross-fades away.
///
/// Deliberately quiet: a wordmark reveal and the tagline, nothing louder.
/// "Campaign-grade statements, black screen, white type" is the brand's own
/// description of this exact moment (`brand/05-content-and-community.md`) —
/// a spinner or progress bar would undercut it, and V0's local SwiftData
/// launch has nothing worth showing progress for anyway.
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
            CMSNColor.black.ignoresSafeArea()
            VStack(spacing: 20) {
                CMSNWordmark(height: 46, color: CMSNColor.offWhite)
                    .scaleEffect(showMark ? 1 : 0.92)
                    .opacity(showMark ? 1 : 0)
                EyebrowLabel(text: "Earn Your CMSN", color: CMSNColor.Semantic.textSecondary)
                    .opacity(showTagline ? 1 : 0)
            }
        }
    }

    private func runSequence() {
        withAnimation(.easeOut(duration: 0.7)) {
            showMark = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.55)) {
            showTagline = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            isFinished = true
        }
    }
}

#Preview {
    WelcomeView()
        .modelContainer(CMSNModelContainerFactory.makeInMemory())
        .environment(AppState(modelContainer: CMSNModelContainerFactory.makeInMemory()))
}
