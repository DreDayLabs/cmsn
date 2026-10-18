import SwiftUI

/// Today is Prepare/Perform/Prove (it owns the whole in-session flow via
/// navigation). Run is recorded running. Nutrition and Score are their own
/// tabs because they're checked independently of a workout. Library is the
/// education shelf. Settings holds the subscription entry point and profile.
/// Run Club is not a tab — see `RunClubNavigationSlot`.
///
/// Icons follow the approved v01 tab bar: a calendar for Today, a grid
/// for Nutrition, a diamond for Score, a book for the library, and lines
/// for Settings.
struct MainTabView: View {
    let athlete: Athlete
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            TodayView(athlete: athlete)
                .tabItem { Label("Today", systemImage: "calendar") }
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
        .toolbarBackground(CMSNColor.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
