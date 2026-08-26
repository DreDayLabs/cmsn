import Foundation

/// In-progress onboarding answers before they're committed to a real
/// `Athlete`. Kept as a plain value type so every step view can bind to it
/// without touching SwiftData until the final "Start Training" tap — one
/// shape for every user, no gender-exclusive fields or branches anywhere.
struct OnboardingDraft {
    var name: String = ""
    var age: Int = 28
    var heightCM: Double = 178
    var weightKG: Double = 82
    var biologicalSexForCalculation: BiologicalSexForCalculation = .preferNotToSay

    var goalWeightKG: Double?
    var clothingSizeGoal: String = ""
    var bodyCompositionGoalNote: String = ""

    var experienceLevel: ExperienceLevel = .beginner
    var trainingFrequencyPerWeek: Int = 3
    var preferredSessionLengthMinutes: Int = 45
    var preferredStyles: Set<TrainingStyle> = [.strength]
    var equipmentProfile: EquipmentProfile = .residentialGym
    var goalTypes: Set<GoalType> = [.generalFitness]

    var limitations: [BodyLimitation] = []

    var unitPreference: UnitPreference = .imperial
    var coachingTone: CoachingTone = .encouraging

    func makeAthlete() -> Athlete {
        Athlete(
            name: name.isEmpty ? nil : name,
            age: age,
            heightCM: heightCM,
            weightKG: weightKG,
            biologicalSexForCalculation: biologicalSexForCalculation,
            goalWeightKG: goalWeightKG,
            clothingSizeGoal: clothingSizeGoal.isEmpty ? nil : clothingSizeGoal,
            bodyCompositionGoalNote: bodyCompositionGoalNote.isEmpty ? nil : bodyCompositionGoalNote,
            experienceLevel: experienceLevel,
            trainingFrequencyPerWeek: trainingFrequencyPerWeek,
            preferredSessionLengthMinutes: preferredSessionLengthMinutes,
            preferredStyles: Array(preferredStyles),
            equipmentProfile: equipmentProfile,
            goalTypes: Array(goalTypes),
            limitations: limitations,
            unitPreference: unitPreference,
            coachingTone: coachingTone,
            onboardingCompletedAt: Date()
        )
    }
}
