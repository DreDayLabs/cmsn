import Foundation
import SwiftData

struct SavedCoachingExplanation: Codable, Equatable {
    var exerciseName: String
    var setNumber: Int
    var rationale: String
    var suggestedWeightKG: Double?
}

/// Separate additive table: no historical WorkoutSession/LoggedSet shape changes.
@Model
final class PlusSessionRecord {
    @Attribute(.unique) var sessionID: UUID
    var coachingEnabled: Bool
    var explanationsData: Data

    init(sessionID: UUID, coachingEnabled: Bool) {
        self.sessionID = sessionID
        self.coachingEnabled = coachingEnabled
        explanationsData = Data()
    }
    var explanations: [String: SavedCoachingExplanation] {
        (try? JSONDecoder().decode([String: SavedCoachingExplanation].self, from: explanationsData)) ?? [:]
    }
    func record(setID: UUID, explanation: SavedCoachingExplanation) {
        var values = explanations
        values[setID.uuidString] = explanation
        if let encoded = try? JSONEncoder().encode(values) { explanationsData = encoded }
    }
}
