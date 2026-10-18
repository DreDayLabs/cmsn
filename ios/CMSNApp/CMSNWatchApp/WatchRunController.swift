import CoreLocation
import CoreMotion
import Foundation
import HealthKit
import WatchConnectivity

/// Phone-free run. The workout session is what keeps GPS alive when the
/// wrist drops. The trace is filtered with the same spike rules as the
/// phone, then handed over with `WCSession.transferFile`.
final class WatchRunController: NSObject, ObservableObject, CLLocationManagerDelegate, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, WCSessionDelegate {
    @Published var environment: RunEnvironment = .outdoor
    @Published var countdownSeconds = 3
    @Published var remaining: Int?
    @Published var phase: RunActivityPhase = .ready
    @Published var distanceMeters: Double = 0
    @Published var movingSeconds: TimeInterval = 0
    @Published var heartRate: Double?
    @Published var nightMode = false
    @Published var statusMessage: String?
    @Published var finished = false

    private let location = CLLocationManager()
    private let pedometer = CMPedometer()
    private let healthStore = HKHealthStore()
    private var machine = AutoPauseMachine()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var accepted: [TrackPoint] = []
    private var trace: [DistanceSample] = []
    private var startedAt: Date?
    private var runID: UUID?
    private var ticker: Timer?
    private var lastSpeed: Double?
    private var indoorDistance: Double = 0
    private var heartRates: [Double] = []
    private var tracking = false
    private var pendingSync: Data?

    override init() {
        super.init()
        location.delegate = self
        location.activityType = .fitness
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = 5
        location.pausesLocationUpdatesAutomatically = false
        loadPrefs()
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: Self.pendingURL) {
            pendingSync = data
            activateSync()
        }
    }

    func toggleNight() {
        nightMode.toggle()
        savePrefs()
    }

    func start() {
        guard phase == .ready || finished else { return }
        savePrefs()
        finished = false
        statusMessage = nil
        accepted = []
        trace = []
        heartRates = []
        heartRate = nil
        distanceMeters = 0
        movingSeconds = 0
        indoorDistance = 0
        lastSpeed = nil
        runID = UUID()
        machine = AutoPauseMachine()
        remaining = countdownSeconds
        tracking = true
        beginSensors()
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func togglePause() {
        let now = Date()
        if phase == .running {
            machine.pauseManually(at: now)
        } else if phase == .autoPaused || phase == .manualPaused {
            machine.resumeManually(at: now)
        }
        phase = machine.phase
        refreshClock()
    }

    func commitHold() {
        let now = Date()
        guard machine.end(holdCompleted: true, at: now) else { return }
        phase = .ended
        ticker?.invalidate()
        tracking = false
        location.stopUpdatingLocation()
        pedometer.stopUpdates()
        refreshClock()
        let payload = makePayload(endedAt: now)
        finishHealth(at: now) { [weak self] wrote in
            DispatchQueue.main.async {
                guard let self, var payload else { return }
                payload.wroteHealthKitOnWatch = wrote
                self.queue(payload)
                self.finished = true
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard tracking, environment == .outdoor else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            statusMessage = "Location is off. Allow it for CMSN Performance to record the route."
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard tracking, environment == .outdoor else { return }
        for location in locations {
            let point = TrackPoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil,
                timestamp: location.timestamp,
                horizontalAccuracy: location.horizontalAccuracy,
                speedMetersPerSecond: location.speed
            )
            guard phase == .running else { continue }
            let reported: Double? = location.speed >= 0 ? location.speed : nil
            lastSpeed = reported
            machine.ingest(speed: reported, at: location.timestamp)
            phase = machine.phase
            guard machine.phase == .running, RunMath.accept(point, after: accepted.last) else { continue }
            accepted.append(point)
            distanceMeters = RunMath.distance(of: accepted)
            appendTrace()
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.statusMessage = "Apple Health didn't keep the workout session. The route is still recording while this screen is up."
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartType),
              let quantity = workoutBuilder.statistics(for: heartType)?.mostRecentQuantity() else { return }
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        guard bpm > 0, bpm < 250 else { return }
        DispatchQueue.main.async {
            self.heartRate = bpm
            self.heartRates.append(bpm)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated, let pendingSync else { return }
        transfer(pendingSync)
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            if let error {
                self.statusMessage = "Saved on this watch. It hasn't reached the iPhone yet. \(error.localizedDescription)"
            } else {
                self.pendingSync = nil
                try? FileManager.default.removeItem(at: Self.pendingURL)
                self.statusMessage = "On its way to the iPhone."
            }
        }
    }

    private func tick() {
        if let remaining {
            if remaining <= 1 {
                self.remaining = nil
                let now = Date()
                startedAt = now
                machine.begin(at: now)
                phase = .running
            } else {
                self.remaining = remaining - 1
            }
            return
        }
        machine.ingest(speed: lastSpeed, at: Date())
        phase = machine.phase
        refreshClock()
    }

    private func beginSensors() {
        Task { await prepareHealth() }
        if environment == .outdoor {
            switch location.authorizationStatus {
            case .notDetermined:
                location.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                location.startUpdatingLocation()
            default:
                statusMessage = "Location is off. Allow it for CMSN Performance to record the route."
            }
        } else if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                guard let self, let data, self.environment == .indoor, self.phase == .running else { return }
                let distance = data.distance?.doubleValue
                let cadence = data.currentCadence?.doubleValue
                DispatchQueue.main.async {
                    if let distance { self.indoorDistance = max(self.indoorDistance, distance) }
                    else { self.indoorDistance = RunMath.indoorMeters(steps: data.numberOfSteps.intValue, heightCM: nil) }
                    self.distanceMeters = self.indoorDistance
                    let speed: Double? = {
                        guard let cadence else { return nil }
                        if cadence >= 1.2 { return 1.5 }
                        if cadence <= 0.3 { return 0 }
                        return nil
                    }()
                    self.lastSpeed = speed
                    self.machine.ingest(speed: speed, at: Date())
                    self.phase = self.machine.phase
                    if self.machine.phase == .running { self.appendTrace() }
                }
            }
        }
    }

    private func prepareHealth() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKSeriesType.workoutRoute(),
        ]
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKObjectType.workoutType()]
        try? await healthStore.requestAuthorization(toShare: share, read: read)
        await startWorkoutSession()
    }

    private func startWorkoutSession() async {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = environment == .indoor ? .indoor : .outdoor
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            workoutSession = session
            self.builder = builder
            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
        } catch {
            await MainActor.run {
                statusMessage = "Apple Health didn't start the workout. Keep the watch face up, or allow Health for CMSN Performance."
            }
        }
    }

    private func finishHealth(at end: Date, completion: @escaping (Bool) -> Void) {
        guard let builder, let workoutSession else {
            completion(false)
            return
        }
        workoutSession.end()
        Task {
            do {
                try await builder.endCollection(at: end)
                let saved = try await builder.finishWorkout()
                completion(saved != nil)
            } catch {
                completion(false)
            }
        }
    }

    private func makePayload(endedAt: Date) -> WatchRunPayload? {
        guard let startedAt, let runID else { return nil }
        let moving = machine.movingSeconds(startedAt: startedAt, now: endedAt)
        let distance = environment == .indoor ? indoorDistance : RunMath.distance(of: accepted)
        let average = heartRates.isEmpty ? heartRate : heartRates.reduce(0, +) / Double(heartRates.count)
        return WatchRunPayload(
            version: WatchRunPayload.currentVersion,
            id: runID,
            startedAt: startedAt,
            endedAt: endedAt,
            environment: environment,
            distanceMeters: distance,
            movingSeconds: moving,
            pausedSeconds: machine.pausedSeconds(now: endedAt),
            elevationGainMeters: RunMath.elevationGainMeters(altitudes: accepted.map(\.altitudeMeters)),
            calories: RunMath.kilocalories(weightKG: 70, movingSeconds: moving, distanceMeters: distance),
            averageHeartRate: average,
            samples: accepted,
            trace: trace,
            wroteHealthKitOnWatch: false
        )
    }

    private func queue(_ payload: WatchRunPayload) {
        guard let data = try? payload.encoded() else { return }
        pendingSync = data
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        try? data.write(to: Self.pendingURL, options: .atomic)
        if WCSession.isSupported() {
            activateSync()
        } else {
            statusMessage = "Saved on this watch. Pair it with the iPhone to copy the run over."
        }
    }

    private func activateSync() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState == .activated, let pendingSync {
            transfer(pendingSync)
        } else {
            session.activate()
        }
    }

    private func transfer(_ data: Data) {
        let url = Self.outgoingURL
        do {
            try data.write(to: url, options: .atomic)
            WCSession.default.transferFile(url, metadata: ["kind": "cmsn-run"])
        } catch {
            statusMessage = "Saved on this watch. The file for the iPhone couldn't be written."
        }
    }

    private func appendTrace() {
        guard let startedAt else { return }
        let moving = machine.movingSeconds(startedAt: startedAt, now: Date())
        movingSeconds = moving
        trace.append(DistanceSample(distanceMeters: distanceMeters, elapsedSeconds: moving))
    }

    private func refreshClock() {
        guard let startedAt else { return }
        movingSeconds = machine.movingSeconds(startedAt: startedAt, now: Date())
    }

    private func loadPrefs() {
        guard let data = try? Data(contentsOf: Self.prefsURL),
              let prefs = try? RunJSON.decoder().decode(WatchPrefs.self, from: data) else { return }
        nightMode = prefs.nightMode
        environment = prefs.environment
        countdownSeconds = [3, 6, 9].contains(prefs.countdownSeconds) ? prefs.countdownSeconds : 3
    }

    private func savePrefs() {
        let prefs = WatchPrefs(nightMode: nightMode, environment: environment, countdownSeconds: countdownSeconds)
        if let data = try? RunJSON.encoder().encode(prefs) {
            try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try? data.write(to: Self.prefsURL, options: .atomic)
        }
    }

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("CMSNWatchRun", isDirectory: true)
    }

    private static var prefsURL: URL { directory.appendingPathComponent("display.json") }
    private static var pendingURL: URL { directory.appendingPathComponent("pending-run.json") }
    private static var outgoingURL: URL { directory.appendingPathComponent("outgoing-run.json") }
}

private struct WatchPrefs: Codable {
    var nightMode: Bool
    var environment: RunEnvironment
    var countdownSeconds: Int
}
