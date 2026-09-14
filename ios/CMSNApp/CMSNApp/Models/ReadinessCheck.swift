import Foundation
import SwiftData

/// The pre-session readiness check on the Today screen. Every field is
/// optional except `energyLevel` — the spec wants this fast enough for the
/// minimum user to clear in a few taps, not a mandatory questionnaire.
@Model
final class ReadinessCheck {
    @Attribute(.unique) var id: UUID
    var date: Date
    var energyLevel: Int // 1...5
    var soreness: Int?   // 1...5
    var jointDiscomfortAreasRaw: [String]
    var sleepQuality: Int? // 1...5
    var motivation: Int?   // 1...5
    var availableMinutes: Int?

    var session: WorkoutSession?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        energyLevel: Int = 3,
        soreness: Int? = nil,
        jointDiscomfortAreas: [BodyArea] = [],
        sleepQuality: Int? = nil,
        motivation: Int? = nil,
        availableMinutes: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.energyLevel = energyLevel
        self.soreness = soreness
        self.jointDiscomfortAreasRaw = jointDiscomfortAreas.map(\.rawValue)
        self.sleepQuality = sleepQuality
        self.motivation = motivation
        self.availableMinutes = availableMinutes
    }

    var jointDiscomfortAreas: [BodyArea] {
        get { jointDiscomfortAreasRaw.compactMap(BodyArea.init(rawValue:)) }
        set { jointDiscomfortAreasRaw = newValue.map(\.rawValue) }
    }

    /// Coarse readiness signal `ProgramResolver` and `RuleBasedSuggestionEngine`
    /// use to trim volume/intensity — deliberately simple (three buckets) so
    /// it's predictable rather than a black box.
    var readinessBand: ReadinessBand {
        var score = energyLevel
        if let sleepQuality { score += sleepQuality } else { score += 3 }
        if let soreness { score -= max(0, soreness - 2) }
        switch score {
        case ..<5: return .low
        case 5...7: return .moderate
        default: return .high
        }
    }
}

enum ReadinessBand: Equatable {
    case low, moderate, high
}
