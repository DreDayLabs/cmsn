import XCTest
import SwiftData
@testable import CMSNApp

@MainActor
final class RunSessionControllerTests: XCTestCase {
    private var container: ModelContainer!
    private var backupDirectory: URL!
    private var clock: TestClock!
    private var location: FakeLocation!
    private var motion: FakeMotion!
    private var speech: FakeSpeech!
    private var session: RunSessionController!

    override func setUp() {
        super.setUp()
        container = CMSNModelContainerFactory.makeInMemory()
        backupDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmsn-active-run-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        ActiveRunBackup.directoryOverride = backupDirectory
        clock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))
        location = FakeLocation()
        motion = FakeMotion()
        speech = FakeSpeech()
        session = makeSession()
    }

    override func tearDown() {
        ActiveRunBackup.clear()
        ActiveRunBackup.directoryOverride = nil
        try? FileManager.default.removeItem(at: backupDirectory)
        session = nil
        container = nil
        super.tearDown()
    }

    func testOutdoorStartUsesLocationAndCancelStopsIt() {
        let athlete = makeAthlete()
        session.preferences.environment = .outdoor
        session.start(context: container.mainContext, athleteID: athlete.id, weightKG: 70, heightCM: 180)
        XCTAssertEqual(location.starts, 1)
        XCTAssertEqual(location.lastBackground, true)
        XCTAssertEqual(motion.starts, 0)
        XCTAssertEqual(speech.spoken, ["3"])
        session.cancelCountdown()
        XCTAssertEqual(session.stage, .idle)
        XCTAssertGreaterThanOrEqual(location.stops, 1)
    }

    func testIndoorStartDoesNotOpenLocation() {
        let athlete = makeAthlete()
        session.preferences.environment = .indoor
        session.start(context: container.mainContext, athleteID: athlete.id, weightKG: 70, heightCM: 180)
        XCTAssertEqual(location.starts, 0)
        XCTAssertEqual(motion.starts, 1)
        reachLive()
        session.ingestMotion(MotionUpdate(distanceMeters: nil, steps: 100, cadenceStepsPerSecond: 1.6, timestamp: clock.date))
        XCTAssertGreaterThan(session.distanceMeters, 0)
        XCTAssertEqual(location.starts, 0)
    }

    func testCountdownReachesLiveAndAKilometerCueSpeaksOnce() {
        let athlete = makeAthlete()
        session.preferences.cueFrequency = .everyKilometer
        session.start(context: container.mainContext, athleteID: athlete.id, weightKG: 70, heightCM: 180)
        reachLive()
        XCTAssertEqual(session.stage, .live)
        XCTAssertEqual(speech.spoken, ["3", "2", "1", "Go."])

        session.ingestLocation(north(0))
        for step in 1...9 {
            clock.date = clock.date.addingTimeInterval(20)
            session.ingestLocation(north(Double(step) * 120))
        }
        XCTAssertGreaterThan(session.distanceMeters, 1_000)
        XCTAssertEqual(speech.spoken.filter { $0.contains("kilometer") }.count, 1)
    }

    func testASpikeDoesNotAddDistanceAndALatePointAfterTheHoldIsIgnored() {
        let athlete = makeAthlete()
        session.start(context: container.mainContext, athleteID: athlete.id, weightKG: 70, heightCM: 180)
        reachLive()
        session.ingestLocation(north(0))
        clock.date = clock.date.addingTimeInterval(20)
        session.ingestLocation(north(100))
        let before = session.distanceMeters
        XCTAssertGreaterThan(before, 50)

        clock.date = clock.date.addingTimeInterval(1)
        session.ingestLocation(TrackPoint(
            latitude: 37.05,
            longitude: -122,
            altitudeMeters: 10,
            timestamp: clock.date,
            horizontalAccuracy: 5,
            speedMetersPerSecond: 3
        ))
        XCTAssertEqual(session.distanceMeters, before, accuracy: 0.01)

        session.commitHoldToEnd()
        XCTAssertEqual(session.stage, .finished)
        XCTAssertNotNil(session.finishedRunID)
        XCTAssertGreaterThanOrEqual(location.stops, 1)
        let frozen = session.distanceMeters
        clock.date = clock.date.addingTimeInterval(20)
        session.ingestLocation(north(800))
        XCTAssertEqual(session.distanceMeters, frozen, accuracy: 0.01)
    }

    func testSilencedCuesDoNotSpeak() {
        let athlete = makeAthlete()
        session.preferences.cuesSilenced = true
        session.preferences.cueFrequency = .everyKilometer
        session.start(context: container.mainContext, athleteID: athlete.id, weightKG: 70, heightCM: 180)
        reachLive()
        session.ingestLocation(north(0))
        for step in 1...9 {
            clock.date = clock.date.addingTimeInterval(20)
            session.ingestLocation(north(Double(step) * 120))
        }
        XCTAssertTrue(speech.spoken.isEmpty)
        XCTAssertGreaterThan(session.distanceMeters, 1_000)
    }

    func testWatchInboxImportsOnceAndSkipsASecondHealthWrite() async throws {
        let athlete = makeAthlete()
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = WatchRunPayload(
            version: WatchRunPayload.currentVersion,
            id: UUID(),
            startedAt: started,
            endedAt: started.addingTimeInterval(80),
            environment: .outdoor,
            distanceMeters: 1,
            movingSeconds: 40,
            pausedSeconds: 0,
            elevationGainMeters: 0,
            calories: 12,
            averageHeartRate: nil,
            samples: [north(0, at: started), north(100, at: started.addingTimeInterval(20))],
            trace: [
                DistanceSample(distanceMeters: 0, elapsedSeconds: 0),
                DistanceSample(distanceMeters: 100, elapsedSeconds: 40),
            ],
            wroteHealthKitOnWatch: true
        )
        let inbox = WatchRunInbox(container: container)
        let data = try payload.encoded()
        await inbox.importData(data)
        await inbox.importData(data)
        let runs = try container.mainContext.fetch(FetchDescriptor<Run>())
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].athleteID, athlete.id)
        XCTAssertEqual(runs[0].source, .watch)
        XCTAssertEqual(runs[0].healthSyncState, .watchOwned)
        XCTAssertTrue(runs[0].ownedByWatchHealth)
        XCTAssertGreaterThan(runs[0].distanceMeters, 50)
        XCTAssertEqual(runs[0].splits.count, 1)
    }

    private func makeSession() -> RunSessionController {
        let clockBox = clock!
        return RunSessionController(
            location: location,
            motion: motion,
            speech: speech,
            heart: FakeHeart(),
            health: FakeHealth(),
            automaticallyTicks: false,
            clock: { clockBox.date },
            haptic: { _ in },
            setIdleTimerDisabled: { _ in }
        )
    }

    private func reachLive() {
        session.advance()
        session.advance()
        session.advance()
    }

    private func makeAthlete() -> Athlete {
        let athlete = Athlete(age: 30, heightCM: 180, weightKG: 70)
        container.mainContext.insert(athlete)
        try? container.mainContext.save()
        return athlete
    }

    private func north(_ meters: Double, at date: Date? = nil) -> TrackPoint {
        TrackPoint(
            latitude: 37 + meters / 111_320,
            longitude: -122,
            altitudeMeters: 10,
            timestamp: date ?? clock.date,
            horizontalAccuracy: 5,
            speedMetersPerSecond: 3
        )
    }
}

private final class TestClock {
    var date: Date
    init(_ date: Date) { self.date = date }
}

private final class FakeLocation: RunLocationProviding {
    var onPoint: ((TrackPoint) -> Void)?
    var onDenied: (() -> Void)?
    var starts = 0
    var stops = 0
    var lastBackground: Bool?
    func startUpdates(allowsBackground: Bool) {
        starts += 1
        lastBackground = allowsBackground
    }
    func stopUpdates() { stops += 1 }
}

private final class FakeMotion: RunMotionProviding {
    var onUpdate: ((MotionUpdate) -> Void)?
    var starts = 0
    var stops = 0
    func start() { starts += 1 }
    func stop() { stops += 1 }
}

private final class FakeSpeech: RunSpeechProviding {
    var spoken: [String] = []
    func speak(_ text: String) { spoken.append(text) }
    func stop() {}
    func setSilenced(_ silenced: Bool) {}
}

private final class FakeHeart: HeartRateProviding {
    var onHeartRate: ((Double) -> Void)?
    func start(strap: Bool) {}
    func stop() {}
}

@MainActor
private final class FakeHealth: HealthRunWriting {
    func liveAuthorizationState() -> HealthAuthorizationState { .authorized }
    func requestAuthorization() async -> HealthAuthorizationState { .authorized }
    func sync(run: Run, context: ModelContext) async {}
    func retryPending(in context: ModelContext) async {}
}
