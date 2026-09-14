import SwiftUI

/// The five-loop system, expressed as tabs: Today is Prepare/Perform/Prove
/// (it owns the whole in-session flow via navigation), Nutrition and Score
/// are their own tabs because they're checked independently of a workout,
/// Supplements is the static library, Settings holds the subscription
/// entry point and profile.
struct MainTabView: View {
    let athlete: Athlete

    var body: some View {
        TabView {
            TodayView(athlete: athlete)
                .tabItem { Label("Today", systemImage: "figure.strengthtraining.traditional") }

            NutritionLogView(athlete: athlete)
                .tabItem { Label("Nutrition", systemImage: "fork.knife") }

            ScoreView(athlete: athlete)
                .tabItem { Label("Score", systemImage: "chart.bar.fill") }

            SupplementLibraryView()
                .tabItem { Label("Supplements", systemImage: "pills") }

            SettingsView(athlete: athlete)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(CMSNColor.offWhite)
    }
}
