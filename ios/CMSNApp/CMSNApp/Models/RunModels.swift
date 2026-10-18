import Foundation
import SwiftData

/// One recorded run. Phase 1 is solo: a run belongs to the local athlete
/// by id and is never posted anywhere. Location samples live on `RunRoute`.
@Model
final class Run {
    @Attribute(.unique) var id: UUID
    var athleteID: UUID
    var startedAt: Date
    var endedAt: Date?
    var environment: RunEnvironment
    var source: RunSource
    var status: RunStatus
    var distanceMeters: Double
    var movingSeconds: Double
    var pausedSeconds: Double
    var elevationGainMeters: Double
    var calories: Double
    var averageHeartRate: Double?
    var notes: String
    var ground: RunGround?
    var effort: RunEffort?
    var mood: RunMood?
    var shoeID: UUID?
    var healthWorkoutUUID: UUID?
    var healthSyncState: HealthSyncRecord
    var healthSyncError: String?
    /// The watch already wrote the HealthKit workout. The phone keeps the
    /// run for history and does not write a second workout.
    var ownedByWatchHealth: Bool
    /// Moving-time distance curve. JSON `[DistanceSample]`. Splits and
    /// personal records read this, not the map line.
    var traceJSON: Data
    @Attribute(.externalStorage) var photoJPEG: Data?

    @Relationship(deleteRule: .cascade, inverse: \RunSplit.run)
    var splits: [RunSplit]

    @Relationship(deleteRule: .cascade, inverse: \RunRoute.run)
    var route: RunRoute?

    init(
        id: UUID = UUID(),
        athleteID: UUID,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        environment: RunEnvironment,
        source: RunSource = .phone,
        status: RunStatus = .active,
        distanceMeters: Double = 0,
        movingSeconds: Double = 0,
        pausedSeconds: Double = 0,
        elevationGainMeters: Double = 0,
        calories: Double = 0,
        averageHeartRate: Double? = nil,
        notes: String = "",
        ground: RunGround? = nil,
        effort: RunEffort? = nil,
        mood: RunMood? = nil,
        shoeID: UUID? = nil,
        healthWorkoutUUID: UUID? = nil,
        healthSyncState: HealthSyncRecord = .pending,
        healthSyncError: String? = nil,
        ownedByWatchHealth: Bool = false,
        traceJSON: Data = Data(),
        photoJPEG: Data? = nil
    ) {
        self.id = id
        self.athleteID = athleteID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.environment = environment
        self.source = source
        self.status = status
        self.distanceMeters = distanceMeters
        self.movingSeconds = movingSeconds
        self.pausedSeconds = pausedSeconds
        self.elevationGainMeters = elevationGainMeters
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.notes = notes
        self.ground = ground
        self.effort = effort
        self.mood = mood
        self.shoeID = shoeID
        self.healthWorkoutUUID = healthWorkoutUUID
        self.healthSyncState = healthSyncState
        self.healthSyncError = healthSyncError
        self.ownedByWatchHealth = ownedByWatchHealth
        self.traceJSON = traceJSON
        self.photoJPEG = photoJPEG
        self.splits = []
        self.route = nil
    }

    func trace() -> [DistanceSample] {
        guard !traceJSON.isEmpty else { return [] }
        return (try? RunJSON.decoder().decode([DistanceSample].self, from: traceJSON)) ?? []
    }

    func setTrace(_ samples: [DistanceSample]) {
        traceJSON = (try? RunJSON.encoder().encode(samples)) ?? traceJSON
    }

    func summary() -> RunSummary {
        RunSummary(
            id: id,
            startedAt: startedAt,
            distanceMeters: distanceMeters,
            movingSeconds: movingSeconds,
            samples: trace()
        )
    }

    var paceSecondsPerMeter: Double? {
        RunMath.averagePaceSecondsPerMeter(distanceMeters: distanceMeters, movingSeconds: movingSeconds)
    }
}

@Model
final class RunSplit {
    @Attribute(.unique) var id: UUID
    var index: Int
    var distanceMeters: Double
    var elapsedSeconds: Double
    var isPartial: Bool
    var run: Run?

    init(
        id: UUID = UUID(),
        index: Int,
        distanceMeters: Double,
        elapsedSeconds: Double,
        isPartial: Bool,
        run: Run? = nil
    ) {
        self.id = id
        self.index = index
        self.distanceMeters = distanceMeters
        self.elapsedSeconds = elapsedSeconds
        self.isPartial = isPartial
        self.run = run
    }
}

/// GPS trace for one run. Samples are a JSON blob so a long route is one
/// column, and a later schema change does not have to migrate each fix.
@Model
final class RunRoute {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var samplesJSON: Data
    var run: Run?

    init(id: UUID = UUID(), samples: [TrackPoint] = [], run: Run? = nil) {
        self.id = id
        self.samplesJSON = (try? RunJSON.encoder().encode(samples)) ?? Data()
        self.run = run
    }

    func samples() -> [TrackPoint] {
        guard !samplesJSON.isEmpty else { return [] }
        return (try? RunJSON.decoder().decode([TrackPoint].self, from: samplesJSON)) ?? []
    }

    func replaceSamples(_ samples: [TrackPoint]) {
        samplesJSON = (try? RunJSON.encoder().encode(samples)) ?? samplesJSON
    }
}

@Model
final class RunShoe {
    @Attribute(.unique) var id: UUID
    var athleteID: UUID
    var name: String
    var createdAt: Date
    var retiredAt: Date?
    var replacementDistanceMeters: Double

    init(
        id: UUID = UUID(),
        athleteID: UUID,
        name: String,
        createdAt: Date = Date(),
        retiredAt: Date? = nil,
        replacementDistanceMeters: Double = ShoeMileage.defaultReplacementMeters
    ) {
        self.id = id
        self.athleteID = athleteID
        self.name = name
        self.createdAt = createdAt
        self.retiredAt = retiredAt
        self.replacementDistanceMeters = replacementDistanceMeters
    }
}

/// One row per athlete. Preferences live here so the run path does not
/// call UserDefaults.
@Model
final class RunSettings {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var athleteID: UUID
    var environment: RunEnvironment
    var countdownSeconds: Int
    var autoPauseEnabled: Bool
    var cueFrequency: CueFrequency
    var cuesSilenced: Bool
    var paceHeadline: PaceHeadline
    var heartRateStrapEnabled: Bool

    init(id: UUID = UUID(), athleteID: UUID, values: RunPreferenceValues) {
        self.id = id
        self.athleteID = athleteID
        self.environment = values.environment
        self.countdownSeconds = values.clampedCountdown
        self.autoPauseEnabled = values.autoPauseEnabled
        self.cueFrequency = values.cueFrequency
        self.cuesSilenced = values.cuesSilenced
        self.paceHeadline = values.paceHeadline
        self.heartRateStrapEnabled = values.heartRateStrapEnabled
    }

    func values(unit: RunDistanceUnit) -> RunPreferenceValues {
        var values = RunPreferenceValues()
        values.environment = environment
        values.countdownSeconds = countdownSeconds
        values.autoPauseEnabled = autoPauseEnabled
        values.cueFrequency = cueFrequency
        values.cuesSilenced = cuesSilenced
        values.paceHeadline = paceHeadline
        values.distanceUnit = unit
        values.heartRateStrapEnabled = heartRateStrapEnabled
        return values
    }

    func apply(_ values: RunPreferenceValues) {
        environment = values.environment
        countdownSeconds = values.clampedCountdown
        autoPauseEnabled = values.autoPauseEnabled
        cueFrequency = values.cueFrequency
        cuesSilenced = values.cuesSilenced
        paceHeadline = values.paceHeadline
        heartRateStrapEnabled = values.heartRateStrapEnabled
    }
}
