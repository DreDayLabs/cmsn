import Foundation
import SwiftData

/// Shared shape for both catalog exercises (seeded, static) and
/// user-created custom exercises (SwiftData-backed) — features like
/// `ExerciseCardView` and `ProgramResolver` work against this protocol so
/// they don't care which kind of exercise they're holding.
protocol ExerciseRepresentable: Identifiable where ID == String {
    var name: String { get }
    var primaryMuscleGroups: [MuscleGroup] { get }
    var equipmentRequired: [EquipmentType] { get }
    var formCues: [String] { get }
    var commonMistake: String { get }
    var setupInstructions: String { get }
    var whyThisExercise: String { get }
    var easierAlternativeExerciseID: String? { get }
    var advancedAlternativeExerciseID: String? { get }
    /// Body areas this exercise meaningfully loads — what
    /// `ProgramResolver` checks a reported limitation against.
    var loadedBodyAreas: [BodyArea] { get }
    var trackingType: ExerciseTrackingType { get }
    var isUnilateral: Bool { get }
    /// V0 has no real video library — this is the named placeholder seam
    /// (see plan: "Explicitly deferred to V1"). `nil` means "no demo yet,"
    /// which the UI renders as a static setup illustration instead.
    var demonstrationVideoAssetName: String? { get }
}

/// A catalog (seeded) exercise. Value type, `Codable` so `SeedData` can
/// define the library as a plain Swift array literal.
struct Exercise: ExerciseRepresentable, Codable, Hashable {
    var id: String
    var name: String
    var primaryMuscleGroups: [MuscleGroup]
    var equipmentRequired: [EquipmentType]
    var formCues: [String]
    var commonMistake: String
    var setupInstructions: String
    var whyThisExercise: String
    var easierAlternativeExerciseID: String?
    var advancedAlternativeExerciseID: String?
    var loadedBodyAreas: [BodyArea]
    var trackingType: ExerciseTrackingType
    var isUnilateral: Bool = false
    var demonstrationVideoAssetName: String? = nil
}

/// A user-authored custom exercise — covers the "Exercise creation" /
/// "Exercise archiving" requirements. Persisted so it survives across
/// sessions and can be reused in future programs.
@Model
final class CustomExercise {
    @Attribute(.unique) var id: String
    var name: String
    var primaryMuscleGroupsRaw: [String]
    var equipmentRequiredRaw: [String]
    var formCues: [String]
    var commonMistake: String
    var setupInstructions: String
    var whyThisExercise: String
    var easierAlternativeExerciseID: String?
    var advancedAlternativeExerciseID: String?
    var loadedBodyAreasRaw: [String]
    var trackingTypeRaw: String
    var isUnilateral: Bool
    var demonstrationVideoAssetName: String?
    var createdAt: Date
    var isArchived: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        primaryMuscleGroups: [MuscleGroup],
        equipmentRequired: [EquipmentType],
        formCues: [String],
        commonMistake: String,
        setupInstructions: String,
        whyThisExercise: String,
        easierAlternativeExerciseID: String? = nil,
        advancedAlternativeExerciseID: String? = nil,
        loadedBodyAreas: [BodyArea] = [],
        trackingType: ExerciseTrackingType = .repsAndWeight,
        isUnilateral: Bool = false,
        demonstrationVideoAssetName: String? = nil,
        createdAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.primaryMuscleGroupsRaw = primaryMuscleGroups.map(\.rawValue)
        self.equipmentRequiredRaw = equipmentRequired.map(\.rawValue)
        self.formCues = formCues
        self.commonMistake = commonMistake
        self.setupInstructions = setupInstructions
        self.whyThisExercise = whyThisExercise
        self.easierAlternativeExerciseID = easierAlternativeExerciseID
        self.advancedAlternativeExerciseID = advancedAlternativeExerciseID
        self.loadedBodyAreasRaw = loadedBodyAreas.map(\.rawValue)
        self.trackingTypeRaw = trackingType.rawValue
        self.isUnilateral = isUnilateral
        self.demonstrationVideoAssetName = demonstrationVideoAssetName
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}

extension CustomExercise: ExerciseRepresentable {
    var primaryMuscleGroups: [MuscleGroup] { primaryMuscleGroupsRaw.compactMap(MuscleGroup.init(rawValue:)) }
    var equipmentRequired: [EquipmentType] { equipmentRequiredRaw.compactMap(EquipmentType.init(rawValue:)) }
    var loadedBodyAreas: [BodyArea] { loadedBodyAreasRaw.compactMap(BodyArea.init(rawValue:)) }
    var trackingType: ExerciseTrackingType { ExerciseTrackingType(rawValue: trackingTypeRaw) ?? .repsAndWeight }
}

/// Look-up across both the seeded catalog and the athlete's custom
/// exercises — the one place features go to resolve an `exerciseID`.
@MainActor
enum ExerciseCatalog {
    static func find(id: String, customExercises: [CustomExercise] = []) -> (any ExerciseRepresentable)? {
        if let seeded = SeedData.exercises.first(where: { $0.id == id }) {
            return seeded
        }
        return customExercises.first(where: { $0.id == id })
    }
}
