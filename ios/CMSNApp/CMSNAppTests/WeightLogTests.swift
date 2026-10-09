import XCTest
import SwiftData
@testable import CMSNApp

@MainActor
final class WeightLogTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: WeightLogRepository!

    override func setUp() {
        super.setUp()
        container = CMSNModelContainerFactory.makeInMemory()
        repository = WeightLogRepository(context: container.mainContext)
    }

    override func tearDown() {
        container = nil
        repository = nil
        super.tearDown()
    }

    private func makeAthlete(
        weight: Double = 90,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        onboarded: Date? = nil
    ) -> Athlete {
        let athlete = Athlete(
            createdAt: createdAt,
            age: 30,
            heightCM: 180,
            weightKG: weight,
            onboardingCompletedAt: onboarded
        )
        container.mainContext.insert(athlete)
        try? container.mainContext.save()
        return athlete
    }

    // MARK: - Adding entries and latest-sync

    func testAddingEntrySyncsProfileToLatestByDate() {
        let athlete = makeAthlete(weight: 90)
        let day = Date(timeIntervalSince1970: 1_710_000_000)
        repository.addEntry(weightKG: 90, recordedAt: day, athlete: athlete)
        repository.addEntry(weightKG: 85, recordedAt: day.addingTimeInterval(-86_400 * 10), athlete: athlete)
        XCTAssertEqual(athlete.weightKG, 90, accuracy: 0.0001, "An older sample must not replace a newer one.")
        repository.addEntry(weightKG: 88, recordedAt: day.addingTimeInterval(86_400), athlete: athlete)
        XCTAssertEqual(athlete.weightKG, 88, accuracy: 0.0001)
        XCTAssertEqual(repository.entries(for: athlete.id).count, 3)
    }

    func testDeletingLatestEntryFallsBackAndEmptyHistoryKeepsProfileWeight() throws {
        let athlete = makeAthlete(weight: 70)
        let day = Date(timeIntervalSince1970: 1_710_000_000)
        let older = try XCTUnwrap(repository.addEntry(weightKG: 92, recordedAt: day, athlete: athlete))
        let newer = try XCTUnwrap(repository.addEntry(weightKG: 89, recordedAt: day.addingTimeInterval(86_400), athlete: athlete))
        repository.delete(newer, athlete: athlete)
        XCTAssertEqual(athlete.weightKG, 92, accuracy: 0.0001)
        repository.delete(older, athlete: athlete)
        XCTAssertEqual(athlete.weightKG, 92, accuracy: 0.0001)
        XCTAssertTrue(repository.entries(for: athlete.id).isEmpty)
    }

    func testSameTimestampBreaksTieOnCreatedAt() {
        let athlete = makeAthlete(weight: 70)
        let when = Date(timeIntervalSince1970: 1_710_000_000)
        let first = WeightEntry(athleteID: athlete.id, recordedAt: when, createdAt: when, weightKG: 80)
        let second = WeightEntry(athleteID: athlete.id, recordedAt: when, createdAt: when.addingTimeInterval(5), weightKG: 81)
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        repository.syncProfileWeight(for: athlete, entries: [first, second])
        XCTAssertEqual(athlete.weightKG, 81, accuracy: 0.0001)
    }

    func testNonPositiveWeightIsRejected() {
        let athlete = makeAthlete(weight: 90)
        XCTAssertNil(repository.addEntry(weightKG: 0, athlete: athlete))
        XCTAssertNil(repository.addEntry(weightKG: -4, athlete: athlete))
        XCTAssertNil(repository.addEntry(weightKG: .nan, athlete: athlete))
        XCTAssertEqual(athlete.weightKG, 90, accuracy: 0.0001)
        XCTAssertTrue(repository.entries(for: athlete.id).isEmpty)
    }

    func testLatestWeightFeedsMacroTargets() {
        let athlete = makeAthlete(weight: 70)
        athlete.goalTypes = [.muscleGain]
        let before = MacroTargetCalculator.targets(for: athlete).proteinGrams
        repository.addEntry(weightKG: 100, recordedAt: Date(), athlete: athlete)
        let after = MacroTargetCalculator.targets(for: athlete).proteinGrams
        XCTAssertGreaterThan(after, before)
        XCTAssertEqual(athlete.weightKG, 100, accuracy: 0.0001)
    }

    func testImperialDisplayConvertsAndStoredUnitStaysKilograms() {
        let athlete = makeAthlete(weight: 70)
        athlete.unitPreference = .imperial
        let kilograms = UnitPreference.imperial.kilograms(fromDisplay: 200)
        repository.addEntry(weightKG: kilograms, recordedAt: Date(), athlete: athlete)
        XCTAssertEqual(athlete.weightKG, 200 / UnitPreference.poundsPerKilogram, accuracy: 0.0001)
        let pounds = UnitPreference.imperial.displayWeight(fromKilograms: 100)
        XCTAssertEqual(pounds, 220.46226, accuracy: 0.0001)
        XCTAssertEqual(UnitPreference.imperial.formattedWeight(kilograms: 100), String(format: "%.1f lb", pounds))
        XCTAssertEqual(UnitPreference.metric.formattedWeight(kilograms: 82), String(format: "%.1f kg", 82.0))
    }

    func testEntriesDoNotCrossAthletes() {
        let first = makeAthlete(weight: 80)
        let second = Athlete(age: 28, heightCM: 170, weightKG: 60)
        container.mainContext.insert(second)
        repository.addEntry(weightKG: 81, recordedAt: Date(), athlete: first)
        repository.addEntry(weightKG: 62, recordedAt: Date(), athlete: second)
        XCTAssertEqual(first.weightKG, 81, accuracy: 0.0001)
        XCTAssertEqual(second.weightKG, 62, accuracy: 0.0001)
        XCTAssertEqual(repository.entries(for: first.id).count, 1)
        XCTAssertEqual(repository.entries(for: second.id).count, 1)
    }

    func testRecordInitialWeightUsesProfileWhenHistoryIsEmpty() {
        let onboarded = Date(timeIntervalSince1970: 1_720_000_000)
        let athlete = makeAthlete(weight: 83, onboarded: onboarded)
        repository.recordInitialWeightIfNeeded(for: athlete)
        let entries = repository.entries(for: athlete.id)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].weightKG, 83, accuracy: 0.0001)
        XCTAssertEqual(entries[0].recordedAt.timeIntervalSince1970, onboarded.timeIntervalSince1970, accuracy: 1)
        repository.recordInitialWeightIfNeeded(for: athlete)
        XCTAssertEqual(repository.entries(for: athlete.id).count, 1)
    }

    func testRecordInitialLogsAChangedProfileWeight() {
        let athlete = makeAthlete(weight: 80, onboarded: Date(timeIntervalSince1970: 1_700_000_000))
        repository.recordInitialWeightIfNeeded(for: athlete)
        athlete.weightKG = 84
        repository.recordInitialWeightIfNeeded(for: athlete)
        XCTAssertEqual(repository.entries(for: athlete.id).count, 2)
        XCTAssertEqual(athlete.weightKG, 84, accuracy: 0.0001)
    }

    // MARK: - Migration seeding

    func testSeederCopiesCurrentWeightAndUsesOnboardingDate() throws {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let onboarded = Date(timeIntervalSince1970: 1_700_086_400)
        let athlete = makeAthlete(weight: 91.5, createdAt: created, onboarded: onboarded)
        try WeightHistorySeeder.seedIfUnmarked(in: container.mainContext)

        let entries = repository.entries(for: athlete.id)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].weightKG, 91.5, accuracy: 0.0001)
        XCTAssertEqual(entries[0].recordedAt.timeIntervalSince1970, onboarded.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(athlete.weightKG, 91.5, accuracy: 0.0001)
        let markers = try container.mainContext.fetch(FetchDescriptor<WeightHistorySeedMarker>())
        XCTAssertEqual(markers.count, 1)
    }

    func testSeederFallsBackToCreatedAtWhenOnboardingDateIsMissing() throws {
        let created = Date(timeIntervalSince1970: 1_600_000_000)
        let athlete = makeAthlete(weight: 77, createdAt: created, onboarded: nil)
        try WeightHistorySeeder.seedMissingEntries(in: container.mainContext)
        try container.mainContext.save()
        let entries = repository.entries(for: athlete.id)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].recordedAt.timeIntervalSince1970, created.timeIntervalSince1970, accuracy: 1)
    }

    func testSeederSkipsNonPositiveWeight() throws {
        let athlete = makeAthlete(weight: 0)
        try WeightHistorySeeder.seedIfUnmarked(in: container.mainContext)
        XCTAssertTrue(repository.entries(for: athlete.id).isEmpty)
        let markers = try container.mainContext.fetch(FetchDescriptor<WeightHistorySeedMarker>())
        XCTAssertEqual(markers.count, 1)
    }

    func testSeederDoesNotDuplicateOrResurrectDeletedEntries() throws {
        let athlete = makeAthlete(weight: 80)
        try WeightHistorySeeder.seedIfUnmarked(in: container.mainContext)
        try WeightHistorySeeder.seedIfUnmarked(in: container.mainContext)
        XCTAssertEqual(repository.entries(for: athlete.id).count, 1)

        for entry in repository.entries(for: athlete.id) {
            repository.delete(entry, athlete: athlete)
        }
        try WeightHistorySeeder.seedIfUnmarked(in: container.mainContext)
        XCTAssertEqual(repository.entries(for: athlete.id).count, 0)
        XCTAssertEqual(athlete.weightKG, 80, accuracy: 0.0001)
    }

    /// Opens a real V2 store (the schema existing installs are on) and
    /// reopens it with the V3 plan. The custom stage must copy `weightKG`
    /// into history without changing the profile value macros still read.
    func testMigrationFromV2SeedsHistoryAndPreservesProfileWeight() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-weight-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("CMSN.store")
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let onboarded = Date(timeIntervalSince1970: 1_700_200_000)
        let weight = 91.25

        try Self.writeV2Store(at: storeURL, createdAt: createdAt, onboarded: onboarded, weightKG: weight)
        try Self.assertV3Migration(at: storeURL, onboarded: onboarded, weightKG: weight)
    }

    private static func writeV2Store(at storeURL: URL, createdAt: Date, onboarded: Date, weightKG: Double) throws {
        let schema = Schema(versionedSchema: CMSNSchemaV2.self)
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

    private static func assertV3Migration(at storeURL: URL, onboarded: Date, weightKG: Double) throws {
        let schema = Schema(versionedSchema: CMSNSchemaV3.self)
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

        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].athleteID, athletes[0].id)
        XCTAssertEqual(entries[0].weightKG, weightKG, accuracy: 0.0001)
        XCTAssertEqual(entries[0].recordedAt.timeIntervalSince1970, onboarded.timeIntervalSince1970, accuracy: 1)

        let markers = try context.fetch(FetchDescriptor<WeightHistorySeedMarker>())
        XCTAssertEqual(markers.count, 1)
    }
}
