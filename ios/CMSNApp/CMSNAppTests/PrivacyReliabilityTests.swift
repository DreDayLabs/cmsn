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

    /// On-disk store with one row of each relationship in the live graph.
    /// A thrown save must leave those rows and their links after reopen.
    func testFailedEraseSaveRetainsChildGraphOnDisk() throws {
        let fixture = try OnDiskEraseFixture()
        defer { fixture.remove() }
        let ids = try fixture.seedChildGraph()
        struct SaveFailed: Error {}
        XCTAssertThrowsError(
            try AccountDataService.eraseEverything(context: fixture.context, save: { _ in throw SaveFailed() })
        )
        try assertChildGraph(ids, in: fixture.context)
        let reopened = try fixture.reopen()
        try assertChildGraph(ids, in: reopened.mainContext)
    }

    /// A successful save of a complete erase must remove the same graph from
    /// the file, not only the athlete row.
    func testSuccessfulEraseRemovesChildGraphOnDisk() throws {
        let fixture = try OnDiskEraseFixture()
        defer { fixture.remove() }
        _ = try fixture.seedChildGraph()
        try AccountDataService.eraseEverything(context: fixture.context)
        try assertChildGraphAbsent(in: fixture.context)
        let reopened = try fixture.reopen()
        try assertChildGraphAbsent(in: reopened.mainContext)
    }

    /// `CMSNSchemaV5` is the store `currentSchema()` opens. Every model in
    /// that list is a `deleteFetched` target, and the full fixture probes
    /// the same set. This does not open a store.
    ///
    /// The erase list is the `deleteFetched(Type.self` names in the
    /// `eraseEverything` source, not a runtime trace of that function.
    /// A delete written another way is not counted. `currentSchema()` is
    /// private, so the V5 binding is the source line
    /// `Schema(versionedSchema: CMSNSchemaV5.self)`.
    func testEraseTargetsMatchCurrentSchema() throws {
        let schemaNames = CMSNSchemaV5.models.map { EraseTargetProbe.modelName($0) }
        let probeNames = EraseTargetProbe.all.map { EraseTargetProbe.modelName($0.type) }
        let service = try String(contentsOf: repoFile("ios/CMSNApp/CMSNApp/App/AccountDataService.swift"), encoding: .utf8)
        let schemaSource = try String(contentsOf: repoFile("ios/CMSNApp/CMSNApp/Persistence/CMSNSchema.swift"), encoding: .utf8)
        let erased = eraseTargetNames(in: service)

        XCTAssertTrue(schemaSource.contains("Schema(versionedSchema: CMSNSchemaV5.self)"))
        XCTAssertEqual(schemaNames.count, Set(schemaNames).count)
        XCTAssertEqual(probeNames.count, schemaNames.count)
        XCTAssertEqual(Set(probeNames), Set(schemaNames))
        XCTAssertEqual(erased.count, Set(erased).count)
        XCTAssertEqual(Set(erased), Set(schemaNames))
    }

    /// Two rows of every model `eraseEverything` deletes. A thrown save
    /// keeps those rows, the SwiftData links, and the stored id values.
    func testFailedEraseSaveRetainsEveryTargetedTypeOnDisk() throws {
        let fixture = try OnDiskEraseFixture()
        defer { fixture.remove() }
        let graph = try fixture.seedAllTargetedTypes()
        struct SaveFailed: Error {}
        XCTAssertThrowsError(
            try AccountDataService.eraseEverything(context: fixture.context, save: { _ in throw SaveFailed() })
        )
        try assertFullEraseGraph(graph, in: fixture.context)
        let reopened = try fixture.reopen()
        try assertFullEraseGraph(graph, in: reopened.mainContext)
    }

    /// The same two-of-each graph is gone from the live context and from the
    /// file after a save that succeeds.
    func testSuccessfulEraseRemovesEveryTargetedTypeOnDisk() throws {
        let fixture = try OnDiskEraseFixture()
        defer { fixture.remove() }
        _ = try fixture.seedAllTargetedTypes()
        try AccountDataService.eraseEverything(context: fixture.context)
        try assertEveryTargetedTypeCount(0, in: fixture.context)
        let reopened = try fixture.reopen()
        try assertEveryTargetedTypeCount(0, in: reopened.mainContext)
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

/// One of each parent and its child. Not every model the eraser deletes.
private struct ChildGraphIDs: Equatable {
    var athlete: UUID
    var session: UUID
    var exercise: UUID
    var set: UUID
    var readiness: UUID
    var apparel: UUID
    var nutritionLog: UUID
    var nutritionEntry: UUID
    var meal: UUID
    var ingredient: UUID
    var run: UUID
    var split: UUID
    var route: UUID
}

@MainActor
private struct OnDiskEraseFixture {
    var directory: URL
    var storeURL: URL
    var configuration: ModelConfiguration
    var container: ModelContainer

    var context: ModelContext { container.mainContext }

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-graph-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appendingPathComponent("CMSN.store")
        configuration = CMSNModelContainerFactory.persistentConfiguration(storeURL: storeURL)
        container = try CMSNModelContainerFactory.open(configuration)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }

    func reopen() throws -> ModelContainer {
        try CMSNModelContainerFactory.open(configuration)
    }

    /// WorkoutSession → LoggedExercise → LoggedSet, plus readiness and apparel
    /// on the session. NutritionLog → NutritionEntry. SavedMeal → ingredient.
    /// Run → RunSplit and RunRoute.
    func seedChildGraph() throws -> ChildGraphIDs {
        let athlete = Athlete(age: 30, heightCM: 180, weightKG: 90)
        let session = WorkoutSession(splitFocus: .fullBody, equipmentProfileUsed: .home)
        let exercise = LoggedExercise(
            exerciseID: "squat",
            exerciseNameSnapshot: "Squat",
            orderIndex: 0
        )
        let set = LoggedSet(
            setIndex: 0,
            plannedRepRangeLow: 6,
            plannedRepRangeHigh: 8,
            plannedWeightKG: 40,
            isAttempted: true,
            completedReps: 8,
            completedWeightKG: 40
        )
        let readiness = ReadinessCheck(energyLevel: 4)
        let apparel = ApparelFeedback(garmentName: "Short", sizeWorn: "L")
        let log = NutritionLog(proteinGramsTarget: 120)
        let entry = NutritionEntry(label: "Eggs", proteinGrams: 18)
        let meal = SavedMeal(name: "Shake")
        let ingredient = SavedMealIngredient(
            name: "Milk",
            portionDescription: "250 ml",
            proteinGrams: 8,
            carbGrams: 12,
            fatGrams: 5,
            calories: 120,
            sortOrder: 0
        )
        let run = Run(athleteID: athlete.id, endedAt: Date(), environment: .outdoor, status: .ended)
        let split = RunSplit(index: 0, distanceMeters: 1000, elapsedSeconds: 300, isPartial: false)
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

        exercise.session = session
        session.loggedExercises = [exercise]
        set.exercise = exercise
        exercise.loggedSets = [set]
        readiness.session = session
        session.readiness = readiness
        apparel.session = session
        session.apparelFeedback = apparel
        entry.log = log
        log.entries = [entry]
        ingredient.meal = meal
        meal.ingredients = [ingredient]
        split.run = run
        run.splits = [split]
        route.run = run
        run.route = route

        context.insert(athlete)
        context.insert(session)
        context.insert(exercise)
        context.insert(set)
        context.insert(readiness)
        context.insert(apparel)
        context.insert(log)
        context.insert(entry)
        context.insert(meal)
        context.insert(ingredient)
        context.insert(run)
        context.insert(split)
        context.insert(route)
        try context.save()
        return ChildGraphIDs(
            athlete: athlete.id,
            session: session.id,
            exercise: exercise.id,
            set: set.id,
            readiness: readiness.id,
            apparel: apparel.id,
            nutritionLog: log.id,
            nutritionEntry: entry.id,
            meal: meal.id,
            ingredient: ingredient.id,
            run: run.id,
            split: split.id,
            route: route.id
        )
    }

    /// Two of every `CMSNSchemaV5` model. Workout rows are not attached to
    /// an athlete. `Run.athleteID` and the other athlete ids below are stored
    /// values, not SwiftData relationships.
    ///
    /// `RunSettings.athleteID` and `NutritionDietPreference.athleteID` are
    /// unique, so the second row uses the second athlete. `WorkoutSession.readiness`,
    /// `WorkoutSession.apparelFeedback`, and `Run.route` are to-one, so the
    /// second child uses the second parent. `WeightHistorySeedMarker` has no
    /// unique key besides its id; the app writes one, the schema allows two.
    func seedAllTargetedTypes() throws -> FullEraseGraph {
        var graph = FullEraseGraph()
        for index in 0..<2 {
            let athlete = Athlete(age: 30 + index, heightCM: 180, weightKG: 90)
            let session = WorkoutSession(
                splitFocus: index == 0 ? .fullBody : .push,
                equipmentProfileUsed: index == 0 ? .home : .travel
            )
            let exercise = LoggedExercise(
                exerciseID: "move-\(index)",
                exerciseNameSnapshot: "Move \(index)",
                orderIndex: index
            )
            let set = LoggedSet(
                setIndex: index,
                plannedRepRangeLow: 6,
                plannedRepRangeHigh: 8,
                plannedWeightKG: 40,
                isAttempted: true,
                completedReps: 8,
                completedWeightKG: 40
            )
            let readiness = ReadinessCheck(energyLevel: 3 + index)
            let apparel = ApparelFeedback(garmentName: "Short \(index)", sizeWorn: index == 0 ? "L" : "M")
            let log = NutritionLog(proteinGramsTarget: 120 + Double(index))
            let entry = NutritionEntry(label: index == 0 ? "Eggs" : "Yogurt", proteinGrams: 18)
            let meal = SavedMeal(name: index == 0 ? "Shake" : "Bowl")
            let ingredient = SavedMealIngredient(
                name: index == 0 ? "Milk" : "Oats",
                portionDescription: index == 0 ? "250 ml" : "40 g",
                proteinGrams: 8,
                carbGrams: 12,
                fatGrams: 5,
                calories: 120,
                sortOrder: index
            )
            let shoe = RunShoe(athleteID: athlete.id, name: "Shoe \(index)")
            let settings = RunSettings(athleteID: athlete.id, values: RunPreferenceValues())
            let run = Run(
                athleteID: athlete.id,
                endedAt: Date(),
                environment: .outdoor,
                status: .ended,
                shoeID: shoe.id
            )
            let split = RunSplit(
                index: index,
                distanceMeters: 1000,
                elapsedSeconds: 300,
                isPartial: false
            )
            let route = RunRoute(samples: [
                TrackPoint(
                    latitude: 12.0 + Double(index),
                    longitude: -98.0,
                    altitudeMeters: nil,
                    timestamp: Date(),
                    horizontalAccuracy: 5,
                    speedMetersPerSecond: 0
                ),
            ])
            let score = ScoreEvent(
                dimension: index == 0 ? .work : .consistency,
                points: 1,
                reason: "set \(index)",
                relatedSessionID: session.id
            )
            let supplement = CustomSupplement(name: "Supplement \(index)", note: "note \(index)")
            let custom = CustomExercise(
                id: "custom-\(index)",
                name: "Custom \(index)",
                primaryMuscleGroups: [.quadriceps],
                equipmentRequired: [.bodyweight],
                formCues: ["Brace"],
                commonMistake: "Knee",
                setupInstructions: "Stand",
                whyThisExercise: "Legs"
            )
            let weight = WeightEntry(athleteID: athlete.id, weightKG: 90 + Double(index))
            let marker = WeightHistorySeedMarker()
            let diet = NutritionDietPreference(
                athleteID: athlete.id,
                selection: index == 0
                    ? .unanswered
                    : NutritionDietSelection(dietIDs: [.highProtein], fastingWindow: nil)
            )
            let club = RunClub(name: "Club \(index)")
            let membership = ClubMembership(athleteID: athlete.id)
            let challenge = Challenge(
                title: "Challenge \(index)",
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(86_400),
                goalDistanceMeters: 5_000 + Double(index)
            )
            let challengeEntry = ChallengeEntry(
                athleteID: athlete.id,
                runID: run.id,
                distanceMeters: 1_000
            )

            exercise.session = session
            session.loggedExercises = [exercise]
            set.exercise = exercise
            exercise.loggedSets = [set]
            readiness.session = session
            session.readiness = readiness
            apparel.session = session
            session.apparelFeedback = apparel
            entry.log = log
            log.entries = [entry]
            ingredient.meal = meal
            meal.ingredients = [ingredient]
            split.run = run
            run.splits = [split]
            route.run = run
            run.route = route
            membership.club = club
            club.memberships = [membership]
            challenge.club = club
            club.challenges = [challenge]
            challengeEntry.challenge = challenge
            challenge.entries = [challengeEntry]

            context.insert(athlete)
            context.insert(session)
            context.insert(exercise)
            context.insert(set)
            context.insert(readiness)
            context.insert(apparel)
            context.insert(log)
            context.insert(entry)
            context.insert(meal)
            context.insert(ingredient)
            context.insert(run)
            context.insert(split)
            context.insert(route)
            context.insert(shoe)
            context.insert(settings)
            context.insert(score)
            context.insert(supplement)
            context.insert(custom)
            context.insert(weight)
            context.insert(marker)
            context.insert(diet)
            context.insert(club)
            context.insert(membership)
            context.insert(challenge)
            context.insert(challengeEntry)

            graph.athletes.append(athlete.id)
            graph.sessions.append(session.id)
            graph.exercises.append(exercise.id)
            graph.sets.append(set.id)
            graph.readiness.append(readiness.id)
            graph.apparel.append(apparel.id)
            graph.logs.append(log.id)
            graph.entries.append(entry.id)
            graph.meals.append(meal.id)
            graph.ingredients.append(ingredient.id)
            graph.runs.append(run.id)
            graph.splits.append(split.id)
            graph.routes.append(route.id)
            graph.shoes.append(shoe.id)
            graph.settings.append(settings.id)
            graph.scoreEvents.append(score.id)
            graph.supplements.append(supplement.id)
            graph.customExercises.append(custom.id)
            graph.weights.append(weight.id)
            graph.markers.append(marker.id)
            graph.diets.append(diet.id)
            graph.clubs.append(club.id)
            graph.memberships.append(membership.id)
            graph.challenges.append(challenge.id)
            graph.challengeEntries.append(challengeEntry.id)
        }
        try context.save()
        return graph
    }
}

@MainActor
private func assertChildGraph(_ ids: ChildGraphIDs, in context: ModelContext) throws {
    let athletes = try context.fetch(FetchDescriptor<Athlete>())
    let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
    let exercises = try context.fetch(FetchDescriptor<LoggedExercise>())
    let sets = try context.fetch(FetchDescriptor<LoggedSet>())
    let readiness = try context.fetch(FetchDescriptor<ReadinessCheck>())
    let apparel = try context.fetch(FetchDescriptor<ApparelFeedback>())
    let logs = try context.fetch(FetchDescriptor<NutritionLog>())
    let entries = try context.fetch(FetchDescriptor<NutritionEntry>())
    let meals = try context.fetch(FetchDescriptor<SavedMeal>())
    let ingredients = try context.fetch(FetchDescriptor<SavedMealIngredient>())
    let runs = try context.fetch(FetchDescriptor<Run>())
    let splits = try context.fetch(FetchDescriptor<RunSplit>())
    let routes = try context.fetch(FetchDescriptor<RunRoute>())

    XCTAssertEqual(athletes.map(\.id), [ids.athlete])
    XCTAssertEqual(sessions.map(\.id), [ids.session])
    XCTAssertEqual(exercises.map(\.id), [ids.exercise])
    XCTAssertEqual(sets.map(\.id), [ids.set])
    XCTAssertEqual(readiness.map(\.id), [ids.readiness])
    XCTAssertEqual(apparel.map(\.id), [ids.apparel])
    XCTAssertEqual(logs.map(\.id), [ids.nutritionLog])
    XCTAssertEqual(entries.map(\.id), [ids.nutritionEntry])
    XCTAssertEqual(meals.map(\.id), [ids.meal])
    XCTAssertEqual(ingredients.map(\.id), [ids.ingredient])
    XCTAssertEqual(runs.map(\.id), [ids.run])
    XCTAssertEqual(splits.map(\.id), [ids.split])
    XCTAssertEqual(routes.map(\.id), [ids.route])

    XCTAssertEqual(exercises.first?.session?.id, ids.session)
    XCTAssertEqual(sets.first?.exercise?.id, ids.exercise)
    XCTAssertEqual(readiness.first?.session?.id, ids.session)
    XCTAssertEqual(apparel.first?.session?.id, ids.session)
    XCTAssertEqual(entries.first?.log?.id, ids.nutritionLog)
    XCTAssertEqual(ingredients.first?.meal?.id, ids.meal)
    XCTAssertEqual(splits.first?.run?.id, ids.run)
    XCTAssertEqual(routes.first?.run?.id, ids.run)
}

@MainActor
private func assertChildGraphAbsent(in context: ModelContext) throws {
    XCTAssertEqual(try context.fetch(FetchDescriptor<Athlete>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutSession>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<LoggedExercise>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<LoggedSet>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<ReadinessCheck>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<ApparelFeedback>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<NutritionLog>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<NutritionEntry>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<SavedMeal>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<SavedMealIngredient>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<Run>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<RunSplit>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<RunRoute>()).count, 0)
}

/// Ids for two rows of each model. Index 0 and index 1 are one linked pair.
private struct FullEraseGraph {
    var athletes: [UUID] = []
    var sessions: [UUID] = []
    var exercises: [UUID] = []
    var sets: [UUID] = []
    var readiness: [UUID] = []
    var apparel: [UUID] = []
    var logs: [UUID] = []
    var entries: [UUID] = []
    var meals: [UUID] = []
    var ingredients: [UUID] = []
    var runs: [UUID] = []
    var splits: [UUID] = []
    var routes: [UUID] = []
    var shoes: [UUID] = []
    var settings: [UUID] = []
    var scoreEvents: [UUID] = []
    var supplements: [UUID] = []
    var customExercises: [String] = []
    var weights: [UUID] = []
    var markers: [UUID] = []
    var diets: [UUID] = []
    var clubs: [UUID] = []
    var memberships: [UUID] = []
    var challenges: [UUID] = []
    var challengeEntries: [UUID] = []
}

/// One probe per persistent model. `testEraseTargetsMatchCurrentSchema`
/// fails if this list and `CMSNSchemaV5.models` diverge.
@MainActor
private struct EraseTargetProbe {
    var type: any PersistentModel.Type
    var count: (ModelContext) throws -> Int

    static func modelName(_ type: any PersistentModel.Type) -> String {
        var name = String(describing: type)
        if let dot = name.lastIndex(of: ".") {
            let tail = String(name[name.index(after: dot)...])
            if tail != "Type" {
                name = tail
            }
        }
        let typeSuffix = ".Type"
        if name.hasSuffix(typeSuffix) {
            name = String(name.dropLast(typeSuffix.count))
        }
        return name
    }

    @MainActor
    static let all: [EraseTargetProbe] = [
        EraseTargetProbe(type: Athlete.self, count: { try $0.fetch(FetchDescriptor<Athlete>()).count }),
        EraseTargetProbe(type: CustomExercise.self, count: { try $0.fetch(FetchDescriptor<CustomExercise>()).count }),
        EraseTargetProbe(type: WorkoutSession.self, count: { try $0.fetch(FetchDescriptor<WorkoutSession>()).count }),
        EraseTargetProbe(type: LoggedExercise.self, count: { try $0.fetch(FetchDescriptor<LoggedExercise>()).count }),
        EraseTargetProbe(type: LoggedSet.self, count: { try $0.fetch(FetchDescriptor<LoggedSet>()).count }),
        EraseTargetProbe(type: ReadinessCheck.self, count: { try $0.fetch(FetchDescriptor<ReadinessCheck>()).count }),
        EraseTargetProbe(type: NutritionLog.self, count: { try $0.fetch(FetchDescriptor<NutritionLog>()).count }),
        EraseTargetProbe(type: NutritionEntry.self, count: { try $0.fetch(FetchDescriptor<NutritionEntry>()).count }),
        EraseTargetProbe(type: ApparelFeedback.self, count: { try $0.fetch(FetchDescriptor<ApparelFeedback>()).count }),
        EraseTargetProbe(type: ScoreEvent.self, count: { try $0.fetch(FetchDescriptor<ScoreEvent>()).count }),
        EraseTargetProbe(type: SavedMeal.self, count: { try $0.fetch(FetchDescriptor<SavedMeal>()).count }),
        EraseTargetProbe(type: SavedMealIngredient.self, count: { try $0.fetch(FetchDescriptor<SavedMealIngredient>()).count }),
        EraseTargetProbe(type: CustomSupplement.self, count: { try $0.fetch(FetchDescriptor<CustomSupplement>()).count }),
        EraseTargetProbe(type: WeightEntry.self, count: { try $0.fetch(FetchDescriptor<WeightEntry>()).count }),
        EraseTargetProbe(type: WeightHistorySeedMarker.self, count: { try $0.fetch(FetchDescriptor<WeightHistorySeedMarker>()).count }),
        EraseTargetProbe(type: Run.self, count: { try $0.fetch(FetchDescriptor<Run>()).count }),
        EraseTargetProbe(type: RunSplit.self, count: { try $0.fetch(FetchDescriptor<RunSplit>()).count }),
        EraseTargetProbe(type: RunRoute.self, count: { try $0.fetch(FetchDescriptor<RunRoute>()).count }),
        EraseTargetProbe(type: RunShoe.self, count: { try $0.fetch(FetchDescriptor<RunShoe>()).count }),
        EraseTargetProbe(type: RunSettings.self, count: { try $0.fetch(FetchDescriptor<RunSettings>()).count }),
        EraseTargetProbe(type: RunClub.self, count: { try $0.fetch(FetchDescriptor<RunClub>()).count }),
        EraseTargetProbe(type: ClubMembership.self, count: { try $0.fetch(FetchDescriptor<ClubMembership>()).count }),
        EraseTargetProbe(type: Challenge.self, count: { try $0.fetch(FetchDescriptor<Challenge>()).count }),
        EraseTargetProbe(type: ChallengeEntry.self, count: { try $0.fetch(FetchDescriptor<ChallengeEntry>()).count }),
        EraseTargetProbe(type: NutritionDietPreference.self, count: { try $0.fetch(FetchDescriptor<NutritionDietPreference>()).count }),
    ]
}

/// Names passed to `deleteFetched` inside `eraseEverything` only.
/// A delete written some other way is not seen. The function body is the
/// source between `func eraseEverything` and `func deleteFetched`.
private func eraseTargetNames(in source: String) -> [String] {
    guard let start = source.range(of: "func eraseEverything"),
          let end = source.range(of: "func deleteFetched") else {
        return []
    }
    var rest = String(source[start.lowerBound..<end.lowerBound])
    var names: [String] = []
    let needle = "deleteFetched("
    while let range = rest.range(of: needle) {
        rest = String(rest[range.upperBound...])
        let name = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        guard rest.dropFirst(name.count).hasPrefix(".self") else { continue }
        names.append(String(name))
    }
    return names
}

@MainActor
private func assertEveryTargetedTypeCount(_ expected: Int, in context: ModelContext) throws {
    for probe in EraseTargetProbe.all {
        let count = try probe.count(context)
        XCTAssertEqual(count, expected, EraseTargetProbe.modelName(probe.type))
    }
}

@MainActor
private func assertFullEraseGraph(_ graph: FullEraseGraph, in context: ModelContext) throws {
    try assertEveryTargetedTypeCount(2, in: context)

    let athletes = try context.fetch(FetchDescriptor<Athlete>())
    let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
    let exercises = try context.fetch(FetchDescriptor<LoggedExercise>())
    let sets = try context.fetch(FetchDescriptor<LoggedSet>())
    let readiness = try context.fetch(FetchDescriptor<ReadinessCheck>())
    let apparel = try context.fetch(FetchDescriptor<ApparelFeedback>())
    let logs = try context.fetch(FetchDescriptor<NutritionLog>())
    let entries = try context.fetch(FetchDescriptor<NutritionEntry>())
    let meals = try context.fetch(FetchDescriptor<SavedMeal>())
    let ingredients = try context.fetch(FetchDescriptor<SavedMealIngredient>())
    let runs = try context.fetch(FetchDescriptor<Run>())
    let splits = try context.fetch(FetchDescriptor<RunSplit>())
    let routes = try context.fetch(FetchDescriptor<RunRoute>())
    let shoes = try context.fetch(FetchDescriptor<RunShoe>())
    let settings = try context.fetch(FetchDescriptor<RunSettings>())
    let scores = try context.fetch(FetchDescriptor<ScoreEvent>())
    let supplements = try context.fetch(FetchDescriptor<CustomSupplement>())
    let customs = try context.fetch(FetchDescriptor<CustomExercise>())
    let weights = try context.fetch(FetchDescriptor<WeightEntry>())
    let markers = try context.fetch(FetchDescriptor<WeightHistorySeedMarker>())
    let diets = try context.fetch(FetchDescriptor<NutritionDietPreference>())
    let clubs = try context.fetch(FetchDescriptor<RunClub>())
    let memberships = try context.fetch(FetchDescriptor<ClubMembership>())
    let challenges = try context.fetch(FetchDescriptor<Challenge>())
    let challengeEntries = try context.fetch(FetchDescriptor<ChallengeEntry>())

    XCTAssertEqual(Set(athletes.map(\.id)), Set(graph.athletes))
    XCTAssertEqual(Set(sessions.map(\.id)), Set(graph.sessions))
    XCTAssertEqual(Set(exercises.map(\.id)), Set(graph.exercises))
    XCTAssertEqual(Set(sets.map(\.id)), Set(graph.sets))
    XCTAssertEqual(Set(readiness.map(\.id)), Set(graph.readiness))
    XCTAssertEqual(Set(apparel.map(\.id)), Set(graph.apparel))
    XCTAssertEqual(Set(logs.map(\.id)), Set(graph.logs))
    XCTAssertEqual(Set(entries.map(\.id)), Set(graph.entries))
    XCTAssertEqual(Set(meals.map(\.id)), Set(graph.meals))
    XCTAssertEqual(Set(ingredients.map(\.id)), Set(graph.ingredients))
    XCTAssertEqual(Set(runs.map(\.id)), Set(graph.runs))
    XCTAssertEqual(Set(splits.map(\.id)), Set(graph.splits))
    XCTAssertEqual(Set(routes.map(\.id)), Set(graph.routes))
    XCTAssertEqual(Set(shoes.map(\.id)), Set(graph.shoes))
    XCTAssertEqual(Set(settings.map(\.id)), Set(graph.settings))
    XCTAssertEqual(Set(scores.map(\.id)), Set(graph.scoreEvents))
    XCTAssertEqual(Set(supplements.map(\.id)), Set(graph.supplements))
    XCTAssertEqual(Set(customs.map(\.id)), Set(graph.customExercises))
    XCTAssertEqual(Set(weights.map(\.id)), Set(graph.weights))
    XCTAssertEqual(Set(markers.map(\.id)), Set(graph.markers))
    XCTAssertEqual(Set(diets.map(\.id)), Set(graph.diets))
    XCTAssertEqual(Set(clubs.map(\.id)), Set(graph.clubs))
    XCTAssertEqual(Set(memberships.map(\.id)), Set(graph.memberships))
    XCTAssertEqual(Set(challenges.map(\.id)), Set(graph.challenges))
    XCTAssertEqual(Set(challengeEntries.map(\.id)), Set(graph.challengeEntries))

    let sessionByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
    let exerciseByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    let setByID = Dictionary(uniqueKeysWithValues: sets.map { ($0.id, $0) })
    let readinessByID = Dictionary(uniqueKeysWithValues: readiness.map { ($0.id, $0) })
    let apparelByID = Dictionary(uniqueKeysWithValues: apparel.map { ($0.id, $0) })
    let logByID = Dictionary(uniqueKeysWithValues: logs.map { ($0.id, $0) })
    let entryByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    let mealByID = Dictionary(uniqueKeysWithValues: meals.map { ($0.id, $0) })
    let ingredientByID = Dictionary(uniqueKeysWithValues: ingredients.map { ($0.id, $0) })
    let runByID = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0) })
    let splitByID = Dictionary(uniqueKeysWithValues: splits.map { ($0.id, $0) })
    let routeByID = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })
    let shoeByID = Dictionary(uniqueKeysWithValues: shoes.map { ($0.id, $0) })
    let settingsByID = Dictionary(uniqueKeysWithValues: settings.map { ($0.id, $0) })
    let scoreByID = Dictionary(uniqueKeysWithValues: scores.map { ($0.id, $0) })
    let weightByID = Dictionary(uniqueKeysWithValues: weights.map { ($0.id, $0) })
    let dietByID = Dictionary(uniqueKeysWithValues: diets.map { ($0.id, $0) })
    let clubByID = Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
    let membershipByID = Dictionary(uniqueKeysWithValues: memberships.map { ($0.id, $0) })
    let challengeByID = Dictionary(uniqueKeysWithValues: challenges.map { ($0.id, $0) })
    let challengeEntryByID = Dictionary(uniqueKeysWithValues: challengeEntries.map { ($0.id, $0) })

    for index in 0..<2 {
        let session = try XCTUnwrap(sessionByID[graph.sessions[index]])
        let exercise = try XCTUnwrap(exerciseByID[graph.exercises[index]])
        let set = try XCTUnwrap(setByID[graph.sets[index]])
        let ready = try XCTUnwrap(readinessByID[graph.readiness[index]])
        let garment = try XCTUnwrap(apparelByID[graph.apparel[index]])
        let log = try XCTUnwrap(logByID[graph.logs[index]])
        let entry = try XCTUnwrap(entryByID[graph.entries[index]])
        let meal = try XCTUnwrap(mealByID[graph.meals[index]])
        let ingredient = try XCTUnwrap(ingredientByID[graph.ingredients[index]])
        let run = try XCTUnwrap(runByID[graph.runs[index]])
        let split = try XCTUnwrap(splitByID[graph.splits[index]])
        let route = try XCTUnwrap(routeByID[graph.routes[index]])
        let shoe = try XCTUnwrap(shoeByID[graph.shoes[index]])
        let setting = try XCTUnwrap(settingsByID[graph.settings[index]])
        let score = try XCTUnwrap(scoreByID[graph.scoreEvents[index]])
        let weight = try XCTUnwrap(weightByID[graph.weights[index]])
        let diet = try XCTUnwrap(dietByID[graph.diets[index]])
        let club = try XCTUnwrap(clubByID[graph.clubs[index]])
        let membership = try XCTUnwrap(membershipByID[graph.memberships[index]])
        let challenge = try XCTUnwrap(challengeByID[graph.challenges[index]])
        let challengeEntry = try XCTUnwrap(challengeEntryByID[graph.challengeEntries[index]])

        XCTAssertEqual(exercise.session?.id, session.id)
        XCTAssertEqual(session.loggedExercises.map(\.id), [exercise.id])
        XCTAssertEqual(set.exercise?.id, exercise.id)
        XCTAssertEqual(exercise.loggedSets.map(\.id), [set.id])
        XCTAssertEqual(ready.session?.id, session.id)
        XCTAssertEqual(session.readiness?.id, ready.id)
        XCTAssertEqual(garment.session?.id, session.id)
        XCTAssertEqual(session.apparelFeedback?.id, garment.id)
        XCTAssertEqual(entry.log?.id, log.id)
        XCTAssertEqual(log.entries.map(\.id), [entry.id])
        XCTAssertEqual(ingredient.meal?.id, meal.id)
        XCTAssertEqual(meal.ingredients.map(\.id), [ingredient.id])
        XCTAssertEqual(split.run?.id, run.id)
        XCTAssertEqual(run.splits.map(\.id), [split.id])
        XCTAssertEqual(route.run?.id, run.id)
        XCTAssertEqual(run.route?.id, route.id)
        XCTAssertEqual(run.athleteID, graph.athletes[index])
        XCTAssertEqual(run.shoeID, shoe.id)
        XCTAssertEqual(shoe.athleteID, graph.athletes[index])
        XCTAssertEqual(setting.athleteID, graph.athletes[index])
        XCTAssertEqual(weight.athleteID, graph.athletes[index])
        XCTAssertEqual(diet.athleteID, graph.athletes[index])
        XCTAssertEqual(membership.athleteID, graph.athletes[index])
        XCTAssertEqual(membership.club?.id, club.id)
        XCTAssertEqual(club.memberships.map(\.id), [membership.id])
        XCTAssertEqual(challenge.club?.id, club.id)
        XCTAssertEqual(club.challenges.map(\.id), [challenge.id])
        XCTAssertEqual(challengeEntry.challenge?.id, challenge.id)
        XCTAssertEqual(challenge.entries.map(\.id), [challengeEntry.id])
        XCTAssertEqual(challengeEntry.athleteID, graph.athletes[index])
        XCTAssertEqual(challengeEntry.runID, run.id)
        XCTAssertEqual(score.relatedSessionID, session.id)
    }
}

private struct MissingRepoFile: Error {
    var path: String
}
