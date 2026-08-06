import SwiftUI
import SwiftData

@main
struct CMSNAppApp: App {
    private let modelContainer: ModelContainer
    @State private var appState: AppState

    init() {
        let container = CMSNModelContainerFactory.makeDefault()
        modelContainer = container
        _appState = State(initialValue: AppState(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            WelcomeView()
                .environment(appState)
                .preferredColorScheme(.dark) // the brand is black/white-first; V0 doesn't ship a light theme
        }
        .modelContainer(modelContainer)
    }
}
