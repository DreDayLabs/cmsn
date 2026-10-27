import Foundation
import SwiftData

/// One row per athlete. Restrictive-diet answers live in the same SwiftData
/// store as the profile, the same way run preferences live on `RunSettings`.
/// The field is not on `Athlete` itself: that model is shared by schema V1–V4,
/// and adding a column there would rewrite those versions.
@Model
final class NutritionDietPreference {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var athleteID: UUID
    /// Stable `RestrictiveDietID` raw values. Unknown strings are ignored on read.
    var dietIDsRaw: [String]
    /// `FastingWindow` raw value. Meaningful only while intermittent fasting is selected.
    var fastingWindowRaw: String?

    init(id: UUID = UUID(), athleteID: UUID, selection: NutritionDietSelection) {
        self.id = id
        self.athleteID = athleteID
        self.dietIDsRaw = selection.dietIDs.map(\.rawValue)
        self.fastingWindowRaw = selection.fastingWindow?.rawValue
    }

    var selection: NutritionDietSelection {
        NutritionDietSelection(rawDietIDs: dietIDsRaw, fastingWindowRaw: fastingWindowRaw)
    }

    func apply(_ selection: NutritionDietSelection) {
        dietIDsRaw = selection.dietIDs.map(\.rawValue)
        fastingWindowRaw = selection.fastingWindow?.rawValue
    }
}
