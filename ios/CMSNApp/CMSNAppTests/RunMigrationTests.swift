import XCTest
import SwiftData
@testable import CMSNApp

@MainActor
final class RunMigrationTests: XCTestCase {
    func testPlanReachesDietPreferenceSchema() {
        XCTAssertEqual(CMSNMigrationPlan.schemas.count, 5)
        XCTAssertEqual(CMSNMigrationPlan.stages.count, 4)
    }

    /// Opens a real V3 store and reopens it on the V4 plan. The athlete
    /// stays, and the new run and club tables start empty. Inserting a
    /// run and a club graph after that proves the additive models persist.
    func testMigrationFromV3PreservesAthleteAndStartsRunsEmpty() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-run-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("CMSN.store")
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let onboarded = Date(timeIntervalSince1970: 1_700_200_000)
        let weight = 88.5

        try Self.writeV3Store(at: storeURL, createdAt: createdAt, onboarded: onboarded, weightKG: weight)
        try Self.assertV4Migration(at: storeURL, weightKG: weight)
    }

    private static func writeV3Store(at storeURL: URL, createdAt: Date, onboarded: Date, weightKG: Double) throws {
        let schema = Schema(versionedSchema: CMSNSchemaV3.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let athlete = Athlete(
            createdAt: createdAt,
            age: 34,
            heightCM: 176,
            weightKG: weightKG,
            onboardingCompletedAt: onboarded
        )
        context.insert(athlete)
        try context.save()
    }

    private static func assertV4Migration(at storeURL: URL, weightKG: Double) throws {
        let schema = Schema(versionedSchema: CMSNSchemaV4.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: CMSNMigrationPlan.self,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        let athletes = try context.fetch(FetchDescriptor<Athlete>())
        XCTAssertEqual(athletes.count, 1)
        XCTAssertEqual(athletes[0].weightKG, weightKG, accuracy: 0.0001)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Run>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<RunClub>()).count, 0)

        let athlete = athletes[0]
        let started = Date(timeIntervalSince1970: 1_710_000_000)
        let run = Run(
            athleteID: athlete.id,
            startedAt: started,
            endedAt: started.addingTimeInterval(300),
            environment: .outdoor,
            status: .ended,
            distanceMeters: 1_000,
            movingSeconds: 300
        )
        context.insert(run)
        let split = RunSplit(index: 1, distanceMeters: 1_000, elapsedSeconds: 300, isPartial: false, run: run)
        context.insert(split)
        let route = RunRoute(
            samples: [
                TrackPoint(
                    latitude: 37,
                    longitude: -122,
                    altitudeMeters: 12,
                    timestamp: started,
                    horizontalAccuracy: 5,
                    speedMetersPerSecond: 3
                ),
            ],
            run: run
        )
        run.route = route
        context.insert(route)

        let club = RunClub(name: "Hold")
        context.insert(club)
        let membership = ClubMembership(athleteID: athlete.id, club: club)
        context.insert(membership)
        let challenge = Challenge(
            title: "Later",
            startsAt: started,
            endsAt: started.addingTimeInterval(86_400),
            goalDistanceMeters: 5_000,
            club: club
        )
        context.insert(challenge)
        let entry = ChallengeEntry(athleteID: athlete.id, runID: run.id, distanceMeters: 1_000, challenge: challenge)
        context.insert(entry)
        try context.save()

        let runs = try context.fetch(FetchDescriptor<Run>())
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].splits.count, 1)
        XCTAssertEqual(runs[0].route?.samples().count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<RunClub>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ClubMembership>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Challenge>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChallengeEntry>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Athlete>())[0].weightKG, weightKG, accuracy: 0.0001)
    }
}
