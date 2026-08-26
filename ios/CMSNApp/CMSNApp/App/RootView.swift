import SwiftUI
import SwiftData

/// Decides the first-run narrative vs. the main app. V0 assumes exactly one
/// local athlete (see `AthleteRepository`) — the moment that profile exists
/// and `hasCompletedFirstRunNarrative` is true, every subsequent launch
/// skips straight to `MainTabView`. Gates on that field rather than
/// `hasCompletedOnboarding`: the profile wizard is only the middle of the
/// first-run narrative (see `OnboardingNarrativeView`), not the end of it.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    var body: some View {
        Group {
            if let athlete = athletes.first, athlete.hasCompletedFirstRunNarrative {
                MainTabView(athlete: athlete)
            } else {
                OnboardingNarrativeView(existingAthlete: athletes.first)
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
