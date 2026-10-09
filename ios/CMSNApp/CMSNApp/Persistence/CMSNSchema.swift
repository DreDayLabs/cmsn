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

/// The on-disk store could not be opened. The store files are left as they were.
struct StoreOpenFailure: Error, Equatable, LocalizedError {
    var message: String

    var errorDescription: String? { message }
}

/// Quarantine refused to run because there was nothing to move.
enum StoreQuarantineError: Error, Equatable, LocalizedError {
    /// No store file or SQLite sidecar exists at the live path.
    case nothingToMove

    var errorDescription: String? {
        switch self {
        case .nothingToMove:
            return "There was no store file to move. Nothing was deleted."
        }
    }
}

enum CMSNModelContainerFactory {
    /// The app's real, on-disk container. Kept as a single source of truth
    /// so `CMSNAppApp` and any future export/backup tooling agree on schema
    /// + migration plan.
    ///
    /// Throws `StoreOpenFailure` instead of crashing. The catch path does
    /// not delete, replace, or move the store — a failed open must not look
    /// like an empty account.
    static func makeDefault() throws -> ModelContainer {
        try open(defaultPersistentConfiguration())
    }

    /// In-memory container for previews and unit tests — never touches the
    /// real on-disk store. A failure here means the schema itself is invalid,
    /// not that an athlete's data is at risk, so it stays a hard failure.
    static func makeInMemory() -> ModelContainer {
        let schema = currentSchema()
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try open(configuration)
        } catch {
            fatalError("Failed to create in-memory CMSN store: \(error)")
        }
    }

    /// Same configuration `makeDefault()` opens, so quarantine targets the
    /// file the app actually uses.
    static func defaultPersistentConfiguration() -> ModelConfiguration {
        ModelConfiguration(schema: currentSchema(), isStoredInMemoryOnly: false)
    }

    /// On-disk configuration at an explicit URL. Used by tests that need a
    /// store outside the app container. The production path uses
    /// `defaultPersistentConfiguration()` so an existing install keeps its
    /// current file location.
    static func persistentConfiguration(storeURL: URL) -> ModelConfiguration {
        ModelConfiguration(schema: currentSchema(), url: storeURL)
    }

    static func open(_ configuration: ModelConfiguration) throws -> ModelContainer {
        let schema = configuration.schema ?? currentSchema()
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: CMSNMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            throw StoreOpenFailure(
                message: "CMSN couldn't open its saved data. Nothing was deleted. \(error.localizedDescription)"
            )
        }
    }

    /// The store file plus the SQLite WAL sidecars SwiftData writes beside it.
    static func relatedStoreURLs(for storeURL: URL) -> [URL] {
        let path = storeURL.path
        return [
            storeURL,
            URL(fileURLWithPath: path + "-wal"),
            URL(fileURLWithPath: path + "-shm"),
        ]
    }

    /// Moves the live store and its sidecars into a timestamped folder next
    /// to the store. This renames bytes; it does not delete them. Call only
    /// after the athlete confirms "start fresh". If a move fails partway,
    /// files already moved are put back on the live path.
    @discardableResult
    static func quarantinePersistentStore(
        at storeURL: URL,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> URL {
        let existing = relatedStoreURLs(for: storeURL).filter { fileManager.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { throw StoreQuarantineError.nothingToMove }

        let backupDir = backupDirectory(for: storeURL, now: now, fileManager: fileManager)
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

        var moved: [(from: URL, to: URL)] = []
        do {
            for url in existing {
                let destination = backupDir.appendingPathComponent(url.lastPathComponent)
                try fileManager.moveItem(at: url, to: destination)
                moved.append((url, destination))
            }
        } catch {
            for pair in moved.reversed() {
                try? fileManager.moveItem(at: pair.to, to: pair.from)
            }
            try? fileManager.removeItem(at: backupDir)
            throw error
        }
        return backupDir
    }

    /// A backup folder that does not already exist, so a second recovery in
    /// the same second cannot overwrite the first.
    static func backupDirectory(for storeURL: URL, now: Date, fileManager: FileManager = .default) -> URL {
        let folder = storeURL.deletingLastPathComponent()
            .appendingPathComponent("CMSNStoreBackups", isDirectory: true)
        let stamp = quarantineStamp(from: now)
        var candidate = folder.appendingPathComponent(stamp, isDirectory: true)
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(stamp)-\(suffix)", isDirectory: true)
            suffix += 1
        }
        return candidate
    }

    static func quarantineStamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func currentSchema() -> Schema {
        Schema(versionedSchema: CMSNSchemaV2.self)
    }
}
