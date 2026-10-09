import SwiftUI
import SwiftData

@main
struct CMSNAppApp: App {
    @State private var bootstrap = StoreBootstrap()

    var body: some Scene {
        WindowGroup {
            Group {
                switch bootstrap.phase {
                case .ready(let container, let appState):
                    WelcomeView()
                        .environment(appState)
                        .modelContainer(container)
                case .failed(let message):
                    StoreRecoveryView(
                        message: message,
                        onRetry: { bootstrap.retry() },
                        onStartFresh: { bootstrap.startFreshPreservingExistingStore() }
                    )
                }
            }
            .preferredColorScheme(.dark) // the brand is black/white-first; V0 doesn't ship a light theme
        }
    }
}
