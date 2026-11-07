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
            "app": "CMSN Performance",
            "format": 2,
        ]

        let iso = ISO8601DateFormatter()

        if let athlete = (try? context.fetch(FetchDescriptor<Athlete>()))?.first {
            var profile: [String: Any] = [
                "name": athlete.name ?? "",
                "age": athlete.age,
                "heightCM": athlete.heightCM,
                "weightKG": athlete.weightKG,
                "experience": athlete.experienceLevel.rawValue,
                "goals": athlete.goalTypesRaw,
                "equipment": athlete.equipmentProfile.rawValue,
                "trainingFrequencyPerWeek": athlete.trainingFrequencyPerWeek,
            ]
            if let diets = (try? context.fetch(FetchDescriptor<NutritionDietPreference>()))?
                .first(where: { $0.athleteID == athlete.id }) {
                profile["restrictiveDietIDs"] = diets.dietIDsRaw
                if let window = diets.fastingWindowRaw {
                    profile["fastingWindow"] = window
                }
            }
            root["profile"] = profile
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

        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.recordedAt)]))) ?? []
        root["weightEntries"] = weights.map { entry -> [String: Any] in
            [
                "date": iso.string(from: entry.recordedAt),
                "weightKG": entry.weightKG,
            ]
        }

        let runs = (try? context.fetch(FetchDescriptor<Run>(sortBy: [SortDescriptor(\.startedAt)]))) ?? []
        root["runs"] = runs.filter { $0.status == .ended }.map { run -> [String: Any] in
            var dict: [String: Any] = [
                "startedAt": iso.string(from: run.startedAt),
                "environment": run.environment.rawValue,
                "source": run.source.rawValue,
                "distanceMeters": run.distanceMeters,
                "movingSeconds": run.movingSeconds,
                "elevationGainMeters": run.elevationGainMeters,
                "calories": run.calories,
                "notes": run.notes,
                "photoAttached": run.photoJPEG != nil,
            ]
            if let ended = run.endedAt { dict["endedAt"] = iso.string(from: ended) }
            if let heart = run.averageHeartRate { dict["averageHeartRate"] = heart }
            if let ground = run.ground { dict["ground"] = ground.rawValue }
            if let effort = run.effort { dict["effort"] = effort.rawValue }
            if let mood = run.mood { dict["mood"] = mood.rawValue }
            return dict
        }

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

    /// Shown in Settings when the erase cannot be saved. Support and the
    /// privacy page use this same sentence. It is a string, so it is not
    /// isolated to the main actor.
    nonisolated static let deleteSaveFailedMessage = "Couldn't erase your data. Nothing was confirmed deleted."

    /// Deletes every stored record. Irreversible once `save` succeeds; the
    /// confirmation lives in the UI, not here. After a successful save,
    /// `RootView` sees no athlete and returns to the first-run narrative.
    ///
    /// Rows are deleted one object at a time with autosave off, then `save`
    /// is the commit. `ModelContext.delete(model:)` is a batch delete.
    /// On the in-memory container at `383a817`, that batch plus `rollback()`
    /// still fetched zero athletes (`PrivacyReliabilityTests` line 83).
    /// Pending per-object deletes are what `rollback()` can discard.
    /// A failed save therefore leaves the last successful save in place.
    /// That is the guarantee behind `deleteSaveFailedMessage`.
    static func eraseEverything(
        context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() },
        rollback: (ModelContext) -> Void = { $0.rollback() }
    ) throws {
        let autosaveWasEnabled = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosaveWasEnabled }
        // Child rows first isn't strictly required (cascades cover it), but
        // being explicit means no orphan survives a future rule change.
        do {
            try deleteFetched(ChallengeEntry.self, in: context)
            try deleteFetched(Challenge.self, in: context)
            try deleteFetched(ClubMembership.self, in: context)
            try deleteFetched(RunClub.self, in: context)
            try deleteFetched(RunSplit.self, in: context)
            try deleteFetched(RunRoute.self, in: context)
            try deleteFetched(Run.self, in: context)
            try deleteFetched(RunShoe.self, in: context)
            try deleteFetched(RunSettings.self, in: context)
            try deleteFetched(ScoreEvent.self, in: context)
            try deleteFetched(ApparelFeedback.self, in: context)
            try deleteFetched(ReadinessCheck.self, in: context)
            try deleteFetched(LoggedSet.self, in: context)
            try deleteFetched(LoggedExercise.self, in: context)
            try deleteFetched(WorkoutSession.self, in: context)
            try deleteFetched(NutritionEntry.self, in: context)
            try deleteFetched(NutritionLog.self, in: context)
            try deleteFetched(SavedMealIngredient.self, in: context)
            try deleteFetched(SavedMeal.self, in: context)
            try deleteFetched(CustomSupplement.self, in: context)
            try deleteFetched(CustomExercise.self, in: context)
            try deleteFetched(WeightEntry.self, in: context)
            try deleteFetched(WeightHistorySeedMarker.self, in: context)
            try deleteFetched(NutritionDietPreference.self, in: context)
            try deleteFetched(Athlete.self, in: context)
            try save(context)
        } catch {
            rollback(context)
            throw error
        }
    }

    /// Stages one `context.delete(_:)` per row. Not `delete(model:)`.
    private static func deleteFetched<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let rows = try context.fetch(FetchDescriptor<T>())
        for row in rows {
            context.delete(row)
        }
    }
}
