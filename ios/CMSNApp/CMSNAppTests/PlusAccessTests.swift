import XCTest
import SwiftData
@testable import CMSNApp

final class PlusAccessPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testInstallDoesNotStartRunwayAndAssessmentCannotRestartIt() {
        var policy = PlusAccessPolicy()
        XCTAssertEqual(policy.state(at: start), .free)
        policy.completeAssessment(at: start)
        policy.completeAssessment(at: start.addingTimeInterval(600))
        XCTAssertEqual(policy.assessmentCompletedAt, start)
        XCTAssertEqual(policy.state(at: start), .runway)
        XCTAssertEqual(policy.state(at: start.addingTimeInterval(604799)), .runway)
        XCTAssertEqual(policy.state(at: start.addingTimeInterval(604800)), .free)
    }
    func testFullCapabilityMatrixAcrossFreeRunwayPaidAndLapsed() {
        var policy = PlusAccessPolicy()
        for capability in PlusAccessPolicy.Capability.allCases {
            XCTAssertEqual(policy.allows(capability, at: start), !capability.requiresPlus)
        }
        policy.completeAssessment(at: start)
        for capability in PlusAccessPolicy.Capability.allCases { XCTAssertTrue(policy.allows(capability, at: start)) }
        let after = start.addingTimeInterval(604800)
        policy.applyVerifiedPaidAccess(true, at: after)
        XCTAssertEqual(policy.state(at: after), .plus)
        for capability in PlusAccessPolicy.Capability.allCases { XCTAssertTrue(policy.allows(capability, at: after)) }
        policy.applyVerifiedPaidAccess(false, at: after)
        for capability in PlusAccessPolicy.Capability.allCases {
            XCTAssertEqual(policy.allows(capability, at: after), !capability.requiresPlus)
        }
    }
    func testSessionSnapshotSurvivesExpiryAndFreeSessionDoesNotGainCoaching() {
        var policy = PlusAccessPolicy()
        let free = PlusSessionAccess(policy: policy, at: start)
        policy.applyVerifiedPaidAccess(true, at: start)
        let paid = PlusSessionAccess(policy: policy, at: start)
        policy.applyVerifiedPaidAccess(false, at: start.addingTimeInterval(1))
        XCTAssertTrue(paid.coachingEnabled)
        XCTAssertFalse(free.coachingEnabled)
        XCTAssertFalse(policy.allows(.coaching, at: start.addingTimeInterval(1)))
    }
    func testPersistedLastVerifiedAccessHoldsAcrossOfflineRenewalBoundary() throws {
        var policy = PlusAccessPolicy()
        policy.applyVerifiedPaidAccess(true, at: start)
        let restored = try JSONDecoder().decode(PlusAccessPolicy.self, from: JSONEncoder().encode(policy))
        XCTAssertEqual(restored.state(at: start.addingTimeInterval(86400 * 40)), .plus)
        policy.applyVerifiedPaidAccess(false, at: start.addingTimeInterval(86400 * 40))
        XCTAssertEqual(policy.state(at: start.addingTimeInterval(86400 * 40)), .free)
    }
}

@MainActor
final class PlusPersistenceAndOfferTests: XCTestCase {
    func testServiceRestoresRunwayAndVerifiedAccessWithoutRestartingAssessment() {
        let defaults = UserDefaults(suiteName: "plus-test-\(UUID().uuidString)")!
        let start = Date().addingTimeInterval(-604800)
        let service = PlusEntitlementService(defaults: defaults)
        service.completeAssessment(at: start)
        service.applyVerifiedPaidAccess(true)
        let restored = PlusEntitlementService(defaults: defaults)
        XCTAssertTrue(restored.hasPlus)
        restored.applyVerifiedPaidAccess(false)
        restored.completeAssessment(at: Date())
        XCTAssertFalse(restored.hasPlus)
        XCTAssertEqual(restored.policy.assessmentCompletedAt, start)
    }
    func testPaywallExampleIsRealEngineOutputFromMatchingFixture() throws {
        let example = PlusPaywallExample.make()
        XCTAssertEqual(try XCTUnwrap(example.suggestion.suggestedWeightKG), 82.5, accuracy: 0.001)
        XCTAssertTrue(example.withPlus.contains(example.suggestion.rationale))
        XCTAssertTrue(example.withPlus.contains("82.5 kg"))
        XCTAssertTrue(example.suggestion.rationale.contains("Try 82.5 kg today."))
        XCTAssertFalse(example.suggestion.rationale.contains("Try 83"))
        XCTAssertTrue(example.withoutPlus.contains("Choose your weight"))
        XCTAssertFalse(example.withPlus.contains("Tuesday"))
        XCTAssertFalse(example.withPlus.contains("86"))
    }
    func testCoachingRecordsSurviveRelaunchAndRemainExportableAfterLapse() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("record.store")
        let id = UUID(), setID = UUID()
        do {
            let container = try CMSNModelContainerFactory.open(CMSNModelContainerFactory.persistentConfiguration(storeURL: url))
            let context = ModelContext(container)
            let record = PlusSessionRecord(sessionID: id, coachingEnabled: true)
            record.record(setID: setID, explanation: SavedCoachingExplanation(exerciseName: "Bench", setNumber: 1,
                rationale: "Your previous recorded coaching.", suggestedWeightKG: 82.5))
            context.insert(record)
            try context.save()
        }
        let reopened = try CMSNModelContainerFactory.open(CMSNModelContainerFactory.persistentConfiguration(storeURL: url))
        let context = ModelContext(reopened)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<PlusSessionRecord>()).first)
        XCTAssertTrue(record.coachingEnabled)
        XCTAssertEqual(record.explanations[setID.uuidString]?.rationale, "Your previous recorded coaching.")
        let export = try AccountDataService.exportJSON(context: context)
        defer { try? FileManager.default.removeItem(at: export) }
        XCTAssertTrue(try String(contentsOf: export, encoding: .utf8).contains("Your previous recorded coaching."))
        try AccountDataService.eraseEverything(context: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlusSessionRecord>()), 0)
    }
    func testV5StoreMigratesToV6WithoutLosingWorkoutRecords() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("migration.store")
        let id = UUID()
        do {
            let schema = Schema(versionedSchema: CMSNSchemaV5.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = ModelContext(container)
            context.insert(WorkoutSession(id: id, splitFocus: .fullBody, equipmentProfileUsed: .fullServiceGym))
            try context.save()
        }
        let container = try CMSNModelContainerFactory.open(CMSNModelContainerFactory.persistentConfiguration(storeURL: url))
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutSession>()).first?.id, id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlusSessionRecord>()), 0)
    }
}
