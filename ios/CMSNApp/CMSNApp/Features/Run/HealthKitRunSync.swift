import CoreLocation
import Foundation
import HealthKit
import SwiftData

private struct HealthWriteFailure: LocalizedError {
    var errorDescription: String? { "Apple Health finished without returning a workout." }
}

@MainActor
protocol HealthRunWriting: AnyObject {
    func liveAuthorizationState() -> HealthAuthorizationState
    func requestAuthorization() async -> HealthAuthorizationState
    func sync(run: Run, context: ModelContext) async
    func retryPending(in context: ModelContext) async
}

/// Writes a finished run into Apple Health and retries until it lands.
/// A denied or failed write stays visible on the run. It is never marked
/// synced, and a stored "we were authorized once" flag is never consulted.
@MainActor
final class HealthKitRunSync: HealthRunWriting {
    private let store = HKHealthStore()

    func liveAuthorizationState() -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        switch store.authorizationStatus(for: HKObjectType.workoutType()) {
        case .notDetermined: return .notDetermined
        case .sharingAuthorized: return .authorized
        case .sharingDenied: return .denied
        @unknown default: return .notDetermined
        }
    }

    func requestAuthorization() async -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        } catch {
            return liveAuthorizationState()
        }
        return liveAuthorizationState()
    }

    func sync(run: Run, context: ModelContext) async {
        guard run.status == .ended else { return }
        var state = liveAuthorizationState()
        var action = HealthSyncPolicy.nextAction(
            liveState: state,
            healthWorkoutUUID: run.healthWorkoutUUID,
            ownedByWatchHealth: run.ownedByWatchHealth
        )
        if action == .requestAuthorization {
            state = await requestAuthorization()
            action = HealthSyncPolicy.nextAction(
                liveState: state,
                healthWorkoutUUID: run.healthWorkoutUUID,
                ownedByWatchHealth: run.ownedByWatchHealth
            )
        }
        switch action {
        case .skipAlreadySynced:
            run.healthSyncState = .synced
            run.healthSyncError = nil
        case .skipWatchOwned:
            run.healthSyncState = .watchOwned
            run.healthSyncError = nil
        case .write:
            do {
                let uuid = try await writeWorkout(for: run)
                run.healthWorkoutUUID = uuid
                run.healthSyncState = .synced
                run.healthSyncError = nil
            } catch {
                run.healthSyncState = .pending
                run.healthSyncError = "Apple Health didn't take this run. It is still saved on this phone. \(error.localizedDescription)"
            }
        case .holdAndExplainDenied:
            run.healthSyncState = .denied
            run.healthSyncError = "Apple Health isn't allowing writes. This run stays on this phone. Turn sharing back on in Settings, then open Run and it will try again."
        case .holdUnavailable:
            run.healthSyncState = .unavailable
            run.healthSyncError = "Apple Health isn't available on this device. This run stays on this phone."
        case .requestAuthorization:
            run.healthSyncState = .pending
            run.healthSyncError = "Apple Health still needs permission before this run can be saved there."
        }
        try? context.save()
    }

    func retryPending(in context: ModelContext) async {
        let runs = (try? context.fetch(FetchDescriptor<Run>())) ?? []
        for run in runs where run.status == .ended && run.healthSyncState != .synced && run.healthSyncState != .watchOwned {
            await sync(run: run, context: context)
        }
    }

    private func writeWorkout(for run: Run) async throws -> UUID {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = run.environment == .indoor ? .indoor : .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        let end = run.endedAt ?? Date()
        try await builder.beginCollection(at: run.startedAt)
        let samples = quantitySamples(for: run, end: end)
        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }
        try await builder.endCollection(at: end)
        guard let workout = try await builder.finishWorkout() else {
            throw HealthWriteFailure()
        }
        if run.environment == .outdoor, let route = run.route {
            let locations = route.samples().map { sample in
                CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: sample.latitude, longitude: sample.longitude),
                    altitude: sample.altitudeMeters ?? 0,
                    horizontalAccuracy: max(0, sample.horizontalAccuracy),
                    verticalAccuracy: sample.altitudeMeters == nil ? -1 : 8,
                    timestamp: sample.timestamp
                )
            }
            if locations.count >= 2 {
                let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
                do {
                    try await routeBuilder.insertRouteData(locations)
                    try await routeBuilder.finishRoute(with: workout, metadata: nil)
                } catch {
                    // The workout itself is saved. Losing the route overlay
                    // must not cause a second workout on the next retry.
                }
            }
        }
        return workout.uuid
    }

    private func quantitySamples(for run: Run, end: Date) -> [HKSample] {
        guard end > run.startedAt else { return [] }
        var samples: [HKSample] = []
        if run.distanceMeters > 0 {
            let type = HKQuantityType(.distanceWalkingRunning)
            let quantity = HKQuantity(unit: .meter(), doubleValue: run.distanceMeters)
            samples.append(HKQuantitySample(type: type, quantity: quantity, start: run.startedAt, end: end))
        }
        if run.calories > 0 {
            let type = HKQuantityType(.activeEnergyBurned)
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: run.calories)
            samples.append(HKQuantitySample(type: type, quantity: quantity, start: run.startedAt, end: end))
        }
        if let bpm = run.averageHeartRate, bpm > 0 {
            let type = HKQuantityType(.heartRate)
            let unit = HKUnit.count().unitDivided(by: .minute())
            let quantity = HKQuantity(unit: unit, doubleValue: bpm)
            samples.append(HKQuantitySample(type: type, quantity: quantity, start: run.startedAt, end: end))
        }
        return samples
    }

    private var shareTypes: Set<HKSampleType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKSeriesType.workoutRoute(),
        ]
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
        ]
    }
}
