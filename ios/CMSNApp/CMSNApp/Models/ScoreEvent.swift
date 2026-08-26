import Foundation
import SwiftData

/// The four dimensions of the CMSN Score. Weights live in
/// `ScoreCalculator.Weights`, not here — this type is just the taxonomy.
enum ScoreDimension: String, Codable, CaseIterable, Identifiable {
    case work, consistency, progress, discipline
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .work: return "Work"
        case .consistency: return "Consistency"
        case .progress: return "Progress"
        case .discipline: return "Discipline & Recovery"
        }
    }
}

/// One atomic scoring event. Score is always the sum of events, never a
/// single mutable counter — this is what makes "returning after 21 days
/// earns recognition" and "a rest day earns discipline credit" auditable and
/// testable rather than magic numbers scattered through the UI.
@Model
final class ScoreEvent {
    @Attribute(.unique) var id: UUID
    var date: Date
    var dimensionRaw: String
    var points: Double
    var reason: String
    var relatedSessionID: UUID?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        dimension: ScoreDimension,
        points: Double,
        reason: String,
        relatedSessionID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.dimensionRaw = dimension.rawValue
        self.points = points
        self.reason = reason
        self.relatedSessionID = relatedSessionID
    }

    var dimension: ScoreDimension { ScoreDimension(rawValue: dimensionRaw) ?? .work }
}
