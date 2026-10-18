import AVFoundation
import CoreBluetooth
import CoreLocation
import CoreMotion
import Foundation
import HealthKit

protocol RunLocationProviding: AnyObject {
    var onPoint: ((TrackPoint) -> Void)? { get set }
    var onDenied: (() -> Void)? { get set }
    func startUpdates(allowsBackground: Bool)
    func stopUpdates()
}

protocol RunMotionProviding: AnyObject {
    var onUpdate: ((MotionUpdate) -> Void)? { get set }
    func start()
    func stop()
}

struct MotionUpdate: Equatable {
    var distanceMeters: Double?
    var steps: Int?
    var cadenceStepsPerSecond: Double?
    var timestamp: Date
}

protocol RunSpeechProviding: AnyObject {
    func speak(_ text: String)
    func stop()
    func setSilenced(_ silenced: Bool)
}

protocol HeartRateProviding: AnyObject {
    var onHeartRate: ((Double) -> Void)? { get set }
    func start(strap: Bool)
    func stop()
}

/// Background location only while `startUpdates` is in effect. `stopUpdates`
/// clears the background flag in the same call.
final class CoreLocationRunService: NSObject, RunLocationProviding, CLLocationManagerDelegate {
    var onPoint: ((TrackPoint) -> Void)?
    var onDenied: (() -> Void)?

    private let manager = CLLocationManager()
    private var wantsUpdates = false
    private var wantsBackground = false

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
    }

    func startUpdates(allowsBackground: Bool) {
        wantsUpdates = true
        wantsBackground = allowsBackground
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            begin()
        case .authorizedAlways:
            begin()
        case .denied, .restricted:
            onDenied?()
        @unknown default:
            onDenied?()
        }
    }

    func stopUpdates() {
        wantsUpdates = false
        wantsBackground = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if wantsUpdates { begin() }
        case .denied, .restricted:
            if wantsUpdates { onDenied?() }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard wantsUpdates else { return }
        let points = locations.map { location in
            TrackPoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil,
                timestamp: location.timestamp,
                horizontalAccuracy: location.horizontalAccuracy,
                speedMetersPerSecond: location.speed
            )
        }
        let handler = onPoint
        Task { @MainActor in
            points.forEach { handler?($0) }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A failed fix is not the end of the run. The next fix can still land.
    }

    private func begin() {
        guard wantsUpdates else { return }
        if wantsBackground, manager.authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        } else {
            manager.allowsBackgroundLocationUpdates = false
        }
        manager.startUpdatingLocation()
    }
}

/// Indoor distance. Pedometer distance when the system has it, otherwise
/// step count times a height-based stride applied by the session.
final class PedometerRunService: RunMotionProviding {
    var onUpdate: ((MotionUpdate) -> Void)?
    private let pedometer = CMPedometer()
    private var running = false

    func start() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        running = true
        pedometer.startUpdates(from: Date()) { [weak self] data, _ in
            guard let self, self.running, let data else { return }
            let update = MotionUpdate(
                distanceMeters: data.distance.map { $0.doubleValue },
                steps: data.numberOfSteps.intValue,
                cadenceStepsPerSecond: data.currentCadence?.doubleValue,
                timestamp: Date()
            )
            let handler = self.onUpdate
            Task { @MainActor in handler?(update) }
        }
    }

    func stop() {
        running = false
        pedometer.stopUpdates()
    }
}

final class RunSpeechService: NSObject, RunSpeechProviding, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var silenced = false
    private var sessionTouched = false

    func setSilenced(_ silenced: Bool) {
        self.silenced = silenced
        if silenced { synthesizer.stopSpeaking(at: .immediate) }
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !silenced, !trimmed.isEmpty else { return }
        let session = AVAudioSession.sharedInstance()
        // A phone call owns the audio. Skip the cue. Do not end the run.
        if session.secondaryAudioShouldBeSilencedHint { return }
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
            sessionTouched = true
        } catch {
            return
        }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        guard sessionTouched else { return }
        sessionTouched = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

/// Heart rate from Apple Health (the watch writes it) and, only when the
/// athlete turned the strap on, a standard Bluetooth heart-rate monitor.
final class HeartRateService: NSObject, HeartRateProviding, CBCentralManagerDelegate, CBPeripheralDelegate {
    var onHeartRate: ((Double) -> Void)?

    private let store = HKHealthStore()
    private var query: HKAnchoredObjectQuery?
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var scanning = false
    private static let service = CBUUID(string: "180D")
    private static let measurement = CBUUID(string: "2A37")

    func start(strap: Bool) {
        startHealthQuery()
        guard strap else { return }
        scanning = true
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil)
        } else if central?.state == .poweredOn {
            central?.scanForPeripherals(withServices: [Self.service], options: nil)
        }
    }

    func stop() {
        scanning = false
        if let query {
            store.stop(query)
            self.query = nil
        }
        central?.stopScan()
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil
    }

    private func startHealthQuery() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-5), end: nil)
        let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
            self?.publish(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.publish(samples)
        }
        store.execute(query)
        self.query = query
    }

    private func publish(_ samples: [HKSample]?) {
        guard let sample = samples?.compactMap({ $0 as? HKQuantitySample }).last else { return }
        let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        guard bpm > 0, bpm < 250 else { return }
        let handler = onHeartRate
        Task { @MainActor in handler?(bpm) }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard scanning, central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: [Self.service], options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard scanning, self.peripheral == nil else { return }
        self.peripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.service])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.service }) else { return }
        peripheral.discoverCharacteristics([Self.measurement], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == Self.measurement }) else { return }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, let bpm = Self.beatsPerMinute(from: data) else { return }
        let handler = onHeartRate
        Task { @MainActor in handler?(bpm) }
    }

    /// Bluetooth Heart Rate Measurement. First byte flags, then the BPM.
    static func beatsPerMinute(from data: Data) -> Double? {
        guard let flags = data.first else { return nil }
        if flags & 0x01 == 0 {
            guard data.count >= 2 else { return nil }
            let bpm = Double(data[1])
            return bpm > 0 ? bpm : nil
        }
        guard data.count >= 3 else { return nil }
        let bpm = Double(UInt16(data[1]) | (UInt16(data[2]) << 8))
        return bpm > 0 ? bpm : nil
    }
}
