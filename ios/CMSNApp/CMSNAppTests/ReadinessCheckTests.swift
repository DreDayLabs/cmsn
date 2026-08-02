import XCTest
@testable import CMSNApp

final class ReadinessCheckTests: XCTestCase {
    func testLowEnergyAndPoorSleepYieldsLowBand() {
        let check = ReadinessCheck(energyLevel: 1, sleepQuality: 1)
        // score = 1 (energy) + 1 (sleep) = 2 -> low
        XCTAssertEqual(check.readinessBand, .low)
    }

    func testModerateInputsYieldModerateBand() {
        let check = ReadinessCheck(energyLevel: 3, sleepQuality: 3)
        // score = 3 + 3 = 6 -> moderate
        XCTAssertEqual(check.readinessBand, .moderate)
    }

    func testHighEnergyGoodSleepLowSorenessYieldsHighBand() {
        let check = ReadinessCheck(energyLevel: 5, soreness: 1, sleepQuality: 5)
        // score = 5 + 5 = 10, soreness 1 -> no reduction (max(0, 1-2) = 0) -> high
        XCTAssertEqual(check.readinessBand, .high)
    }

    func testHighSorenessPullsScoreDownFromHigh() {
        let check = ReadinessCheck(energyLevel: 5, soreness: 5, sleepQuality: 5)
        // score = 10 - max(0, 5-2)=3 -> 7 -> still moderate, not high
        XCTAssertEqual(check.readinessBand, .moderate)
    }

    func testMissingSleepQualityDefaultsToNeutralContribution() {
        let withDefault = ReadinessCheck(energyLevel: 3, sleepQuality: nil)
        let withNeutralSleep = ReadinessCheck(energyLevel: 3, sleepQuality: 3)
        XCTAssertEqual(withDefault.readinessBand, withNeutralSleep.readinessBand)
    }

    func testJointDiscomfortAreasRoundTripThroughRawStorage() {
        let check = ReadinessCheck(jointDiscomfortAreas: [.knee, .shoulder])
        XCTAssertEqual(Set(check.jointDiscomfortAreas), Set([.knee, .shoulder]))
    }
}
