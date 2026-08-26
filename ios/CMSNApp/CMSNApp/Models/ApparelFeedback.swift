import Foundation
import SwiftData

/// The post-session, <20-second, always-optional apparel feedback loop —
/// the "Dress" side of the five-loop system. Local-only storage in V0;
/// aggregation for real product/fit decisions is a V2 backend concern (see
/// `brand/08-app-strategy.md` §9), but the schema exists now so nothing
/// collected today is lost once a backend lands.
@Model
final class ApparelFeedback {
    @Attribute(.unique) var id: UUID
    var garmentName: String
    var sizeWorn: String
    var stayedInPlace: Bool?
    var waistbandSecure: Bool?
    var restrictedMovement: Bool?
    var sweatManaged: Bool?
    var seamIrritation: Bool?
    var wouldWearAgain: Bool?
    var freeTextNote: String
    var loggedAt: Date

    var session: WorkoutSession?

    init(
        id: UUID = UUID(),
        garmentName: String,
        sizeWorn: String,
        stayedInPlace: Bool? = nil,
        waistbandSecure: Bool? = nil,
        restrictedMovement: Bool? = nil,
        sweatManaged: Bool? = nil,
        seamIrritation: Bool? = nil,
        wouldWearAgain: Bool? = nil,
        freeTextNote: String = "",
        loggedAt: Date = Date()
    ) {
        self.id = id
        self.garmentName = garmentName
        self.sizeWorn = sizeWorn
        self.stayedInPlace = stayedInPlace
        self.waistbandSecure = waistbandSecure
        self.restrictedMovement = restrictedMovement
        self.sweatManaged = sweatManaged
        self.seamIrritation = seamIrritation
        self.wouldWearAgain = wouldWearAgain
        self.freeTextNote = freeTextNote
        self.loggedAt = loggedAt
    }
}
