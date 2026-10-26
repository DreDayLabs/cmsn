import XCTest
import SwiftData
@testable import CMSNApp

@MainActor
final class RestrictiveDietTests: XCTestCase {
    private let lockedIDs = [
        "daniel_fast",
        "keto",
        "carnivore",
        "vegan",
        "vegetarian",
        "dr_sebi",
        "mediterranean",
        "paleo",
        "whole30",
        "pescatarian",
        "flexitarian",
        "intermittent_fasting",
        "high_protein",
        "low_carb",
    ]

    private let lockedNames = [
        "daniel_fast": "Daniel Fast (Daniel's diet)",
        "keto": "Keto",
        "carnivore": "Carnivore",
        "vegan": "Vegan",
        "vegetarian": "Vegetarian",
        "dr_sebi": "Dr. Sebi (alkaline)",
        "mediterranean": "Mediterranean",
        "paleo": "Paleo",
        "whole30": "Whole30",
        "pescatarian": "Pescatarian",
        "flexitarian": "Flexitarian (mostly plants, some meat)",
        "intermittent_fasting": "Intermittent fasting",
        "high_protein": "High-protein (athlete / body-recomp)",
        "low_carb": "Low-carb (not full keto)",
        "none": "None / not on a restrictive diet",
    ]

    func testCatalogContainsLockedDietsAndNone() {
        XCTAssertEqual(RestrictiveDietID.named.map(\.rawValue), lockedIDs)
        XCTAssertEqual(RestrictiveDietID.none.rawValue, "none")
        XCTAssertEqual(RestrictiveDietCatalog.entries.count, 15)
        XCTAssertEqual(Set(RestrictiveDietCatalog.entries.map(\.id)), Set(RestrictiveDietID.allCases))
        XCTAssertEqual(RestrictiveDietCatalog.choices.map(\.id), RestrictiveDietID.allCases)
    }

    func testCatalogNamesAndSeedsAreComplete() {
        for diet in RestrictiveDietCatalog.entries {
            XCTAssertEqual(diet.displayName, lockedNames[diet.id.rawValue])
            XCTAssertFalse(diet.summary.isEmpty)
            XCTAssertFalse(diet.preWorkout.foods.isEmpty)
            XCTAssertFalse(diet.preWorkout.timing.isEmpty)
            XCTAssertFalse(diet.postWorkout.foods.isEmpty)
            XCTAssertFalse(diet.postWorkout.timing.isEmpty)
        }
        XCTAssertEqual(FastingWindow.sixteenEight.rawValue, "16_8")
        XCTAssertEqual(FastingWindow.omad.rawValue, "omad")
        XCTAssertTrue(DietWorkoutFueling.disclaimer.contains("Product-seeded"))
        XCTAssertTrue(DietWorkoutFueling.disclaimer.contains("not medical advice"))
    }

    func testSelectingPaleoSurfacesPaleoSuggestions() {
        let state = RestrictiveDietSectionState.make(
            NutritionDietSelection(dietIDs: [.paleo], fastingWindow: nil)
        )
        XCTAssertTrue(state.surface.isVisible)
        XCTAssertFalse(state.showsFastingWindows)
        XCTAssertEqual(state.surface.cards.map(\.id), [.paleo])
        let card = state.surface.cards[0]
        XCTAssertEqual(card.displayName, "Paleo")
        XCTAssertTrue(card.preWorkoutFoods.localizedCaseInsensitiveContains("almond"))
        XCTAssertTrue(card.postWorkoutFoods.localizedCaseInsensitiveContains("sweet potato"))
        XCTAssertFalse(card.preWorkoutTiming.isEmpty)
        XCTAssertFalse(card.postWorkoutTiming.isEmpty)
        XCTAssertTrue(state.surface.disclaimer.contains("not medical advice"))
        XCTAssertNil(state.surface.overlapNote)
    }

    func testSelectingVeganSurfacesPlantProtein() {
        let state = RestrictiveDietSectionState.make(
            NutritionDietSelection(dietIDs: [.vegan], fastingWindow: nil)
        )
        XCTAssertTrue(state.surface.isVisible)
        let card = state.surface.cards[0]
        XCTAssertEqual(card.id, .vegan)
        XCTAssertTrue(card.postWorkoutFoods.localizedCaseInsensitiveContains("lentils"))
        XCTAssertTrue(card.postWorkoutFoods.localizedCaseInsensitiveContains("chickpeas"))
        XCTAssertFalse(card.postWorkoutFoods.localizedCaseInsensitiveContains("chicken"))
    }

    func testNoneClearsNamedDietsAndStillSurfacesGeneralFueling() {
        var selection = NutritionDietSelection(dietIDs: [.paleo, .vegan], fastingWindow: nil)
        selection = selection.toggling(.none)
        let state = RestrictiveDietSectionState.make(selection)
        XCTAssertEqual(state.selection.dietIDs, [.none])
        XCTAssertTrue(state.surface.isVisible)
        XCTAssertEqual(state.surface.cards.map(\.id), [.none])
        XCTAssertFalse(state.surface.cards[0].postWorkoutFoods.localizedCaseInsensitiveContains("sweet potato"))
        XCTAssertFalse(state.showsFastingWindows)
    }

    func testUnansweredSelectionHidesSuggestions() {
        let state = RestrictiveDietSectionState.make(.unanswered)
        XCTAssertFalse(state.surface.isVisible)
        XCTAssertTrue(state.surface.cards.isEmpty)
        XCTAssertFalse(state.showsFastingWindows)
    }

    func testNamedDietClearsNoneAndListsEachDiet() {
        let selection = NutritionDietSelection(dietIDs: [.none], fastingWindow: nil)
            .toggling(.vegan)
            .toggling(.paleo)
        let state = RestrictiveDietSectionState.make(selection)
        XCTAssertEqual(state.selection.dietIDs, [.vegan, .paleo])
        XCTAssertEqual(state.surface.cards.map(\.id), [.vegan, .paleo])
        XCTAssertNotNil(state.surface.overlapNote)
    }

    func testIntermittentFastingWindowsChangeTiming() {
        let sixteen = RestrictiveDietSectionState.make(
            NutritionDietSelection(dietIDs: [.intermittentFasting], fastingWindow: nil)
        )
        XCTAssertTrue(sixteen.showsFastingWindows)
        XCTAssertEqual(sixteen.selection.fastingWindow, .sixteenEight)
        XCTAssertTrue(sixteen.surface.cards[0].preWorkoutTiming.contains("16:8"))
        XCTAssertTrue(sixteen.surface.cards[0].postWorkoutTiming.contains("16:8"))

        let omad = RestrictiveDietSectionState.make(sixteen.selection.selectingFastingWindow(.omad))
        XCTAssertEqual(omad.selection.fastingWindow, .omad)
        XCTAssertTrue(omad.surface.cards[0].preWorkoutFoods.contains("OMAD"))
        XCTAssertTrue(omad.surface.cards[0].postWorkoutTiming.contains("OMAD"))
        XCTAssertFalse(omad.surface.cards[0].preWorkoutTiming.contains("16:8"))
    }

    func testTurningOffFastingClearsTheWindow() {
        let selection = NutritionDietSelection(dietIDs: [.intermittentFasting], fastingWindow: .omad)
            .toggling(.intermittentFasting)
        XCTAssertEqual(selection, .unanswered)
        XCTAssertNil(selection.fastingWindow)
    }

    func testUnknownStoredIdsAreDropped() {
        let selection = NutritionDietSelection(
            rawDietIDs: ["paleo", "not_a_diet", "paleo"],
            fastingWindowRaw: "nope"
        )
        XCTAssertEqual(selection.dietIDs, [.paleo])
        XCTAssertNil(selection.fastingWindow)
    }

    func testNoneStoredWithANamedDietKeepsOnlyNone() {
        let selection = NutritionDietSelection(rawDietIDs: ["vegan", "none"], fastingWindowRaw: "16_8")
        XCTAssertEqual(selection.dietIDs, [.none])
        XCTAssertNil(selection.fastingWindow)
    }

    func testPersistenceRoundTrip() throws {
        let container = CMSNModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let athlete = Athlete(age: 30, heightCM: 180, weightKG: 80, onboardingCompletedAt: Date())
        let other = Athlete(age: 22, heightCM: 165, weightKG: 60)
        context.insert(athlete)
        context.insert(other)
        try context.save()

        let repository = NutritionRepository(context: context)
        XCTAssertEqual(repository.dietSelection(for: athlete.id), .unanswered)

        let selected = NutritionDietSelection(dietIDs: [.paleo, .intermittentFasting], fastingWindow: .omad)
        repository.saveDietSelection(selected, athleteID: athlete.id)
        XCTAssertEqual(repository.dietSelection(for: athlete.id), selected)
        XCTAssertEqual(repository.dietSelection(for: other.id), .unanswered)

        let replaced = selected.toggling(.none)
        repository.saveDietSelection(replaced, athleteID: athlete.id)
        XCTAssertEqual(repository.dietSelection(for: athlete.id).dietIDs, [.none])
        XCTAssertNil(repository.dietSelection(for: athlete.id).fastingWindow)
        XCTAssertEqual(try context.fetch(FetchDescriptor<NutritionDietPreference>()).count, 1)

        let stored = try context.fetch(FetchDescriptor<NutritionDietPreference>())[0]
        XCTAssertEqual(stored.dietIDsRaw, ["none"])
        XCTAssertEqual(stored.athleteID, athlete.id)

        let surfaced = RestrictiveDietSectionState.make(repository.dietSelection(for: athlete.id))
        XCTAssertTrue(surfaced.surface.isVisible)
        XCTAssertEqual(surfaced.surface.cards.map(\.id), [.none])
    }

    func testMigrationFromV4PreservesAthleteAndStartsDietPreferencesEmpty() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-diet-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("CMSN.store")
        let weight = 77.5
        try Self.writeV4Store(at: storeURL, weightKG: weight)

        let schema = Schema(versionedSchema: CMSNSchemaV5.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: CMSNMigrationPlan.self,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        let athletes = try context.fetch(FetchDescriptor<Athlete>())
        XCTAssertEqual(athletes.count, 1)
        XCTAssertEqual(athletes[0].weightKG, weight, accuracy: 0.0001)
        XCTAssertEqual(try context.fetch(FetchDescriptor<NutritionDietPreference>()).count, 0)

        let repository = NutritionRepository(context: context)
        let saved = NutritionDietSelection(dietIDs: [.vegan], fastingWindow: nil)
        repository.saveDietSelection(saved, athleteID: athletes[0].id)
        XCTAssertEqual(repository.dietSelection(for: athletes[0].id), saved)
        XCTAssertEqual(athletes[0].weightKG, weight, accuracy: 0.0001)
    }

    private static func writeV4Store(at storeURL: URL, weightKG: Double) throws {
        let schema = Schema(versionedSchema: CMSNSchemaV4.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.insert(Athlete(age: 34, heightCM: 176, weightKG: weightKG, onboardingCompletedAt: Date()))
        try context.save()
    }
}
