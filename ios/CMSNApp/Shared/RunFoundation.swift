import Foundation

/// Pure run math, naming, and sync policy. Foundation only, so the phone
/// target, the watch target, and unit tests all share one implementation.
/// Nothing in this file starts location, Health, motion, or audio.

enum RunJSON {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum RunEnvironment: String, Codable, CaseIterable, Identifiable {
    case outdoor
    case indoor
    var id: String { rawValue }
    var title: String { self == .outdoor ? "Outdoor" : "Indoor" }
}

enum RunSource: String, Codable {
    case phone
    case watch
}

enum RunStatus: String, Codable {
    case active
    case ended
    case discarded
}

enum RunDistanceUnit: String, Codable, CaseIterable, Identifiable {
    case kilometers
    case miles
    var id: String { rawValue }

    static let mileMeters = 1_609.344

    var meters: Double { self == .kilometers ? 1_000 : Self.mileMeters }
    var label: String { self == .kilometers ? "km" : "mi" }
    var paceSuffix: String { self == .kilometers ? "/km" : "/mi" }
    var spokenNoun: (Int) -> String {
        switch self {
        case .kilometers:
            return { $0 == 1 ? "kilometer" : "kilometers" }
        case .miles:
            return { $0 == 1 ? "mile" : "miles" }
        }
    }
}

enum CueFrequency: String, Codable, CaseIterable, Identifiable {
    case off
    case everyKilometer
    case everyMile
    case everyFiveMinutes
    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .everyKilometer: return "Every kilometer"
        case .everyMile: return "Every mile"
        case .everyFiveMinutes: return "Every 5 minutes"
        }
    }
}

enum PaceHeadline: String, Codable, CaseIterable, Identifiable {
    case current
    case average
    var id: String { rawValue }
    var title: String { self == .current ? "Current pace" : "Average pace" }
}

enum RunGround: String, Codable, CaseIterable, Identifiable {
    case road, trail, track, treadmill, mixed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .road: return "Road"
        case .trail: return "Trail"
        case .track: return "Track"
        case .treadmill: return "Treadmill"
        case .mixed: return "Mixed"
        }
    }
}

enum RunEffort: String, Codable, CaseIterable, Identifiable {
    case easy, steady, hard, allOut
    var id: String { rawValue }
    var title: String {
        switch self {
        case .easy: return "Easy"
        case .steady: return "Steady"
        case .hard: return "Hard"
        case .allOut: return "All out"
        }
    }
}

enum RunMood: String, Codable, CaseIterable, Identifiable {
    case flat, good, sharp, heavy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .flat: return "Flat"
        case .good: return "Good"
        case .sharp: return "Sharp"
        case .heavy: return "Heavy"
        }
    }
}

enum RecordKind: String, Codable, CaseIterable, Identifiable {
    case mile
    case fiveK
    case tenK
    case longest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mile: return "Fastest mile"
        case .fiveK: return "Fastest 5K"
        case .tenK: return "Fastest 10K"
        case .longest: return "Longest run"
        }
    }
    var targetMeters: Double? {
        switch self {
        case .mile: return RunDistanceUnit.mileMeters
        case .fiveK: return 5_000
        case .tenK: return 10_000
        case .longest: return nil
        }
    }
}

enum HealthAuthorizationState: String, Equatable {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

enum HealthSyncRecord: String, Codable {
    case pending
    case synced
    case denied
    case unavailable
    case watchOwned
}

enum HealthSyncAction: Equatable {
    case requestAuthorization
    case write
    case holdAndExplainDenied
    case holdUnavailable
    case skipAlreadySynced
    case skipWatchOwned
}

/// Decides what a sync attempt may do. The only authorization input is the
/// live HealthKit status. A boolean remembered from an earlier launch is
/// not an input — that remembered flag is how sync dies quietly.
enum HealthSyncPolicy {
    static func nextAction(
        liveState: HealthAuthorizationState,
        healthWorkoutUUID: UUID?,
        ownedByWatchHealth: Bool
    ) -> HealthSyncAction {
        if healthWorkoutUUID != nil { return .skipAlreadySynced }
        if ownedByWatchHealth { return .skipWatchOwned }
        switch liveState {
        case .notDetermined: return .requestAuthorization
        case .authorized: return .write
        case .denied: return .holdAndExplainDenied
        case .unavailable: return .holdUnavailable
        }
    }
}

struct RunPreferenceValues: Equatable, Codable {
    var environment: RunEnvironment = .outdoor
    var countdownSeconds: Int = 3
    var autoPauseEnabled: Bool = true
    var cueFrequency: CueFrequency = .everyKilometer
    var cuesSilenced: Bool = false
    var paceHeadline: PaceHeadline = .current
    var distanceUnit: RunDistanceUnit = .kilometers
    /// Off until the athlete asks. Creating a Bluetooth scan at the first
    /// run would prompt every person, including those with no strap.
    var heartRateStrapEnabled: Bool = false

    var clampedCountdown: Int { [3, 6, 9].contains(countdownSeconds) ? countdownSeconds : 3 }

    static func fresh(unit: RunDistanceUnit) -> RunPreferenceValues {
        var values = RunPreferenceValues()
        values.distanceUnit = unit
        values.cueFrequency = unit == .miles ? .everyMile : .everyKilometer
        return values
    }
}

struct TrackPoint: Codable, Equatable, Hashable {
    var latitude: Double
    var longitude: Double
    var altitudeMeters: Double?
    var timestamp: Date
    var horizontalAccuracy: Double
    var speedMetersPerSecond: Double
}

struct DistanceSample: Codable, Equatable, Hashable {
    var distanceMeters: Double
    var elapsedSeconds: Double
}

struct SplitDraft: Equatable {
    var index: Int
    var distanceMeters: Double
    var elapsedSeconds: Double
    var isPartial: Bool

    var paceSecondsPerMeter: Double {
        guard distanceMeters > 0, elapsedSeconds > 0 else { return 0 }
        return elapsedSeconds / distanceMeters
    }
}

struct RunSummary: Equatable, Identifiable {
    var id: UUID
    var startedAt: Date
    var distanceMeters: Double
    var movingSeconds: Double
    var samples: [DistanceSample]
}

struct PersonalRecordHit: Equatable, Identifiable {
    var kind: RecordKind
    var seconds: Double
    var previousSeconds: Double?
    var distanceMeters: Double
    var id: String { kind.rawValue }
}

struct RunLevel: Equatable, Identifiable {
    var name: String
    var minimumMeters: Double
    /// Gray step. The run levels are named for CMSN, and the tone stays
    /// inside the black / white / gray palette. No borrowed running-club hue.
    var toneHex: UInt32
    var id: String { name }

    static let all: [RunLevel] = [
        RunLevel(name: "Ash", minimumMeters: 0, toneHex: 0x6E6E6E),
        RunLevel(name: "Flint", minimumMeters: 25_000, toneHex: 0x8A8A8A),
        RunLevel(name: "Slate", minimumMeters: 100_000, toneHex: 0xA3A3A3),
        RunLevel(name: "Iron", minimumMeters: 250_000, toneHex: 0xBCBCBC),
        RunLevel(name: "Graphite", minimumMeters: 500_000, toneHex: 0xD4D4D4),
        RunLevel(name: "Carbon", minimumMeters: 1_000_000, toneHex: 0xE4E4E4),
        RunLevel(name: "Obsidian", minimumMeters: 2_500_000, toneHex: 0xF4F4F4),
        RunLevel(name: "House", minimumMeters: 5_000_000, toneHex: 0xFFFFFF),
    ]

    static func current(lifetimeMeters: Double) -> RunLevel {
        all.last { lifetimeMeters + 0.001 >= $0.minimumMeters } ?? all[0]
    }

    static func next(after level: RunLevel) -> RunLevel? {
        guard let index = all.firstIndex(of: level), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    static func progress(lifetimeMeters: Double) -> Double {
        let level = current(lifetimeMeters: lifetimeMeters)
        guard let upcoming = next(after: level) else { return 1 }
        let span = upcoming.minimumMeters - level.minimumMeters
        guard span > 0 else { return 1 }
        return min(1, max(0, (lifetimeMeters - level.minimumMeters) / span))
    }
}

struct RunBadge: Equatable, Identifiable {
    var id: String
    var title: String
    var detail: String
}

enum TrendGranularity: String, CaseIterable, Identifiable {
    case week
    case month
    var id: String { rawValue }
    var title: String { self == .week ? "Week" : "Month" }
}

struct TrendBucket: Equatable, Identifiable {
    var start: Date
    var distanceMeters: Double
    var movingSeconds: Double
    var id: Date { start }

    var paceSecondsPerMeter: Double? {
        guard distanceMeters > 0, movingSeconds > 0 else { return nil }
        return movingSeconds / distanceMeters
    }
}

enum ShoeReminder: Equatable {
    case none
    case soon
    case due
}

enum ShoeMileage {
    /// 500 miles, the usual replacement window, stored in meters.
    static let defaultReplacementMeters = 500 * RunDistanceUnit.mileMeters

    static func reminder(accumulatedMeters: Double, limitMeters: Double) -> ShoeReminder {
        guard limitMeters > 0, accumulatedMeters.isFinite, accumulatedMeters >= 0 else { return .none }
        let ratio = accumulatedMeters / limitMeters
        if ratio >= 1 { return .due }
        if ratio >= 0.8 { return .soon }
        return .none
    }
}

struct WatchRunPayload: Codable, Equatable {
    var version: Int
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var environment: RunEnvironment
    var distanceMeters: Double
    var movingSeconds: Double
    var pausedSeconds: Double
    var elevationGainMeters: Double
    var calories: Double
    var averageHeartRate: Double?
    var samples: [TrackPoint]
    var trace: [DistanceSample]
    /// True when the watch already saved an HealthKit workout. The phone
    /// must not write a second copy into Apple Health.
    var wroteHealthKitOnWatch: Bool

    static let currentVersion = 1

    func encoded() throws -> Data {
        try RunJSON.encoder().encode(self)
    }

    static func decode(_ data: Data) throws -> WatchRunPayload {
        try RunJSON.decoder().decode(WatchRunPayload.self, from: data)
    }
}

enum RunMath {
    static let maxPlausibleSpeed = 9.0
    static let maxHorizontalAccuracy = 50.0
    static let halfMarathonMeters = 21_097.5

    static func meters(from: TrackPoint, to: TrackPoint) -> Double {
        let earth = 6_371_000.0
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earth * c
    }

    static func distance(of points: [TrackPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for index in 1..<points.count {
            total += meters(from: points[index - 1], to: points[index])
        }
        return total
    }

    /// Drops a fix that is too coarse, out of order, or too fast to be a
    /// person running. A long gap is kept when the implied speed is still
    /// human — that is a tunnel, not a teleport.
    static func accept(_ point: TrackPoint, after previous: TrackPoint?) -> Bool {
        guard point.horizontalAccuracy >= 0, point.horizontalAccuracy <= maxHorizontalAccuracy else { return false }
        guard abs(point.latitude) <= 90, abs(point.longitude) <= 180 else { return false }
        guard let previous else { return true }
        let dt = point.timestamp.timeIntervalSince(previous.timestamp)
        guard dt >= 0.2 else { return false }
        let speed = meters(from: previous, to: point) / dt
        return speed <= maxPlausibleSpeed
    }

    static func accepted(_ points: [TrackPoint]) -> [TrackPoint] {
        var kept: [TrackPoint] = []
        for point in points {
            if accept(point, after: kept.last) { kept.append(point) }
        }
        return kept
    }

    /// Light 3-point average for the drawn line. Distance is measured on
    /// the un-averaged accepted points so the line does not shrink the run.
    static func smooth(_ points: [TrackPoint]) -> [TrackPoint] {
        guard points.count >= 3 else { return points }
        var result = points
        for index in 1..<(points.count - 1) {
            let a = points[index - 1]
            let b = points[index]
            let c = points[index + 1]
            result[index].latitude = (a.latitude + b.latitude + c.latitude) / 3
            result[index].longitude = (a.longitude + b.longitude + c.longitude) / 3
            if let aa = a.altitudeMeters, let ba = b.altitudeMeters, let ca = c.altitudeMeters {
                result[index].altitudeMeters = (aa + ba + ca) / 3
            }
        }
        return result
    }

    static func elevationGainMeters(altitudes: [Double?], minimumStep: Double = 0.8, maxSpike: Double = 15) -> Double {
        var last: Double?
        var gain = 0.0
        for altitude in altitudes {
            guard let altitude, altitude.isFinite else { continue }
            guard let previous = last else {
                last = altitude
                continue
            }
            let delta = altitude - previous
            if delta >= minimumStep, delta <= maxSpike { gain += delta }
            if abs(delta) <= maxSpike { last = altitude }
        }
        return gain
    }

    static func kilocalories(weightKG: Double, movingSeconds: Double, distanceMeters: Double) -> Double {
        guard movingSeconds > 0, distanceMeters >= 0 else { return 0 }
        let kilograms = weightKG > 20 ? weightKG : 70
        let minutes = movingSeconds / 60
        let metersPerMinute = distanceMeters / minutes
        let vo2 = 0.2 * metersPerMinute + 3.5
        let met = max(1, vo2 / 3.5)
        let hours = movingSeconds / 3_600
        return met * kilograms * hours
    }

    static func strideMeters(heightCM: Double?) -> Double {
        guard let heightCM, heightCM > 80, heightCM < 250 else { return 0.78 }
        return (heightCM / 100) * 0.415
    }

    static func indoorMeters(steps: Int, heightCM: Double?) -> Double {
        Double(max(0, steps)) * strideMeters(heightCM: heightCM)
    }

    static func paceSecondsPerUnit(_ secondsPerMeter: Double, unit: RunDistanceUnit) -> Double {
        secondsPerMeter * unit.meters
    }

    static func averagePaceSecondsPerMeter(distanceMeters: Double, movingSeconds: Double) -> Double? {
        guard distanceMeters >= 10, movingSeconds > 0 else { return nil }
        return movingSeconds / distanceMeters
    }

    static func currentPaceSecondsPerMeter(samples: [DistanceSample], window: Double = 20) -> Double? {
        guard let last = samples.last else { return nil }
        let cutoff = last.elapsedSeconds - window
        guard let earlier = samples.last(where: { $0.elapsedSeconds <= cutoff }) ?? samples.first else { return nil }
        let distance = last.distanceMeters - earlier.distanceMeters
        let time = last.elapsedSeconds - earlier.elapsedSeconds
        guard distance >= 8, time >= 4 else { return nil }
        return time / distance
    }

    static func formatPace(_ secondsPerUnit: Double) -> String {
        guard secondsPerUnit.isFinite, secondsPerUnit > 0, secondsPerUnit < 30 * 60 else { return "—" }
        let total = Int(secondsPerUnit.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func formatDistance(_ meters: Double, unit: RunDistanceUnit, places: Int = 2) -> String {
        let value = max(0, meters) / unit.meters
        return String(format: "%.\(places)f", value)
    }

    static func splits(samples: [DistanceSample], unitMeters: Double) -> [SplitDraft] {
        guard unitMeters > 0, let last = samples.last, last.distanceMeters > 0 else { return [] }
        let ordered = samples.sorted { $0.distanceMeters < $1.distanceMeters }
        var result: [SplitDraft] = []
        var boundary = unitMeters
        var previousTime = 0.0
        var index = 1
        while boundary <= last.distanceMeters + 0.05 {
            guard let at = ordered.firstIndex(where: { $0.distanceMeters + 0.05 >= boundary }) else { break }
            let time = interpolatedTime(reaching: boundary, samples: ordered, index: at)
            result.append(SplitDraft(
                index: index,
                distanceMeters: unitMeters,
                elapsedSeconds: max(0, time - previousTime),
                isPartial: false
            ))
            previousTime = time
            boundary += unitMeters
            index += 1
            if index > 10_000 { break }
        }
        let covered = Double(result.count) * unitMeters
        let remainder = last.distanceMeters - covered
        if remainder >= 1 {
            result.append(SplitDraft(
                index: index,
                distanceMeters: remainder,
                elapsedSeconds: max(0, last.elapsedSeconds - previousTime),
                isPartial: true
            ))
        }
        return result
    }

    static func bestSegmentSeconds(samples: [DistanceSample], targetMeters: Double) -> Double? {
        let usable = samplesForRecords(distanceMeters: samples.last?.distanceMeters ?? 0, movingSeconds: samples.last?.elapsedSeconds ?? 0, samples: samples)
        guard targetMeters > 0, let last = usable.last, last.distanceMeters + 0.05 >= targetMeters else { return nil }
        var best: Double?
        var end = 0
        for start in usable.indices {
            let need = usable[start].distanceMeters + targetMeters
            if end < start { end = start }
            while end < usable.count, usable[end].distanceMeters + 0.05 < need { end += 1 }
            guard end < usable.count else { break }
            let endTime = interpolatedTime(reaching: need, samples: usable, index: end)
            let delta = endTime - usable[start].elapsedSeconds
            if delta > 0 { best = min(best ?? delta, delta) }
        }
        return best
    }

    static func samplesForRecords(distanceMeters: Double, movingSeconds: Double, samples: [DistanceSample]) -> [DistanceSample] {
        if let last = samples.last, last.distanceMeters >= 1 { return samples }
        guard distanceMeters > 0, movingSeconds > 0 else { return [] }
        return [
            DistanceSample(distanceMeters: 0, elapsedSeconds: 0),
            DistanceSample(distanceMeters: distanceMeters, elapsedSeconds: movingSeconds),
        ]
    }

    static func records(for run: RunSummary, against history: [RunSummary]) -> [PersonalRecordHit] {
        var hits: [PersonalRecordHit] = []
        let standards: [(RecordKind, Double)] = [(.mile, RunDistanceUnit.mileMeters), (.fiveK, 5_000), (.tenK, 10_000)]
        for (kind, distance) in standards {
            let mine = samplesForRecords(distanceMeters: run.distanceMeters, movingSeconds: run.movingSeconds, samples: run.samples)
            guard let seconds = bestSegmentSeconds(samples: mine, targetMeters: distance) else { continue }
            let previous = history.compactMap { other -> Double? in
                let samples = samplesForRecords(distanceMeters: other.distanceMeters, movingSeconds: other.movingSeconds, samples: other.samples)
                return bestSegmentSeconds(samples: samples, targetMeters: distance)
            }.min()
            if let previous {
                if seconds + 0.05 < previous {
                    hits.append(PersonalRecordHit(kind: kind, seconds: seconds, previousSeconds: previous, distanceMeters: distance))
                }
            } else {
                hits.append(PersonalRecordHit(kind: kind, seconds: seconds, previousSeconds: nil, distanceMeters: distance))
            }
        }
        if run.distanceMeters >= 100 {
            let previousLongest = history.map(\.distanceMeters).max() ?? 0
            if run.distanceMeters > previousLongest + 0.5 {
                hits.append(PersonalRecordHit(kind: .longest, seconds: run.movingSeconds, previousSeconds: nil, distanceMeters: run.distanceMeters))
            }
        }
        return hits
    }

    static func board(runs: [RunSummary]) -> [PersonalRecordHit] {
        var hits: [PersonalRecordHit] = []
        let standards: [(RecordKind, Double)] = [(.mile, RunDistanceUnit.mileMeters), (.fiveK, 5_000), (.tenK, 10_000)]
        for (kind, distance) in standards {
            let best = runs.compactMap { run -> Double? in
                let samples = samplesForRecords(distanceMeters: run.distanceMeters, movingSeconds: run.movingSeconds, samples: run.samples)
                return bestSegmentSeconds(samples: samples, targetMeters: distance)
            }.min()
            if let best {
                hits.append(PersonalRecordHit(kind: kind, seconds: best, previousSeconds: nil, distanceMeters: distance))
            }
        }
        if let longest = runs.filter({ $0.distanceMeters >= 100 }).max(by: { $0.distanceMeters < $1.distanceMeters }) {
            hits.append(PersonalRecordHit(kind: .longest, seconds: longest.movingSeconds, previousSeconds: nil, distanceMeters: longest.distanceMeters))
        }
        return hits
    }

    static func weeklyStreak(runDates: [Date], now: Date, calendar: Calendar) -> Int {
        let weeks = Set(runDates.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start })
        guard var cursor = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        if !weeks.contains(cursor) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }
        var streak = 0
        while weeks.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
            if streak > 5_200 { break }
        }
        return streak
    }

    static func badges(runs: [RunSummary], streak: Int) -> [RunBadge] {
        let longest = runs.map(\.distanceMeters).max() ?? 0
        var badges: [RunBadge] = []
        if longest >= 5_000 {
            badges.append(RunBadge(id: "first-5k", title: "First 5K", detail: "One run covered 5 kilometers."))
        }
        if longest >= 10_000 {
            badges.append(RunBadge(id: "first-10k", title: "First 10K", detail: "One run covered 10 kilometers."))
        }
        if longest >= halfMarathonMeters {
            badges.append(RunBadge(id: "first-half", title: "First Half", detail: "One run covered a half marathon."))
        }
        if streak >= 4 {
            badges.append(RunBadge(id: "streak-4", title: "4-Week Streak", detail: "A run in four weeks in a row."))
        }
        if streak >= 8 {
            badges.append(RunBadge(id: "streak-8", title: "8-Week Streak", detail: "A run in eight weeks in a row."))
        }
        if streak >= 12 {
            badges.append(RunBadge(id: "streak-12", title: "12-Week Streak", detail: "A run in twelve weeks in a row."))
        }
        return badges
    }

    static func trendBuckets(
        runs: [RunSummary],
        granularity: TrendGranularity,
        now: Date,
        calendar: Calendar,
        count: Int
    ) -> [TrendBucket] {
        let component: Calendar.Component = granularity == .week ? .weekOfYear : .month
        guard count > 0, let thisStart = calendar.dateInterval(of: component, for: now)?.start else { return [] }
        var starts: [Date] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            if let date = calendar.date(byAdding: component, value: -offset, to: thisStart) {
                starts.append(calendar.dateInterval(of: component, for: date)?.start ?? date)
            }
        }
        return starts.map { start in
            let end = calendar.date(byAdding: component, value: 1, to: start) ?? start
            let included = runs.filter { $0.startedAt >= start && $0.startedAt < end }
            return TrendBucket(
                start: start,
                distanceMeters: included.reduce(0) { $0 + $1.distanceMeters },
                movingSeconds: included.reduce(0) { $0 + $1.movingSeconds }
            )
        }
    }

    static func shouldAnnounce(
        frequency: CueFrequency,
        silenced: Bool,
        previousDistance: Double,
        distance: Double,
        previousElapsed: TimeInterval,
        elapsed: TimeInterval
    ) -> Bool {
        guard !silenced else { return false }
        switch frequency {
        case .off:
            return false
        case .everyKilometer:
            return crossed(previous: previousDistance, current: distance, interval: 1_000)
        case .everyMile:
            return crossed(previous: previousDistance, current: distance, interval: RunDistanceUnit.mileMeters)
        case .everyFiveMinutes:
            return crossed(previous: previousElapsed, current: elapsed, interval: 300)
        }
    }

    static func cueSentence(
        distanceMeters: Double,
        movingSeconds: TimeInterval,
        unit: RunDistanceUnit,
        frequency: CueFrequency
    ) -> String {
        switch frequency {
        case .everyFiveMinutes:
            let minutes = max(1, Int((movingSeconds / 60).rounded()))
            let distance = formatDistance(distanceMeters, unit: unit)
            return "\(minutes) minutes. \(distance) \(unit.label)."
        case .off, .everyKilometer, .everyMile:
            let whole = max(1, Int((distanceMeters / unit.meters).rounded()))
            let pace = averagePaceSecondsPerMeter(distanceMeters: distanceMeters, movingSeconds: movingSeconds)
            let paceText = pace.map { formatPace(paceSecondsPerUnit($0, unit: unit)) } ?? ""
            let noun = unit.spokenNoun(whole)
            if paceText.isEmpty || paceText == "—" { return "\(whole) \(noun)." }
            return "\(whole) \(noun). \(paceText) pace."
        }
    }

    static func toneHex(paceSecondsPerMeter: Double, fastest: Double, slowest: Double) -> UInt32 {
        guard fastest.isFinite, slowest.isFinite, slowest > fastest + 0.000_001 else { return 0xF4F4F4 }
        let t = min(1, max(0, (paceSecondsPerMeter - fastest) / (slowest - fastest)))
        let channel = Int((0xF4) + (Double(0x3A - 0xF4) * t))
        let clamped = UInt32(min(255, max(0, channel)))
        return (clamped << 16) | (clamped << 8) | clamped
    }

    static func crossed(previous: Double, current: Double, interval: Double) -> Bool {
        guard interval > 0, current >= previous else { return false }
        return floor(current / interval) > floor(previous / interval)
    }

    private static func interpolatedTime(reaching distance: Double, samples: [DistanceSample], index: Int) -> Double {
        guard samples.indices.contains(index) else { return 0 }
        guard index > 0 else { return samples[index].elapsedSeconds }
        let previous = samples[index - 1]
        let current = samples[index]
        let span = current.distanceMeters - previous.distanceMeters
        guard span > 0 else { return current.elapsedSeconds }
        let fraction = min(1, max(0, (distance - previous.distanceMeters) / span))
        return previous.elapsedSeconds + fraction * (current.elapsedSeconds - previous.elapsedSeconds)
    }
}

/// Phase 2 navigation is reserved in the type system and is not installed
/// as a tab, a link, or a button. `isPresented` stays false so a test can
/// lock that.
enum RunClubNavigationSlot {
    static let phase = 2
    static let isPresented = false
}
