import Foundation
import SwiftData

/// Versioned schema, per the technical requirement that migrations be
/// planned from V0 rather than retrofitted later. `V1` here is the app's
/// first shipped schema (unrelated to the product "V1/V2" roadmap naming —
/// this is SwiftData's own versioning vocabulary).
enum CMSNSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Athlete.self,
            CustomExercise.self,
            WorkoutSession.self,
            LoggedExercise.self,
            LoggedSet.self,
            ReadinessCheck.self,
            NutritionLog.self,
            NutritionEntry.self,
            ApparelFeedback.self,
            ScoreEvent.self,
        ]
    }
}

/// V2: the meal builder + supplement bank release. Adds SavedMeal /
/// SavedMealIngredient / CustomSupplement, and NutritionEntry gained an
/// optional `calories` — all additive, so the stage is lightweight.
enum CMSNSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        CMSNSchemaV1.models + [
            SavedMeal.self,
            SavedMealIngredient.self,
            CustomSupplement.self,
        ]
    }
}

enum CMSNMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [CMSNSchemaV1.self, CMSNSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: CMSNSchemaV1.self, toVersion: CMSNSchemaV2.self)]
    }
}

enum CMSNModelContainerFactory {
    /// The app's real, on-disk container. Kept as a single source of truth
    /// so `CMSNAppApp` and any future export/backup tooling agree on schema
    /// + migration plan.
    static func makeDefault() -> ModelContainer {
        let schema = Schema(versionedSchema: CMSNSchemaV2.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: CMSNMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            // A production app would surface a recovery path (export +
            // reset) rather than crash; V0 makes the failure loud during
            // development since silent data loss is worse than a crash here.
            fatalError("Failed to create CMSN persistent store: \(error)")
        }
    }

    /// In-memory container for previews and unit tests — never touches the
    /// real on-disk store.
    static func makeInMemory() -> ModelContainer {
        let schema = Schema(versionedSchema: CMSNSchemaV2.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, migrationPlan: CMSNMigrationPlan.self, configurations: [configuration])
        } catch {
            fatalError("Failed to create in-memory CMSN store: \(error)")
        }
    }
}
