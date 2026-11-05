import SwiftData
import XCTest
@testable import CMSNApp

/// A store written by an earlier build whose model shape matches none of
/// the declared schema versions must still open, keep its rows, and leave
/// a copy of the original bytes behind.
@MainActor
final class StoreUpgradeTests: XCTestCase {
    func testUnknownVersionStoreUpgradesWithoutDataLoss() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-upgrade-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("default.store")

        // "Prior build": every current model except the seed marker, written
        // without a migration plan, so its hash matches no VersionedSchema.
        let priorModels = CMSNSchemaV5.models.filter { ObjectIdentifier($0) != ObjectIdentifier(WeightHistorySeedMarker.self) }
        let priorSchema = Schema(priorModels)
        let athleteID = UUID()
        do {
            let prior = try ModelContainer(for: priorSchema, configurations: [ModelConfiguration(schema: priorSchema, url: storeURL)])
            let context = ModelContext(prior)
            context.insert(WeightEntry(athleteID: athleteID, weightKG: 81.5))
            try context.save()
        }

        let container = try CMSNModelContainerFactory.open(
            CMSNModelContainerFactory.persistentConfiguration(storeURL: storeURL)
        )
        let entries = try ModelContext(container).fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.athleteID, athleteID)
        XCTAssertEqual(entries.first?.weightKG, 81.5)
        // New table is usable after the upgrade.
        _ = try ModelContext(container).fetch(FetchDescriptor<WeightHistorySeedMarker>())
    }

    func testCurrentStoreReopensCleanly() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-reopen-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = CMSNModelContainerFactory.persistentConfiguration(storeURL: root.appendingPathComponent("default.store"))
        do {
            let c = try CMSNModelContainerFactory.open(config)
            let ctx = ModelContext(c)
            ctx.insert(WeightEntry(athleteID: UUID(), weightKG: 70))
            try ctx.save()
        }
        let reopened = try CMSNModelContainerFactory.open(config)
        XCTAssertEqual(try ModelContext(reopened).fetchCount(FetchDescriptor<WeightEntry>()), 1)
    }

    func testResetArgumentIsOptIn() {
        XCTAssertEqual(CMSNModelContainerFactory.resetFirstRunArgument, "-CMSNResetFirstRun")
        XCTAssertFalse(CMSNModelContainerFactory.shouldResetPersistentStore(arguments: []))
        XCTAssertFalse(CMSNModelContainerFactory.shouldResetPersistentStore(arguments: ["-AppleLanguages", "(en)"]))
        XCTAssertTrue(
            CMSNModelContainerFactory.shouldResetPersistentStore(
                arguments: ["CMSNApp", "-CMSNResetFirstRun"]
            )
        )
    }

    func testResetRemovesStoreSidecars() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-reset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = root.appendingPathComponent("default.store")
        try Data("store".utf8).write(to: store)
        try Data("wal".utf8).write(to: URL(fileURLWithPath: store.path + "-wal"))
        try Data("journal".utf8).write(to: URL(fileURLWithPath: store.path + "-journal"))
        CMSNModelContainerFactory.resetPersistentStore(at: store)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.path + "-wal"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.path + "-journal"))
    }

    func testBackupCopiesWithoutMoving() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = root.appendingPathComponent("default.store")
        try Data("bytes".utf8).write(to: store)
        let backup = try CMSNModelContainerFactory.backupPersistentStore(at: store)
        XCTAssertEqual(try Data(contentsOf: store), Data("bytes".utf8))
        XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("default.store")), Data("bytes".utf8))
    }
}
