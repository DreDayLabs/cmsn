import Foundation
import SwiftData
import Observation

/// App-wide, cross-screen state: the one active program, the calendar
/// service, the suggestion engine, and the StoreKit manager. Screens read
/// this via `@Environment` rather than each constructing their own copy of
/// shared services — in particular, `CalendarSplitService` and
/// `StoreKitManager` hold real system state (EventKit auth, StoreKit
/// listeners) that must not be duplicated per-view.
@MainActor
@Observable
final class AppState {
    let modelContainer: ModelContainer
    let calendarService: CalendarSplitService
    let storeKitManager: StoreKitManager
    let suggestionEngine: SuggestionEngine

    /// The active training program. V0 ships two seed programs and lets the
    /// athlete pick one in onboarding; there's no custom program builder yet
    /// (that's V1 — see plan).
    var activeProgram: TrainingProgram

    init(modelContainer: ModelContainer, activeProgram: TrainingProgram = SeedData.pushPullLegs) {
        self.modelContainer = modelContainer
        self.calendarService = CalendarSplitService()
        self.storeKitManager = StoreKitManager()
        self.suggestionEngine = RuleBasedSuggestionEngine()
        self.activeProgram = activeProgram
    }

    var athleteRepository: AthleteRepository { AthleteRepository(context: modelContainer.mainContext) }
    var workoutRepository: WorkoutRepository { WorkoutRepository(context: modelContainer.mainContext) }
    var nutritionRepository: NutritionRepository { NutritionRepository(context: modelContainer.mainContext) }
    var scoreRepository: ScoreRepository { ScoreRepository(context: modelContainer.mainContext) }
}
