import XCTest
@testable import CMSNApp

final class RunMathTests: XCTestCase {
    func testHaversineOneDegreeOfLongitudeAtTheEquator() {
        let start = point(latitude: 0, longitude: 0, at: 0)
        let end = point(latitude: 0, longitude: 1, at: 1)
        XCTAssertEqual(RunMath.meters(from: start, to: end), 111_195, accuracy: 50)
    }

    func testPaceFormatAndSplits() {
        XCTAssertEqual(RunMath.formatPace(300), "5:00")
        let samples = [
            DistanceSample(distanceMeters: 0, elapsedSeconds: 0),
            DistanceSample(distanceMeters: 500, elapsedSeconds: 150),
            DistanceSample(distanceMeters: 1_000, elapsedSeconds: 300),
            DistanceSample(distanceMeters: 1_500, elapsedSeconds: 480),
        ]
        let splits = RunMath.splits(samples: samples, unitMeters: 1_000)
        XCTAssertEqual(splits.count, 2)
        XCTAssertEqual(splits[0].distanceMeters, 1_000, accuracy: 0.01)
        XCTAssertEqual(splits[0].elapsedSeconds, 300, accuracy: 0.01)
        XCTAssertFalse(splits[0].isPartial)
        XCTAssertEqual(splits[1].distanceMeters, 500, accuracy: 0.01)
        XCTAssertEqual(splits[1].elapsedSeconds, 180, accuracy: 0.01)
        XCTAssertTrue(splits[1].isPartial)
    }

    func testFirstCoveringIsARecordAndASlowerRepeatIsNot() {
        let mile = RunDistanceUnit.mileMeters
        let first = summary(distance: mile, seconds: 500)
        let firstHits = RunMath.records(for: first, against: [])
        XCTAssertTrue(firstHits.contains { $0.kind == .mile && $0.previousSeconds == nil })

        let slower = summary(distance: mile, seconds: 560)
        XCTAssertFalse(RunMath.records(for: slower, against: [first]).contains { $0.kind == .mile })

        let faster = summary(distance: mile, seconds: 450)
        let fasterHit = RunMath.records(for: faster, against: [first]).first { $0.kind == .mile }
        XCTAssertEqual(fasterHit?.previousSeconds, 500)

        let fiveK = summary(distance: 5_000, seconds: 1_500)
        XCTAssertTrue(RunMath.records(for: fiveK, against: []).contains { $0.kind == .fiveK })
        let tenK = summary(distance: 10_000, seconds: 3_200)
        XCTAssertTrue(RunMath.records(for: tenK, against: []).contains { $0.kind == .tenK })
    }

    func testLongestRecordNeedsOneHundredMetersAndARealIncrease() {
        let short = summary(distance: 90, seconds: 40)
        XCTAssertFalse(RunMath.records(for: short, against: []).contains { $0.kind == .longest })

        let first = summary(distance: 200, seconds: 80)
        XCTAssertTrue(RunMath.records(for: first, against: []).contains { $0.kind == .longest })

        let same = summary(distance: 200, seconds: 90)
        XCTAssertFalse(RunMath.records(for: same, against: [first]).contains { $0.kind == .longest })

        let longer = summary(distance: 350, seconds: 140)
        XCTAssertTrue(RunMath.records(for: longer, against: [first]).contains { $0.kind == .longest })
    }

    func testSpikeRejectionKeepsAHumanGapAndDropsATeleport() {
        let origin = point(latitude: 37, longitude: -122, at: 0)
        XCTAssertFalse(RunMath.accept(point(latitude: 37, longitude: -122, at: 1, accuracy: 80), after: origin))
        XCTAssertFalse(RunMath.accept(point(latitude: 37, longitude: -122, at: 1, accuracy: -1), after: origin))
        XCTAssertFalse(RunMath.accept(point(latitude: 37, longitude: -122, at: 0.1), after: origin))

        let step = point(latitude: 37 + 100 / 111_320, longitude: -122, at: 20)
        XCTAssertTrue(RunMath.accept(step, after: origin))

        let teleport = point(latitude: 37.05, longitude: -122, at: 1)
        XCTAssertFalse(RunMath.accept(teleport, after: origin))

        let tunnel = point(latitude: 37 + 400 / 111_320, longitude: -122, at: 80)
        XCTAssertTrue(RunMath.accept(tunnel, after: origin))
    }

    func testSmoothingMovesTheMiddleFixAndLeavesTheEnds() {
        let points = [
            point(latitude: 37, longitude: -122, at: 0),
            point(latitude: 37.002, longitude: -122, at: 10),
            point(latitude: 37.004, longitude: -122, at: 20),
        ]
        let smoothed = RunMath.smooth(points)
        XCTAssertEqual(smoothed[0].latitude, points[0].latitude, accuracy: 0.000_000_1)
        XCTAssertEqual(smoothed[2].latitude, points[2].latitude, accuracy: 0.000_000_1)
        XCTAssertNotEqual(smoothed[1].latitude, points[1].latitude)
        XCTAssertEqual(RunMath.distance(of: points), RunMath.distance(of: RunMath.accepted(points)), accuracy: 0.01)
    }

    func testElevationIgnoresNoiseAndSpikes() {
        let gain = RunMath.elevationGainMeters(altitudes: [10, 10.2, 12, 40, 13])
        XCTAssertEqual(gain, 2.8, accuracy: 0.001)
    }

    func testCaloriesStayInRangeAndRiseWithWeight() {
        let base = RunMath.kilocalories(weightKG: 70, movingSeconds: 1_800, distanceMeters: 5_000)
        XCTAssertGreaterThan(base, 200)
        XCTAssertLessThan(base, 800)
        let heavier = RunMath.kilocalories(weightKG: 100, movingSeconds: 1_800, distanceMeters: 5_000)
        XCTAssertGreaterThan(heavier, base)
        XCTAssertEqual(RunMath.kilocalories(weightKG: 10, movingSeconds: 1_800, distanceMeters: 5_000), base, accuracy: 0.01)
    }

    func testIndoorStrideUsesHeightOrTheFallback() {
        XCTAssertEqual(RunMath.strideMeters(heightCM: 180), 1.8 * 0.415, accuracy: 0.0001)
        XCTAssertEqual(RunMath.indoorMeters(steps: 1_000, heightCM: nil), 780, accuracy: 0.01)
        XCTAssertEqual(RunMath.indoorMeters(steps: -3, heightCM: 180), 0)
    }

    func testCuesCrossOnceAndStayQuietWhenSilenced() {
        XCTAssertTrue(RunMath.shouldAnnounce(
            frequency: .everyKilometer,
            silenced: false,
            previousDistance: 900,
            distance: 1_050,
            previousElapsed: 200,
            elapsed: 250
        ))
        XCTAssertFalse(RunMath.shouldAnnounce(
            frequency: .everyKilometer,
            silenced: true,
            previousDistance: 900,
            distance: 1_050,
            previousElapsed: 200,
            elapsed: 250
        ))
        XCTAssertFalse(RunMath.shouldAnnounce(
            frequency: .off,
            silenced: false,
            previousDistance: 0,
            distance: 5_000,
            previousElapsed: 0,
            elapsed: 1_000
        ))
        let sentence = RunMath.cueSentence(
            distanceMeters: 1_000,
            movingSeconds: 300,
            unit: .kilometers,
            frequency: .everyKilometer
        )
        XCTAssertEqual(sentence, "1 kilometer. 5:00 pace.")
    }

    func testLevelsAreCMSNNamesInGray() {
        XCTAssertEqual(RunLevel.current(lifetimeMeters: 0).name, "Ash")
        XCTAssertEqual(RunLevel.current(lifetimeMeters: 25_000).name, "Flint")
        XCTAssertEqual(RunLevel.current(lifetimeMeters: 5_000_000).name, "House")
        XCTAssertEqual(RunLevel.progress(lifetimeMeters: 5_000_000), 1)
        let banned = ["yellow", "orange", "green", "blue", "purple", "volt", "vault", "nike"]
        for level in RunLevel.all {
            let name = level.name.lowercased()
            for word in banned {
                XCTAssertFalse(name.contains(word), level.name)
            }
            assertGray(level.toneHex)
        }
        assertGray(RunMath.toneHex(paceSecondsPerMeter: 0.3, fastest: 0.2, slowest: 0.5))
        assertGray(RunMath.toneHex(paceSecondsPerMeter: 0.5, fastest: 0.2, slowest: 0.5))
    }

    func testWeeklyStreakIsNotADailyCount() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 1, day: 7))!
        let thursday = calendar.date(from: DateComponents(year: 2026, month: 1, day: 8))!
        XCTAssertEqual(RunMath.weeklyStreak(runDates: [wednesday, thursday], now: thursday, calendar: calendar), 1)

        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: thursday)!.start
        let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek)!
        let twoBack = calendar.date(byAdding: .weekOfYear, value: -1, to: previous)!
        XCTAssertEqual(RunMath.weeklyStreak(runDates: [previous, twoBack], now: thursday, calendar: calendar), 2)
        XCTAssertEqual(RunMath.weeklyStreak(runDates: [twoBack], now: thursday, calendar: calendar), 0)
    }

    func testShoeReminderAtEightyAndOneHundredPercent() {
        let limit = ShoeMileage.defaultReplacementMeters
        XCTAssertEqual(ShoeMileage.reminder(accumulatedMeters: limit * 0.79, limitMeters: limit), .none)
        XCTAssertEqual(ShoeMileage.reminder(accumulatedMeters: limit * 0.8, limitMeters: limit), .soon)
        XCTAssertEqual(ShoeMileage.reminder(accumulatedMeters: limit, limitMeters: limit), .due)
    }

    func testHealthPolicyUsesOnlyTheLiveAuthorization() {
        let id = UUID()
        XCTAssertEqual(HealthSyncPolicy.nextAction(liveState: .authorized, healthWorkoutUUID: id, ownedByWatchHealth: false), .skipAlreadySynced)
        XCTAssertEqual(HealthSyncPolicy.nextAction(liveState: .authorized, healthWorkoutUUID: nil, ownedByWatchHealth: true), .skipWatchOwned)
        XCTAssertEqual(HealthSyncPolicy.nextAction(liveState: .notDetermined, healthWorkoutUUID: nil, ownedByWatchHealth: false), .requestAuthorization)
        XCTAssertEqual(HealthSyncPolicy.nextAction(liveState: .authorized, healthWorkoutUUID: nil, ownedByWatchHealth: false), .write)
        XCTAssertEqual(HealthSyncPolicy.nextAction(liveState: .denied, healthWorkoutUUID: nil, ownedByWatchHealth: false), .holdAndExplainDenied)
        XCTAssertEqual(HealthSyncPolicy.nextAction(liveState: .unavailable, healthWorkoutUUID: nil, ownedByWatchHealth: false), .holdUnavailable)
    }

    func testWatchPayloadRoundTripAndHeartRateParser() {
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = WatchRunPayload(
            version: WatchRunPayload.currentVersion,
            id: UUID(),
            startedAt: started,
            endedAt: started.addingTimeInterval(600),
            environment: .outdoor,
            distanceMeters: 1_200,
            movingSeconds: 400,
            pausedSeconds: 12,
            elevationGainMeters: 8,
            calories: 90,
            averageHeartRate: 148,
            samples: [point(latitude: 37, longitude: -122, at: 0)],
            trace: [DistanceSample(distanceMeters: 1_200, elapsedSeconds: 400)],
            wroteHealthKitOnWatch: true
        )
        let decoded = try? WatchRunPayload.decode(try payload.encoded())
        XCTAssertEqual(decoded, payload)
        XCTAssertEqual(HeartRateService.beatsPerMinute(from: Data([0x00, 72])), 72)
        XCTAssertEqual(HeartRateService.beatsPerMinute(from: Data([0x01, 0x2C, 0x01])), 300)
        XCTAssertNil(HeartRateService.beatsPerMinute(from: Data([0x00])))
    }

    func testRunClubSlotStaysClosed() {
        XCTAssertEqual(RunClubNavigationSlot.phase, 2)
        XCTAssertFalse(RunClubNavigationSlot.isPresented)
    }

    private func assertGray(_ hex: UInt32) {
        let red = (hex >> 16) & 0xFF
        let green = (hex >> 8) & 0xFF
        let blue = hex & 0xFF
        XCTAssertEqual(red, green)
        XCTAssertEqual(green, blue)
    }

    private func summary(distance: Double, seconds: Double) -> RunSummary {
        RunSummary(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            distanceMeters: distance,
            movingSeconds: seconds,
            samples: []
        )
    }

    private func point(latitude: Double, longitude: Double, at seconds: TimeInterval, accuracy: Double = 5) -> TrackPoint {
        TrackPoint(
            latitude: latitude,
            longitude: longitude,
            altitudeMeters: 10,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000 + seconds),
            horizontalAccuracy: accuracy,
            speedMetersPerSecond: 3
        )
    }
}
