import SwiftUI

@main
struct CMSNWatchApp: App {
    @StateObject private var run = WatchRunController()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(run)
        }
    }
}
