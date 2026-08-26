import Foundation
import SwiftData

/// Export and erase — the two data-rights actions Settings offers.
///
/// The app is local-first (no server, no account), so "your data" is
/// exactly what's in the on-device SwiftData store. Export serializes it
/// to human-readable JSON; erase deletes every model type and lets
/// `RootView`'s athlete gate drop the app back to first-run onboarding.
@MainActor
enum AccountDataService {
    // MARK: Export

    /// Writes a JSON export to a temp file and returns its URL for the
    /// share sheet. Built by hand rather than Codable conformance so the
    /// export shape stays stable even if model internals change.
    static func exportJSON(context: ModelContext) throws -> URL {
        var root: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "app": "CMSN",
            "format": 1,
        ]

        let iso = ISO8601DateFormatter()

        if let athlete = (try? context.fetch(FetchDescriptor<Athlete>()))?.first {
            root["profile"] = [
                "name": athlete.name ?? "",
                "age": athlete.age,
                "heightCM": athlete.heightCM,
                "weightKG": athlete.weightKG,
                "experience": athlete.experienceLevel.rawValue,
                "goals": athlete.goalTypesRaw,
                "equipment": athlete.equipmentProfile.rawValue,
                "trainingFrequencyPerWeek": athlete.trainingFrequencyPerWeek,
            ] as [String: Any]
        }

        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.date)]))) ?? []
        root["workoutSessions"] = sessions.map { session -> [String: Any] in
            [
                "date": iso.string(from: session.date),
                "focus": session.splitFocus.rawValue,
                "completed": session.isComplete,
                "exercises": session.loggedExercises.sorted { $0.orderIndex < $1.orderIndex }.map { exercise -> [String: Any] in
                    [
                        "name": exercise.exerciseNameSnapshot,
                        "sets": exercise.loggedSets.sorted { $0.setIndex < $1.setIndex }.map { set -> [String: Any] in
                            [
                                "reps": set.completedReps ?? 0,
                                "weightKG": set.completedWeightKG ?? 0,
                                "attempted": set.isAttempted,
                            ]
                        },
                    ]
                },
            ]
        }

        let logs = (try? context.fetch(FetchDescriptor<NutritionLog>(sortBy: [SortDescriptor(\.date)]))) ?? []
        root["nutrition"] = logs.map { log -> [String: Any] in
            [
                "date": iso.string(from: log.date),
                "proteinTarget": log.proteinGramsTarget,
                "entries": log.entries.sorted { $0.timestamp < $1.timestamp }.map { entry -> [String: Any] in
                    var dict: [String: Any] = [
                        "time": iso.string(from: entry.timestamp),
                        "label": entry.label,
                        "proteinGrams": entry.proteinGrams,
                    ]
                    if let carbs = entry.carbGrams { dict["carbGrams"] = carbs }
                    if let fat = entry.fatGrams { dict["fatGrams"] = fat }
                    if let kcal = entry.calories { dict["calories"] = kcal }
                    return dict
                },
            ]
        }

        let meals = (try? context.fetch(FetchDescriptor<SavedMeal>())) ?? []
        root["savedMeals"] = meals.map { meal -> [String: Any] in
            [
                "name": meal.name,
                "ingredients": meal.ingredients.sorted { $0.sortOrder < $1.sortOrder }.map { ingredient -> [String: Any] in
                    [
                        "name": ingredient.name,
                        "portion": ingredient.portionDescription,
                        "proteinGrams": ingredient.proteinGrams,
                        "carbGrams": ingredient.carbGrams,
                        "fatGrams": ingredient.fatGrams,
                        "calories": ingredient.calories,
                    ]
                },
            ]
        }

        let supplements = (try? context.fetch(FetchDescriptor<CustomSupplement>())) ?? []
        root["customSupplements"] = supplements.map { ["name": $0.name, "note": $0.note] }

        let scoreEvents = (try? context.fetch(FetchDescriptor<ScoreEvent>(sortBy: [SortDescriptor(\.date)]))) ?? []
        root["scoreEvents"] = scoreEvents.map { event -> [String: Any] in
            [
                "date": iso.string(from: event.date),
                "dimension": event.dimensionRaw,
                "points": event.points,
                "reason": event.reason,
            ]
        }

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-export-\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url)
        return url
    }

    // MARK: Erase (offboarding)

    /// Deletes every stored record. Irreversible; the confirmation lives in
    /// the UI, not here. After this, `RootView` sees no athlete and returns
    /// to the first-run narrative — the app behaves like a fresh install.
    static func eraseEverything(context: ModelContext) {
        // Child rows first isn't strictly required (cascades cover it), but
        // being explicit means no orphan survives a future rule change.
        try? context.delete(model: ScoreEvent.self)
        try? context.delete(model: ApparelFeedback.self)
        try? context.delete(model: ReadinessCheck.self)
        try? context.delete(model: LoggedSet.self)
        try? context.delete(model: LoggedExercise.self)
        try? context.delete(model: WorkoutSession.self)
        try? context.delete(model: NutritionEntry.self)
        try? context.delete(model: NutritionLog.self)
        try? context.delete(model: SavedMealIngredient.self)
        try? context.delete(model: SavedMeal.self)
        try? context.delete(model: CustomSupplement.self)
        try? context.delete(model: CustomExercise.self)
        try? context.delete(model: Athlete.self)
        try? context.save()
    }
}
