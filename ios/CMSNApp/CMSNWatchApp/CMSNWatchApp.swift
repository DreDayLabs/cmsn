import SwiftUI

/// V0 scaffold only — not implemented. This target exists so the Xcode
/// project structure is in place for V1's real Watch companion (start
/// session, log set, rest timer, discomfort report — see the plan's
/// "Explicitly deferred to V1" list) without a project-restructure later.
@main
struct CMSNWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("CMSN").font(.headline)
            Text("Watch companion\ncoming in a future update.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
