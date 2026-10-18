import Foundation
import SwiftData
import UIKit

enum SessionStage: Equatable {
    case idle
    case countdown(Int)
    case live
    case finished
}

enum RunHaptic {
    case tick
    case success
}

struct ActiveRunBackupFile: Codable, Equatable {
    var runID: UUID
    var samples: [TrackPoint]
    var trace: [DistanceSample]
    var indoorDistance: Double
}

enum ActiveRunBackup {
    static var directoryOverride: URL?

    static func fileURL() -> URL {
        if let directoryOverride {
            return directoryOverride.appendingPathComponent("active-run.json")
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("CMSNRuns", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("active-run.json")
    }

    static func save(_ file: ActiveRunBackupFile) {
        guard let data = try? RunJSON.encoder().encode(file) else { return }
        try? data.write(to: fileURL(), options: .atomic)
    }

    static func load() -> ActiveRunBackupFile? {
        guard let data = try? Data(contentsOf: fileURL()) else { return nil }
        return try? RunJSON.decoder().decode(ActiveRunBackupFile.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL())
    }
}

/// Owns one phone run from countdown through save. Location, motion, and
/// heart-rate hardware start when the run starts and stop in the same
/// moment the run ends or the countdown is cancelled.
@MainActor
@Observable
final class RunSessionController {
    private(set) var stage: SessionStage = .idle
    private(set) var machine = AutoPauseMachine()
    private(set) var accepted: [TrackPoint] = []
    private(set) var trace: [DistanceSample] = []
    private(set) var heartRate: Double?
    private(set) var finishedRunID: UUID?
    private(set) var permissionNote: String?
    private(set) var endError: String?
    /// Bumps every second so the live clock redraws even when no GPS fix arrives.
    private(set) var displayTick: Int = 0

    var preferences = RunPreferenceValues()
    var clock: () -> Date
    var haptic: (RunHaptic) -> Void
    var setIdleTimerDisabled: (Bool) -> Void

    private let location: any RunLocationProviding
    private let motion: any RunMotionProviding
    private let speech: any RunSpeechProviding
    private let heart: any HeartRateProviding
    private let health: any HealthRunWriting
    private let automaticallyTicks: Bool

    private var context: ModelContext?
    private var athleteID: UUID?
    private var weightKG: Double = 70
    private var heightCM: Double = 170
    private var runID: UUID?
    private var startedAt: Date?
    private var indoorDistance: Double = 0
    private var lastSpeed: Double?
    private var lastCueDistance: Double = 0
    private var lastCueElapsed: TimeInterval = 0
    private var heartRates: [Double] = []
    private var ticker: Timer?

    init(
        location: (any RunLocationProviding)? = nil,
        motion: (any RunMotionProviding)? = nil,
        speech: (any RunSpeechProviding)? = nil,
        heart: (any HeartRateProviding)? = nil,
        health: (any HealthRunWriting)? = nil,
        automaticallyTicks: Bool = true,
        clock: @escaping () -> Date = Date.init,
        haptic: ((RunHaptic) -> Void)? = nil,
        setIdleTimerDisabled: ((Bool) -> Void)? = nil
    ) {
        // Defaults are built in the body. A default argument is nonisolated,
        // and HealthKitRunSync's initializer is MainActor.
        self.location = location ?? CoreLocationRunService()
        self.motion = motion ?? PedometerRunService()
        self.speech = speech ?? RunSpeechService()
        self.heart = heart ?? HeartRateService()
        self.health = health ?? HealthKitRunSync()
        self.automaticallyTicks = automaticallyTicks
        self.clock = clock
        self.haptic = haptic ?? { RunSessionController.deviceHaptic($0) }
        self.setIdleTimerDisabled = setIdleTimerDisabled ?? { UIApplication.shared.isIdleTimerDisabled = $0 }
        bind()
    }

    var isSessionOpen: Bool {
        switch stage {
        case .countdown, .live: return true
        case .idle, .finished: return false
        }
    }

    var distanceMeters: Double {
        preferences.environment == .indoor ? indoorDistance : RunMath.distance(of: accepted)
    }

    var phase: RunActivityPhase { machine.phase }

    func movingSeconds(now: Date? = nil) -> TimeInterval {
        guard let startedAt else { return 0 }
        return machine.movingSeconds(startedAt: startedAt, now: now ?? clock())
    }

    var headlinePaceText: String {
        let secondsPerMeter: Double?
        switch preferences.paceHeadline {
        case .current:
            secondsPerMeter = RunMath.currentPaceSecondsPerMeter(samples: trace)
        case .average:
            secondsPerMeter = RunMath.averagePaceSecondsPerMeter(
                distanceMeters: distanceMeters,
                movingSeconds: movingSeconds()
            )
        }
        guard let secondsPerMeter else { return "—" }
        return RunMath.formatPace(RunMath.paceSecondsPerUnit(secondsPerMeter, unit: preferences.distanceUnit))
    }

    func start(context: ModelContext, athleteID: UUID, weightKG: Double, heightCM: Double) {
        guard stage == .idle || stage == .finished else { return }
        self.context = context
        self.athleteID = athleteID
        self.weightKG = weightKG
        self.heightCM = heightCM
        finishedRunID = nil
        endError = nil
        permissionNote = nil
        accepted = []
        trace = []
        heartRates = []
        heartRate = nil
        indoorDistance = 0
        lastSpeed = nil
        lastCueDistance = 0
        lastCueElapsed = 0
        runID = nil
        startedAt = nil
        machine = AutoPauseMachine()
        machine.config.enabled = preferences.autoPauseEnabled
        speech.setSilenced(preferences.cuesSilenced)
        let countdown = preferences.clampedCountdown
        stage = .countdown(countdown)
        setIdleTimerDisabled(true)
        if preferences.environment == .outdoor {
            location.startUpdates(allowsBackground: true)
        } else {
            motion.start()
        }
        heart.start(strap: preferences.heartRateStrapEnabled)
        if !preferences.cuesSilenced {
            speech.speak("\(countdown)")
            haptic(.tick)
        }
        armTicker()
        Task { await prepareHealth() }
    }

    func advance() {
        displayTick += 1
        let now = clock()
        switch stage {
        case .countdown(let remaining):
            let next = remaining - 1
            if next <= 0 {
                beginLive(at: now)
            } else {
                stage = .countdown(next)
                if !preferences.cuesSilenced {
                    speech.speak("\(next)")
                    haptic(.tick)
                }
            }
        case .live:
            machine.ingest(speed: lastSpeed, at: now)
            refreshCues(now: now)
            persist(now: now)
        case .idle, .finished:
            break
        }
    }

    func cancelCountdown() {
        guard case .countdown = stage else { return }
        stopSensors()
        ticker?.invalidate()
        stage = .idle
        setIdleTimerDisabled(false)
    }

    func togglePause() {
        guard stage == .live else { return }
        let now = clock()
        switch machine.phase {
        case .running:
            machine.pauseManually(at: now)
        case .manualPaused, .autoPaused:
            machine.resumeManually(at: now)
        case .ready, .ended:
            break
        }
        persist(now: now)
    }

    func commitHoldToEnd() {
        guard stage == .live else { return }
        let now = clock()
        guard machine.end(holdCompleted: true, at: now) else { return }
        stopSensors()
        ticker?.invalidate()
        setIdleTimerDisabled(false)
        finalize(at: now)
    }

    func ingestLocation(_ point: TrackPoint) {
        guard stage == .live, preferences.environment == .outdoor else { return }
        guard machine.phase != .ended else { return }
        let reported: Double? = point.speedMetersPerSecond >= 0 ? point.speedMetersPerSecond : nil
        lastSpeed = reported
        machine.ingest(speed: reported, at: point.timestamp)
        guard machine.phase == .running else {
            persist(now: clock())
            return
        }
        guard RunMath.accept(point, after: accepted.last) else { return }
        accepted.append(point)
        let moving = movingSeconds(now: max(clock(), point.timestamp))
        trace.append(DistanceSample(distanceMeters: RunMath.distance(of: accepted), elapsedSeconds: moving))
        refreshCues(now: clock())
        persist(now: clock())
    }

    func ingestMotion(_ update: MotionUpdate) {
        guard stage == .live, preferences.environment == .indoor else { return }
        if let distance = update.distanceMeters {
            indoorDistance = max(indoorDistance, distance)
        } else if let steps = update.steps {
            indoorDistance = max(indoorDistance, RunMath.indoorMeters(steps: steps, heightCM: heightCM))
        }
        let speed: Double?
        if let cadence = update.cadenceStepsPerSecond {
            if cadence >= 1.2 { speed = 1.5 }
            else if cadence <= 0.3 { speed = 0 }
            else { speed = nil }
        } else {
            speed = nil
        }
        lastSpeed = speed
        machine.ingest(speed: speed, at: update.timestamp)
        if machine.phase == .running {
            let moving = movingSeconds(now: max(clock(), update.timestamp))
            trace.append(DistanceSample(distanceMeters: indoorDistance, elapsedSeconds: moving))
        }
        refreshCues(now: clock())
        persist(now: clock())
    }

    func retryHealth(in context: ModelContext) async {
        await health.retryPending(in: context)
    }

    func discard(run: Run, context: ModelContext) {
        guard run.status == .active else { return }
        if runID == run.id { cancelOpenSession() }
        run.status = .discarded
        run.endedAt = clock()
        try? context.save()
        if ActiveRunBackup.load()?.runID == run.id { ActiveRunBackup.clear() }
    }

    func resume(run: Run, context: ModelContext, weightKG: Double, heightCM: Double) {
        guard run.status == .active, stage == .idle || stage == .finished else { return }
        self.context = context
        self.athleteID = run.athleteID
        self.weightKG = weightKG
        self.heightCM = heightCM
        runID = run.id
        startedAt = run.startedAt
        preferences.environment = run.environment
        machine = AutoPauseMachine()
        machine.config.enabled = preferences.autoPauseEnabled
        machine.begin(at: run.startedAt)
        var samples = run.route?.samples() ?? []
        if let backup = ActiveRunBackup.load(), backup.runID == run.id, backup.samples.count > samples.count {
            samples = backup.samples
            trace = backup.trace
            indoorDistance = backup.indoorDistance
        } else {
            trace = run.trace()
            indoorDistance = run.environment == .indoor ? run.distanceMeters : 0
        }
        accepted = samples
        stage = .live
        finishedRunID = nil
        setIdleTimerDisabled(true)
        speech.setSilenced(preferences.cuesSilenced)
        if run.environment == .outdoor {
            location.startUpdates(allowsBackground: true)
        } else {
            motion.start()
        }
        heart.start(strap: preferences.heartRateStrapEnabled)
        armTicker()
    }

    private func bind() {
        location.onPoint = { [weak self] point in
            Task { @MainActor in self?.ingestLocation(point) }
        }
        location.onDenied = { [weak self] in
            Task { @MainActor in
                self?.permissionNote = "Location is off. This run can keep time, but it will not draw a route until location is allowed for CMSN Performance."
            }
        }
        motion.onUpdate = { [weak self] update in
            Task { @MainActor in self?.ingestMotion(update) }
        }
        heart.onHeartRate = { [weak self] bpm in
            Task { @MainActor in self?.ingestHeart(bpm) }
        }
    }

    private func ingestHeart(_ bpm: Double) {
        guard isSessionOpen else { return }
        heartRate = bpm
        heartRates.append(bpm)
    }

    private func beginLive(at now: Date) {
        guard let context, let athleteID else {
            stage = .idle
            stopSensors()
            return
        }
        stage = .live
        startedAt = now
        machine.begin(at: now)
        if !preferences.cuesSilenced { speech.speak("Go.") }
        haptic(.tick)
        let run = Run(
            athleteID: athleteID,
            startedAt: now,
            environment: preferences.environment,
            source: .phone,
            status: .active
        )
        context.insert(run)
        runID = run.id
        try? context.save()
        persist(now: now)
    }

    private func finalize(at now: Date) {
        guard let context, let runID, let run = existing(runID, in: context) else {
            endError = "This run couldn't be saved. If a backup is on this phone, open Run and resume it."
            stage = .finished
            return
        }
        let moving = movingSeconds(now: now)
        run.endedAt = now
        run.status = .ended
        run.distanceMeters = distanceMeters
        run.movingSeconds = moving
        run.pausedSeconds = machine.pausedSeconds(now: now)
        run.setTrace(trace)
        run.elevationGainMeters = RunMath.elevationGainMeters(altitudes: accepted.map(\.altitudeMeters))
        run.calories = RunMath.kilocalories(weightKG: weightKG, movingSeconds: moving, distanceMeters: distanceMeters)
        if !heartRates.isEmpty {
            run.averageHeartRate = heartRates.reduce(0, +) / Double(heartRates.count)
        }
        if run.route == nil {
            let route = RunRoute(samples: accepted)
            route.run = run
            run.route = route
            context.insert(route)
        } else {
            run.route?.replaceSamples(accepted)
        }
        let drafts = RunMath.splits(samples: trace, unitMeters: preferences.distanceUnit.meters)
        for draft in drafts {
            let split = RunSplit(
                index: draft.index,
                distanceMeters: draft.distanceMeters,
                elapsedSeconds: draft.elapsedSeconds,
                isPartial: draft.isPartial,
                run: run
            )
            context.insert(split)
        }
        do {
            try context.save()
        } catch {
            endError = "The run finished, and saving it failed. \(error.localizedDescription)"
        }
        ActiveRunBackup.clear()
        stage = .finished
        finishedRunID = run.id
        haptic(.success)
        let saved = run
        Task { await health.sync(run: saved, context: context) }
    }

    private func persist(now: Date) {
        guard let context, let runID, let run = existing(runID, in: context) else { return }
        run.distanceMeters = distanceMeters
        run.movingSeconds = movingSeconds(now: now)
        run.pausedSeconds = machine.pausedSeconds(now: now)
        run.setTrace(trace)
        if let bpm = heartRate { run.averageHeartRate = bpm }
        if run.route == nil {
            let route = RunRoute(samples: accepted)
            route.run = run
            run.route = route
            context.insert(route)
        } else {
            run.route?.replaceSamples(accepted)
        }
        try? context.save()
        guard let id = self.runID else { return }
        ActiveRunBackup.save(ActiveRunBackupFile(
            runID: id,
            samples: accepted,
            trace: trace,
            indoorDistance: indoorDistance
        ))
    }

    private func refreshCues(now: Date) {
        let distance = distanceMeters
        let elapsed = movingSeconds(now: now)
        if RunMath.shouldAnnounce(
            frequency: preferences.cueFrequency,
            silenced: preferences.cuesSilenced,
            previousDistance: lastCueDistance,
            distance: distance,
            previousElapsed: lastCueElapsed,
            elapsed: elapsed
        ) {
            speech.speak(RunMath.cueSentence(
                distanceMeters: distance,
                movingSeconds: elapsed,
                unit: preferences.distanceUnit,
                frequency: preferences.cueFrequency
            ))
        }
        lastCueDistance = distance
        lastCueElapsed = elapsed
    }

    private func prepareHealth() async {
        var state = health.liveAuthorizationState()
        if state == .notDetermined {
            state = await health.requestAuthorization()
        }
        if state == .denied {
            permissionNote = "Apple Health is off. This run still saves on this phone. It will not appear in Health until sharing is allowed."
        }
    }

    private func stopSensors() {
        location.stopUpdates()
        motion.stop()
        heart.stop()
        speech.stop()
    }

    private func cancelOpenSession() {
        stopSensors()
        ticker?.invalidate()
        stage = .idle
        setIdleTimerDisabled(false)
    }

    private func armTicker() {
        ticker?.invalidate()
        guard automaticallyTicks else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func existing(_ id: UUID, in context: ModelContext) -> Run? {
        let target = id
        var descriptor = FetchDescriptor<Run>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func deviceHaptic(_ kind: RunHaptic) {
        switch kind {
        case .tick:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
