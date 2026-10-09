import Foundation
import SwiftData

/// One body-weight sample. Kilograms are the stored unit; the athlete's
/// `unitPreference` only changes how the number is entered and shown.
///
/// Tied to an athlete by id rather than a SwiftData relationship so
/// `Athlete`'s persisted shape does not change. The V2→V3 migration can
/// add this model — and seed it from the existing `weightKG` — without
/// rewriting profile rows that are already on disk.
@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var athleteID: UUID
    /// When the athlete weighed this. Separate from `createdAt` (when the
    /// row was written) so a backfilled sample can sit earlier on the
    /// chart than one logged today.
    var recordedAt: Date
    var createdAt: Date
    var weightKG: Double

    init(
        id: UUID = UUID(),
        athleteID: UUID,
        recordedAt: Date = Date(),
        createdAt: Date = Date(),
        weightKG: Double
    ) {
        self.id = id
        self.athleteID = athleteID
        self.recordedAt = recordedAt
        self.createdAt = createdAt
        self.weightKG = weightKG
    }
}

/// Written once, the first time weight history is seeded. Stops a later
/// launch from inventing a new "original" sample after the athlete has
/// deleted every entry. Not user-facing data.
@Model
final class WeightHistorySeedMarker {
    @Attribute(.unique) var id: UUID
    var seededAt: Date

    init(id: UUID = UUID(), seededAt: Date = Date()) {
        self.id = id
        self.seededAt = seededAt
    }
}
