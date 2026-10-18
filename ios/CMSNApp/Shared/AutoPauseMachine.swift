import Foundation

struct PauseInterval: Equatable, Codable {
    var start: Date
    var end: Date?
}

enum RunActivityPhase: String, Equatable, Codable {
    case ready
    case running
    case autoPaused
    case manualPaused
    case ended
}

struct AutoPauseConfig: Equatable {
    var enabled: Bool = true
    /// Below this, and held, the clock pauses. About a slow walk.
    var pauseBelowMetersPerSecond: Double = 0.45
    /// Above this, and held, an automatic pause resumes. Manual pause does not.
    var resumeAboveMetersPerSecond: Double = 0.9
    var pauseAfter: TimeInterval = 3
    var resumeAfter: TimeInterval = 1
}

/// Stopped time pauses the clock. Moving time resumes it. A missing speed
/// (GPS dropout, invalid fix) never pauses and never ends the run.
struct AutoPauseMachine: Equatable {
    private(set) var phase: RunActivityPhase = .ready
    private(set) var pauses: [PauseInterval] = []
    var config: AutoPauseConfig = AutoPauseConfig()
    private var slowSince: Date?
    private var fastSince: Date?

    mutating func begin(at date: Date) {
        guard phase == .ready || phase == .ended else { return }
        phase = .running
        pauses = []
        slowSince = nil
        fastSince = nil
        _ = date
    }

    mutating func ingest(speed: Double?, at date: Date) {
        guard phase == .running || phase == .autoPaused else { return }
        guard config.enabled else {
            slowSince = nil
            fastSince = nil
            return
        }
        guard let speed, speed >= 0 else {
            slowSince = nil
            fastSince = nil
            return
        }
        switch phase {
        case .running:
            fastSince = nil
            if speed < config.pauseBelowMetersPerSecond {
                if let slowSince {
                    if date.timeIntervalSince(slowSince) >= config.pauseAfter {
                        phase = .autoPaused
                        pauses.append(PauseInterval(start: slowSince, end: nil))
                        self.slowSince = nil
                    }
                } else {
                    slowSince = date
                }
            } else {
                slowSince = nil
            }
        case .autoPaused:
            slowSince = nil
            if speed > config.resumeAboveMetersPerSecond {
                if let fastSince {
                    if date.timeIntervalSince(fastSince) >= config.resumeAfter {
                        closeOpenPause(at: date)
                        phase = .running
                        self.fastSince = nil
                    }
                } else {
                    fastSince = date
                }
            } else {
                fastSince = nil
            }
        default:
            break
        }
    }

    mutating func pauseManually(at date: Date) {
        guard phase == .running || phase == .autoPaused else { return }
        if phase == .running {
            pauses.append(PauseInterval(start: date, end: nil))
        }
        phase = .manualPaused
        slowSince = nil
        fastSince = nil
    }

    mutating func resumeManually(at date: Date) {
        guard phase == .manualPaused || phase == .autoPaused else { return }
        closeOpenPause(at: date)
        phase = .running
        slowSince = nil
        fastSince = nil
    }

    /// The only end path. A call with `holdCompleted == false` changes nothing.
    @discardableResult
    mutating func end(holdCompleted: Bool, at date: Date) -> Bool {
        guard holdCompleted else { return false }
        guard phase == .running || phase == .autoPaused || phase == .manualPaused else { return false }
        closeOpenPause(at: date)
        phase = .ended
        slowSince = nil
        fastSince = nil
        return true
    }

    func movingSeconds(startedAt: Date, now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(startedAt) - pausedSeconds(now: now))
    }

    func pausedSeconds(now: Date) -> TimeInterval {
        pauses.reduce(0) { sum, interval in
            let end = interval.end ?? now
            return sum + max(0, end.timeIntervalSince(interval.start))
        }
    }

    private mutating func closeOpenPause(at date: Date) {
        guard let index = pauses.indices.last, pauses[index].end == nil else { return }
        pauses[index].end = max(date, pauses[index].start)
    }
}
