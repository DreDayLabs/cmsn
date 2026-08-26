import XCTest
@testable import CMSNApp

final class OneRepMaxEstimatorTests: XCTestCase {
    func testSingleRepReturnsWeightExactly() {
        XCTAssertEqual(OneRepMaxEstimator.epley(weight: 100, reps: 1), 100)
    }

    func testKnownEpleyValue() {
        // 100 * (1 + 10/30) = 133.33...
        let result = OneRepMaxEstimator.epley(weight: 100, reps: 10)
        XCTAssertEqual(result, 133.333, accuracy: 0.01)
    }

    func testZeroRepsReturnsZero() {
        XCTAssertEqual(OneRepMaxEstimator.epley(weight: 100, reps: 0), 0)
    }

    func testZeroWeightReturnsZero() {
        XCTAssertEqual(OneRepMaxEstimator.epley(weight: 0, reps: 10), 0)
    }

    func testHigherRepsProduceHigherEstimate() {
        let low = OneRepMaxEstimator.epley(weight: 100, reps: 5)
        let high = OneRepMaxEstimator.epley(weight: 100, reps: 12)
        XCTAssertGreaterThan(high, low)
    }
}

final class WeightRoundingTests: XCTestCase {
    func testRoundsToNearestIncrement() {
        XCTAssertEqual(WeightRounding.round(103, to: 5), 105)
        XCTAssertEqual(WeightRounding.round(102, to: 5), 100)
        // 102.5 / 5 == 20.5, and Double.rounded() rounds halves away from
        // zero by default, so this rounds up to 105, not down to 100.
        XCTAssertEqual(WeightRounding.round(102.5, to: 5), 105, accuracy: 0.001)
    }

    func testZeroIncrementReturnsOriginalValue() {
        XCTAssertEqual(WeightRounding.round(103, to: 0), 103)
    }

    func testBarbellIncrementDiffersFromMachine() {
        let barbell = WeightRounding.incrementKG(for: .barbell, unitPreference: .imperial)
        let machine = WeightRounding.incrementKG(for: .machine, unitPreference: .imperial)
        XCTAssertLessThan(barbell, machine)
    }
}
