import Foundation
import SwiftData
import WatchConnectivity

/// Receives a finished watch run and stores it on the phone. A second
/// delivery of the same id is ignored. If the watch already wrote HealthKit,
/// the phone does not write another workout.
@MainActor
final class WatchRunInbox: NSObject, WCSessionDelegate {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let data = try? Data(contentsOf: file.file) else { return }
        Task { @MainActor in
            await self.importData(data)
        }
    }

    func importData(_ data: Data) async {
        guard let payload = try? WatchRunPayload.decode(data) else { return }
        let context = container.mainContext
        let target = payload.id
        var existing = FetchDescriptor<Run>(predicate: #Predicate { $0.id == target })
        existing.fetchLimit = 1
        if let found = try? context.fetch(existing), !found.isEmpty { return }
        guard let athlete = AthleteRepository(context: context).currentAthlete() else { return }

        var distance = payload.distanceMeters
        var trace = payload.trace
        if payload.environment == .outdoor, payload.samples.count >= 2 {
            let kept = RunMath.accepted(payload.samples)
            let measured = RunMath.distance(of: kept)
            if measured > 0 { distance = measured }
        }
        if trace.isEmpty {
            trace = RunMath.samplesForRecords(distanceMeters: distance, movingSeconds: payload.movingSeconds, samples: [])
        }
        let run = Run(
            id: payload.id,
            athleteID: athlete.id,
            startedAt: payload.startedAt,
            endedAt: payload.endedAt,
            environment: payload.environment,
            source: .watch,
            status: .ended,
            distanceMeters: distance,
            movingSeconds: payload.movingSeconds,
            pausedSeconds: payload.pausedSeconds,
            elevationGainMeters: payload.elevationGainMeters,
            calories: payload.calories,
            averageHeartRate: payload.averageHeartRate,
            healthSyncState: payload.wroteHealthKitOnWatch ? .watchOwned : .pending,
            ownedByWatchHealth: payload.wroteHealthKitOnWatch
        )
        run.setTrace(trace)
        context.insert(run)
        if !payload.samples.isEmpty {
            let route = RunRoute(samples: RunMath.accepted(payload.samples))
            route.run = run
            run.route = route
            context.insert(route)
        }
        let unit = RunPreferenceValues.fresh(unit: athlete.unitPreference == .imperial ? .miles : .kilometers).distanceUnit
        for draft in RunMath.splits(samples: trace, unitMeters: unit.meters) {
            let split = RunSplit(
                index: draft.index,
                distanceMeters: draft.distanceMeters,
                elapsedSeconds: draft.elapsedSeconds,
                isPartial: draft.isPartial,
                run: run
            )
            context.insert(split)
        }
        try? context.save()
        if !payload.wroteHealthKitOnWatch {
            await HealthKitRunSync().sync(run: run, context: context)
        }
    }
}
