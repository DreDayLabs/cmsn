import XCTest
@testable import CMSNApp

final class AutoPauseMachineTests: XCTestCase {
    func testStandingThreeSecondsPausesAndMovingResumes() {
        var machine = AutoPauseMachine()
        let start = Date(timeIntervalSince1970: 1_000)
        machine.begin(at: start)
        machine.ingest(speed: 0, at: start)
        machine.ingest(speed: 0, at: start.addingTimeInterval(2))
        XCTAssertEqual(machine.phase, .running)
        machine.ingest(speed: 0, at: start.addingTimeInterval(3))
        XCTAssertEqual(machine.phase, .autoPaused)

        machine.ingest(speed: 2, at: start.addingTimeInterval(3))
        XCTAssertEqual(machine.phase, .autoPaused)
        machine.ingest(speed: 2, at: start.addingTimeInterval(3.5))
        XCTAssertEqual(machine.phase, .autoPaused)
        machine.ingest(speed: 2, at: start.addingTimeInterval(4))
        XCTAssertEqual(machine.phase, .running)
    }

    func testMissingOrNegativeSpeedNeverPausesAndClearsTheSlowTimer() {
        var machine = AutoPauseMachine()
        let start = Date(timeIntervalSince1970: 2_000)
        machine.begin(at: start)
        machine.ingest(speed: nil, at: start.addingTimeInterval(30))
        machine.ingest(speed: -1, at: start.addingTimeInterval(90))
        XCTAssertEqual(machine.phase, .running)

        machine.ingest(speed: 0, at: start.addingTimeInterval(100))
        machine.ingest(speed: nil, at: start.addingTimeInterval(101))
        machine.ingest(speed: 0, at: start.addingTimeInterval(102))
        machine.ingest(speed: 0, at: start.addingTimeInterval(104))
        XCTAssertEqual(machine.phase, .running)
        machine.ingest(speed: 0, at: start.addingTimeInterval(105))
        XCTAssertEqual(machine.phase, .autoPaused)
    }

    func testManualPauseDoesNotAutoResume() {
        var machine = AutoPauseMachine()
        let start = Date(timeIntervalSince1970: 3_000)
        machine.begin(at: start)
        machine.pauseManually(at: start.addingTimeInterval(1))
        machine.ingest(speed: 3, at: start.addingTimeInterval(5))
        machine.ingest(speed: 3, at: start.addingTimeInterval(10))
        XCTAssertEqual(machine.phase, .manualPaused)
        machine.resumeManually(at: start.addingTimeInterval(12))
        XCTAssertEqual(machine.phase, .running)
    }

    func testEndRequiresTheHold() {
        var machine = AutoPauseMachine()
        let start = Date(timeIntervalSince1970: 4_000)
        machine.begin(at: start)
        XCTAssertFalse(machine.end(holdCompleted: false, at: start.addingTimeInterval(5)))
        XCTAssertEqual(machine.phase, .running)
        XCTAssertTrue(machine.end(holdCompleted: true, at: start.addingTimeInterval(6)))
        XCTAssertEqual(machine.phase, .ended)
        XCTAssertFalse(machine.end(holdCompleted: true, at: start.addingTimeInterval(7)))
    }

    func testDisabledConfigNeverAutoPauses() {
        var machine = AutoPauseMachine()
        machine.config.enabled = false
        let start = Date(timeIntervalSince1970: 5_000)
        machine.begin(at: start)
        machine.ingest(speed: 0, at: start)
        machine.ingest(speed: 0, at: start.addingTimeInterval(30))
        XCTAssertEqual(machine.phase, .running)
    }

    func testMovingTimeStartsThePauseWhenTheAthleteStopped() {
        var machine = AutoPauseMachine()
        let start = Date(timeIntervalSince1970: 6_000)
        machine.begin(at: start)
        machine.ingest(speed: 2, at: start)
        machine.ingest(speed: 0, at: start.addingTimeInterval(5))
        machine.ingest(speed: 0, at: start.addingTimeInterval(8))
        XCTAssertEqual(machine.phase, .autoPaused)
        XCTAssertEqual(machine.movingSeconds(startedAt: start, now: start.addingTimeInterval(10)), 5, accuracy: 0.001)
    }
}
