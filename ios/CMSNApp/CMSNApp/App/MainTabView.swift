import SwiftUI

/// The five-loop system, expressed as tabs: Today is Prepare/Perform/Prove
/// (it owns the whole in-session flow via navigation), Nutrition and Score
/// are their own tabs because they're checked independently of a workout,
/// Supplements is the static library, Settings holds the subscription
/// entry point and profile.
///
/// Icons are chosen for brand register, not generic fitness-app chrome:
/// The Walk for Today, a book for the education library (never a pill),
/// a quiet mark for Score instead of a filled chart.
struct MainTabView: View {
    let athlete: Athlete

    var body: some View {
        TabView {
            TodayView(athlete: athlete)
                .tabItem { Label("Today", systemImage: "figure.walk") }

            NutritionLogView(athlete: athlete)
                .tabItem { Label("Nutrition", systemImage: "circle.grid.2x2") }

            ScoreView(athlete: athlete)
                .tabItem { Label("Score", systemImage: "diamond") }

            SupplementLibraryView()
                .tabItem { Label("Library", systemImage: "book") }

            SettingsView(athlete: athlete)
                .tabItem { Label("Settings", systemImage: "line.3.horizontal") }
        }
        .tint(CMSNColor.offWhite)
    }
}
