import SwiftUI

/// Today is Prepare/Perform/Prove (it owns the whole in-session flow via
/// navigation). Run is recorded running. Nutrition and Score are their own
/// tabs because they're checked independently of a workout. Library is the
/// education shelf. Settings holds the subscription entry point and profile.
/// Run Club is not a tab — see `RunClubNavigationSlot`.
///
/// Icons are chosen for brand register, not generic fitness-app chrome:
/// The Walk for Today, a book for the education library (never a pill),
/// a quiet mark for Score instead of a filled chart.
struct MainTabView: View {
    let athlete: Athlete
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            TodayView(athlete: athlete)
                .tabItem { Label("Today", systemImage: "figure.walk") }
                .tag(AppTab.today)

            RunHomeView(athlete: athlete)
                .tabItem { Label("Run", systemImage: "figure.run") }
                .tag(AppTab.run)

            NutritionLogView(athlete: athlete)
                .tabItem { Label("Nutrition", systemImage: "circle.grid.2x2") }
                .tag(AppTab.nutrition)

            ScoreView(athlete: athlete)
                .tabItem { Label("Score", systemImage: "diamond") }
                .tag(AppTab.score)

            EducationLibraryView()
                .tabItem { Label("Library", systemImage: "book") }
                .tag(AppTab.library)

            SettingsView(athlete: athlete)
                .tabItem { Label("Settings", systemImage: "line.3.horizontal") }
                .tag(AppTab.settings)
        }
        .tint(CMSNColor.offWhite)
    }
}
