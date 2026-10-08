import XCTest
@testable import CMSNApp

@MainActor
final class StoreRecoveryTests: XCTestCase {
    func testQuarantineStampIsUTCAndStable() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(CMSNModelContainerFactory.quarantineStamp(from: date), "20231114-221320")
    }

    func testRelatedStoreURLsIncludeSQLiteSidecars() {
        let store = URL(fileURLWithPath: "/tmp/default.store")
        XCTAssertEqual(
            CMSNModelContainerFactory.relatedStoreURLs(for: store).map(\.path),
            ["/tmp/default.store", "/tmp/default.store-wal", "/tmp/default.store-shm"]
        )
    }

    func testQuarantineMovesStoreAndSidecarsWithoutDeletingBytes() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = root.appendingPathComponent("default.store")
        let wal = URL(fileURLWithPath: store.path + "-wal")
        let shm = URL(fileURLWithPath: store.path + "-shm")
        let neighbor = root.appendingPathComponent("notes.txt")
        try Data("store-bytes".utf8).write(to: store)
        try Data("wal-bytes".utf8).write(to: wal)
        try Data("shm-bytes".utf8).write(to: shm)
        try Data("keep".utf8).write(to: neighbor)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let backup = try CMSNModelContainerFactory.quarantinePersistentStore(at: store, now: now)

        XCTAssertEqual(backup.lastPathComponent, "20231114-221320")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: wal.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: shm.path))
        XCTAssertEqual(try Data(contentsOf: neighbor), Data("keep".utf8))
        XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("default.store")), Data("store-bytes".utf8))
        XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("default.store-wal")), Data("wal-bytes".utf8))
        XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("default.store-shm")), Data("shm-bytes".utf8))
    }

    func testSecondQuarantineInTheSameSecondDoesNotOverwriteTheFirst() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = root.appendingPathComponent("default.store")
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try Data("first".utf8).write(to: store)
        let first = try CMSNModelContainerFactory.quarantinePersistentStore(at: store, now: now)

        try Data("second".utf8).write(to: store)
        let second = try CMSNModelContainerFactory.quarantinePersistentStore(at: store, now: now)

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(second.lastPathComponent, "20231114-221320-2")
        XCTAssertEqual(try Data(contentsOf: first.appendingPathComponent("default.store")), Data("first".utf8))
        XCTAssertEqual(try Data(contentsOf: second.appendingPathComponent("default.store")), Data("second".utf8))
    }

    func testQuarantineOfMissingStoreThrowsAndCreatesNoBackup() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = root.appendingPathComponent("default.store")
        XCTAssertThrowsError(try CMSNModelContainerFactory.quarantinePersistentStore(at: store)) { error in
            XCTAssertEqual(error as? StoreQuarantineError, .nothingToMove)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("CMSNStoreBackups").path))
    }

    func testFailedOpenDoesNotQuarantineTheStore() {
        var quarantines = 0
        let bootstrap = StoreBootstrap(
            openStore: { throw StoreOpenFailure(message: "disk full") },
            quarantine: { _ in
                quarantines += 1
                return URL(fileURLWithPath: "/tmp/backup")
            },
            storeURL: { URL(fileURLWithPath: "/tmp/cmsn.store") }
        )

        guard case .failed(let message) = bootstrap.phase else {
            return XCTFail("A failed open should stay on the recovery path.")
        }
        XCTAssertTrue(message.contains("disk full"))
        XCTAssertEqual(quarantines, 0, "Opening the store must not move or delete it.")
    }

    func testStartFreshQuarantinesThenOpensAgain() throws {
        var opens = 0
        var quarantines = 0
        let bootstrap = StoreBootstrap(
            openStore: {
                opens += 1
                if opens == 1 {
                    throw StoreOpenFailure(message: "corrupt")
                }
                return CMSNModelContainerFactory.makeInMemory()
            },
            quarantine: { url in
                quarantines += 1
                XCTAssertEqual(url.path, "/tmp/cmsn.store")
                return URL(fileURLWithPath: "/tmp/CMSNStoreBackups/stamp")
            },
            storeURL: { URL(fileURLWithPath: "/tmp/cmsn.store") }
        )

        XCTAssertEqual(quarantines, 0)
        bootstrap.startFreshPreservingExistingStore()
        XCTAssertEqual(quarantines, 1)
        XCTAssertEqual(opens, 2)
        guard case .ready = bootstrap.phase else {
            return XCTFail("After an explicit quarantine, a successful reopen should leave the app ready.")
        }
    }

    func testFailedOpenLeavesBlockingStoreBytesInPlace() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // A directory where SwiftData expects a store file. Our wrapper must
        // surface the error and leave the marker that sits inside it.
        let storeURL = root.appendingPathComponent("default.store", isDirectory: true)
        try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        let marker = storeURL.appendingPathComponent("marker")
        let payload = Data("userdata".utf8)
        try payload.write(to: marker)

        XCTAssertThrowsError(
            try CMSNModelContainerFactory.open(CMSNModelContainerFactory.persistentConfiguration(storeURL: storeURL))
        ) { error in
            XCTAssertTrue(error is StoreOpenFailure)
        }
        XCTAssertEqual(try Data(contentsOf: marker), payload)
    }

    private func makeTempRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-store-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
