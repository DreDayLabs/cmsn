import Foundation
import SwiftData

/// The single training profile. One shape for every user — no
/// gender-exclusive branching anywhere in this model or the onboarding flow
/// that populates it, per the product direction's audience-balance rule.
///
/// V0 assumes a single local athlete profile (no multi-user accounts, no
/// backend) — `AthleteRepository` enforces "exactly one Athlete" until V2
/// adds auth.
@Model
final class Athlete {
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    // Identity (kept minimal; name is optional and never required to use the app)
    var name: String?

    // Physiological inputs — used for calorie/protein math and progressive
    // overload only, never surfaced as content-gating fields.
    var age: Int
    var heightCM: Double
    var weightKG: Double
    var biologicalSexForCalculation: BiologicalSexForCalculation

    // Optional goal markers. All optional because the product spec is
    // explicit that "improvement" isn't universally weight loss.
    var goalWeightKG: Double?
    var clothingSizeGoal: String?
    var bodyCompositionGoalNote: String?

    // Training shape
    var experienceLevel: ExperienceLevel
    var trainingFrequencyPerWeek: Int
    var preferredSessionLengthMinutes: Int
    var preferredStylesRaw: [String]
    var equipmentProfile: EquipmentProfile
    var trainingLocationNote: String?
    var goalTypesRaw: [String]

    // Injury/limitation intake — see BodyArea.swift. Stored as Codable
    // value-type array; SwiftData persists arrays of Codable structs
    // directly without a separate relationship.
    var limitations: [BodyLimitation]

    // Device/permission state
    var watchAvailable: Bool
    var healthKitAuthorized: Bool
    var calendarAuthorized: Bool

    // Preferences
    var unitPreference: UnitPreference
    var coachingTone: CoachingTone

    var onboardingCompletedAt: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        name: String? = nil,
        age: Int,
        heightCM: Double,
        weightKG: Double,
        biologicalSexForCalculation: BiologicalSexForCalculation = .preferNotToSay,
        goalWeightKG: Double? = nil,
        clothingSizeGoal: String? = nil,
        bodyCompositionGoalNote: String? = nil,
        experienceLevel: ExperienceLevel = .beginner,
        trainingFrequencyPerWeek: Int = 3,
        preferredSessionLengthMinutes: Int = 45,
        preferredStyles: [TrainingStyle] = [.strength],
        equipmentProfile: EquipmentProfile = .residentialGym,
        trainingLocationNote: String? = nil,
        goalTypes: [GoalType] = [.generalFitness],
        limitations: [BodyLimitation] = [],
        watchAvailable: Bool = false,
        healthKitAuthorized: Bool = false,
        calendarAuthorized: Bool = false,
        unitPreference: UnitPreference = .imperial,
        coachingTone: CoachingTone = .encouraging,
        onboardingCompletedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.age = age
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.biologicalSexForCalculation = biologicalSexForCalculation
        self.goalWeightKG = goalWeightKG
        self.clothingSizeGoal = clothingSizeGoal
        self.bodyCompositionGoalNote = bodyCompositionGoalNote
        self.experienceLevel = experienceLevel
        self.trainingFrequencyPerWeek = trainingFrequencyPerWeek
        self.preferredSessionLengthMinutes = preferredSessionLengthMinutes
        self.preferredStylesRaw = preferredStyles.map(\.rawValue)
        self.equipmentProfile = equipmentProfile
        self.trainingLocationNote = trainingLocationNote
        self.goalTypesRaw = goalTypes.map(\.rawValue)
        self.limitations = limitations
        self.watchAvailable = watchAvailable
        self.healthKitAuthorized = healthKitAuthorized
        self.calendarAuthorized = calendarAuthorized
        self.unitPreference = unitPreference
        self.coachingTone = coachingTone
        self.onboardingCompletedAt = onboardingCompletedAt
    }

    var preferredStyles: [TrainingStyle] {
        get { preferredStylesRaw.compactMap(TrainingStyle.init(rawValue:)) }
        set { preferredStylesRaw = newValue.map(\.rawValue) }
    }

    var goalTypes: [GoalType] {
        get { goalTypesRaw.compactMap(GoalType.init(rawValue:)) }
        set { goalTypesRaw = newValue.map(\.rawValue) }
    }

    /// Active (non-resolved) limitations at or above a given severity —
    /// what `ProgramResolver` actually filters exercises against.
    func activeLimitations(minimumSeverity: LimitationSeverity = .mild) -> [BodyLimitation] {
        limitations.filter { $0.severity >= minimumSeverity }
    }

    var hasCompletedOnboarding: Bool { onboardingCompletedAt != nil }
}
