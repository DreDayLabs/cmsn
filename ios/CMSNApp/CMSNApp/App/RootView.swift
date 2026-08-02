import SwiftUI
import SwiftData

/// Decides Onboarding vs. the main app. V0 assumes exactly one local
/// athlete (see `AthleteRepository`) — the moment that profile exists and
/// `hasCompletedOnboarding` is true, every subsequent launch skips straight
/// to `MainTabView`.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    var body: some View {
        Group {
            if let athlete = athletes.first, athlete.hasCompletedOnboarding {
                MainTabView(athlete: athlete)
            } else {
                OnboardingFlowView(existingAthlete: athletes.first)
            }
        }
        .tint(CMSNColor.offWhite)
    }
}

#Preview {
    RootView()
        .modelContainer(CMSNModelContainerFactory.makeInMemory())
        .environment(AppState(modelContainer: CMSNModelContainerFactory.makeInMemory()))
}
