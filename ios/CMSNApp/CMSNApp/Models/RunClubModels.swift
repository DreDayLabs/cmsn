import Foundation
import SwiftData

/// Phase 2 hold space. These models ship empty. No screen creates them,
/// and `RunClubNavigationSlot.isPresented` stays false. The relationships
/// are real so a later club UI does not need another migration.

@Model
final class RunClub {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var name: String
    var about: String

    @Relationship(deleteRule: .cascade, inverse: \ClubMembership.club)
    var memberships: [ClubMembership]

    @Relationship(deleteRule: .cascade, inverse: \Challenge.club)
    var challenges: [Challenge]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        name: String,
        about: String = "",
        memberships: [ClubMembership] = [],
        challenges: [Challenge] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.about = about
        self.memberships = memberships
        self.challenges = challenges
    }
}

@Model
final class ClubMembership {
    @Attribute(.unique) var id: UUID
    var athleteID: UUID
    var joinedAt: Date
    var roleRaw: String
    var club: RunClub?

    init(
        id: UUID = UUID(),
        athleteID: UUID,
        joinedAt: Date = Date(),
        roleRaw: String = "member",
        club: RunClub? = nil
    ) {
        self.id = id
        self.athleteID = athleteID
        self.joinedAt = joinedAt
        self.roleRaw = roleRaw
        self.club = club
    }
}

@Model
final class Challenge {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String
    var startsAt: Date
    var endsAt: Date
    var goalDistanceMeters: Double
    var club: RunClub?

    @Relationship(deleteRule: .cascade, inverse: \ChallengeEntry.challenge)
    var entries: [ChallengeEntry]

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        startsAt: Date,
        endsAt: Date,
        goalDistanceMeters: Double,
        club: RunClub? = nil,
        entries: [ChallengeEntry] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.goalDistanceMeters = goalDistanceMeters
        self.club = club
        self.entries = entries
    }
}

@Model
final class ChallengeEntry {
    @Attribute(.unique) var id: UUID
    var athleteID: UUID
    var runID: UUID?
    var distanceMeters: Double
    var recordedAt: Date
    var challenge: Challenge?

    init(
        id: UUID = UUID(),
        athleteID: UUID,
        runID: UUID? = nil,
        distanceMeters: Double,
        recordedAt: Date = Date(),
        challenge: Challenge? = nil
    ) {
        self.id = id
        self.athleteID = athleteID
        self.runID = runID
        self.distanceMeters = distanceMeters
        self.recordedAt = recordedAt
        self.challenge = challenge
    }
}
