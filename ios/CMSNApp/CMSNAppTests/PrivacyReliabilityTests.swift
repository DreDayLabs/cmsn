import SwiftData
import XCTest
@testable import CMSNApp

@MainActor
final class PrivacyReliabilityTests: XCTestCase {
    func testCalendarStaysOffUntilOptIn() {
        for authorization in [CalendarSplitService.AuthorizationState.notDetermined, .authorized, .denied] {
            XCTAssertEqual(
                CalendarAccessPolicy.gate(userOptedIn: false, authorization: authorization),
                .off,
                "Off toggle must not read or ask when iOS status is \(authorization)."
            )
            XCTAssertFalse(
                CalendarAccessPolicy.shouldRequestPermission(userOptedIn: false, authorization: authorization)
            )
        }
    }

    func testOptInDoesNotReadBeforeTheSystemGrant() {
        XCTAssertEqual(
            CalendarAccessPolicy.gate(userOptedIn: true, authorization: .notDetermined),
            .waitingForPrompt
        )
        XCTAssertTrue(
            CalendarAccessPolicy.shouldRequestPermission(userOptedIn: true, authorization: .notDetermined)
        )
        XCTAssertNotEqual(
            CalendarAccessPolicy.gate(userOptedIn: true, authorization: .notDetermined),
            .readTitles
        )
    }

    func testDenialAndRevocationDoNotReadOrAskAgain() {
        XCTAssertEqual(
            CalendarAccessPolicy.gate(userOptedIn: true, authorization: .denied),
            .blocked
        )
        XCTAssertFalse(
            CalendarAccessPolicy.shouldRequestPermission(userOptedIn: true, authorization: .denied)
        )
    }

    func testAuthorizedOptInReadsTitlesOnly() {
        XCTAssertEqual(
            CalendarAccessPolicy.gate(userOptedIn: true, authorization: .authorized),
            .readTitles
        )
        XCTAssertFalse(
            CalendarAccessPolicy.shouldRequestPermission(userOptedIn: true, authorization: .authorized)
        )
    }

    func testServiceDoesNotReadWhenOptedOut() {
        let service = CalendarSplitService()
        XCTAssertNil(service.todaysOverrideFocus(userOptedIn: false))
        XCTAssertNil(service.todaysOverrideEvent(userOptedIn: false))
    }

    func testTodayDoesNotRequestCalendarAccess() throws {
        let today = try String(contentsOf: repoFile("ios/CMSNApp/CMSNApp/Features/Today/TodayView.swift"), encoding: .utf8)
        XCTAssertFalse(today.contains("requestAccess"))
        XCTAssertFalse(today.contains("primeCalendarIfNeeded"))
        let settings = try String(contentsOf: repoFile("ios/CMSNApp/CMSNApp/App/SettingsView.swift"), encoding: .utf8)
        XCTAssertTrue(settings.contains("requestAccess"))
        XCTAssertTrue(settings.contains("shouldRequestPermission"))
    }

    func testFailedEraseSaveRollsBackAndThrows() throws {
        let container = CMSNModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let athlete = Athlete(age: 30, heightCM: 180, weightKG: 90)
        context.insert(athlete)
        try context.save()
        let id = athlete.id

        struct SaveFailed: Error {}
        XCTAssertThrowsError(
            try AccountDataService.eraseEverything(context: context, save: { _ in throw SaveFailed() })
        )

        let remaining = try context.fetch(FetchDescriptor<Athlete>())
        XCTAssertEqual(remaining.map(\.id), [id])
        XCTAssertEqual(
            AccountDataService.deleteSaveFailedMessage,
            "Couldn't erase your data. Nothing was confirmed deleted."
        )
    }

    /// Induced save failure against a file-backed store. The same context and
    /// a container opened again on that file must still hold the athlete.
    /// This file has not been executed on the Mac yet. It does not describe
    /// what the old batch `delete(model:)` path did to a sqlite file.
    func testFailedEraseSaveLeavesOnDiskAthlete() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-erase-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("CMSN.store")
        let configuration = CMSNModelContainerFactory.persistentConfiguration(storeURL: storeURL)
        let id: UUID
        do {
            let container = try CMSNModelContainerFactory.open(configuration)
            let context = container.mainContext
            let athlete = Athlete(age: 30, heightCM: 180, weightKG: 90)
            context.insert(athlete)
            try context.save()
            id = athlete.id
            struct SaveFailed: Error {}
            XCTAssertThrowsError(
                try AccountDataService.eraseEverything(context: context, save: { _ in throw SaveFailed() })
            )
            let live = try context.fetch(FetchDescriptor<Athlete>())
            XCTAssertEqual(live.map(\.id), [id])
        }
        let reopened = try CMSNModelContainerFactory.open(configuration)
        let stored = try reopened.mainContext.fetch(FetchDescriptor<Athlete>())
        XCTAssertEqual(stored.map(\.id), [id])
    }

    func testSuccessfulEraseRemovesTheAthlete() throws {
        let container = CMSNModelContainerFactory.makeInMemory()
        let context = container.mainContext
        context.insert(Athlete(age: 30, heightCM: 180, weightKG: 90))
        try context.save()
        try AccountDataService.eraseEverything(context: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Athlete>()).isEmpty)
    }

    func testExportOmitsRouteAndPhotoBytes() throws {
        let container = CMSNModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let athlete = Athlete(age: 30, heightCM: 180, weightKG: 90)
        context.insert(athlete)
        let run = Run(
            athleteID: athlete.id,
            endedAt: Date(),
            environment: .outdoor,
            status: .ended,
            photoJPEG: Data("photo-bytes-not-for-export".utf8)
        )
        let route = RunRoute(samples: [
            TrackPoint(
                latitude: 12.345678,
                longitude: -98.765432,
                altitudeMeters: nil,
                timestamp: Date(),
                horizontalAccuracy: 5,
                speedMetersPerSecond: 0
            ),
        ])
        route.run = run
        run.route = route
        context.insert(run)
        context.insert(route)
        try context.save()

        let url = try AccountDataService.exportJSON(context: context)
        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let runs = try XCTUnwrap(root["runs"] as? [[String: Any]])
        XCTAssertEqual(runs.first?["photoAttached"] as? Bool, true)
        XCTAssertNil(root["routes"])
        XCTAssertFalse(text.contains("12.345678"))
        XCTAssertFalse(text.contains("photo-bytes-not-for-export"))
        XCTAssertFalse(text.contains("\"rpe\""))
    }

    func testWebsiteCopyMatchesInAppLegalCopy() throws {
        let privacy = try String(contentsOf: repoFile("app/privacy/page.tsx"), encoding: .utf8)
        let support = try String(contentsOf: repoFile("app/support/page.tsx"), encoding: .utf8)
        let sentences = [
            LegalCopy.shortVersion,
            LegalCopy.stored,
            LegalCopy.running,
            LegalCopy.foodLookups,
            LegalCopy.optionalPermissions,
            LegalCopy.changes,
            LegalCopy.deleteSaveFailedMessage,
        ]
        for sentence in sentences {
            XCTAssertTrue(privacy.contains(sentence), sentence)
        }
        XCTAssertTrue(support.contains(LegalCopy.yourData))
        XCTAssertTrue(support.contains(LegalCopy.deleteSaveFailedMessage))
        XCTAssertFalse(support.contains("full copy"))
        XCTAssertTrue(LegalCopy.stored.contains(LegalCopy.deleteSaveFailedMessage))
        XCTAssertTrue(LegalCopy.yourData.contains(LegalCopy.deleteSaveFailedMessage))
        let home = try String(contentsOf: repoFile("ios/CMSNApp/CMSNApp/Features/Run/RunHomeView.swift"), encoding: .utf8)
        XCTAssertTrue(home.contains("A run is waiting to sync"))
        XCTAssertTrue(LegalCopy.running.contains("A run is waiting to sync"))
    }

    private func repoFile(_ relative: String) throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw MissingRepoFile(path: file.path)
        }
        return file
    }
}

private struct MissingRepoFile: Error {
    var path: String
}
