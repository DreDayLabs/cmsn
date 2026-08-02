import SwiftUI

/// The three-step onboarding wizard. `existingAthlete` handles the edge
/// case where an `Athlete` row exists but `onboardingCompletedAt` was never
/// set (e.g. the app was killed mid-onboarding) — the draft resumes from
/// whatever's already saved rather than starting over.
struct OnboardingFlowView: View {
    let existingAthlete: Athlete?
    @Environment(AppState.self) private var appState

    @State private var draft: OnboardingDraft
    @State private var step: Step = .trainingProfile

    private enum Step { case trainingProfile, equipment, limitations }

    init(existingAthlete: Athlete?) {
        self.existingAthlete = existingAthlete
        if let existing = existingAthlete {
            _draft = State(initialValue: OnboardingDraft(
                name: existing.name ?? "",
                age: existing.age,
                heightCM: existing.heightCM,
                weightKG: existing.weightKG,
                biologicalSexForCalculation: existing.biologicalSexForCalculation,
                goalWeightKG: existing.goalWeightKG,
                clothingSizeGoal: existing.clothingSizeGoal ?? "",
                bodyCompositionGoalNote: existing.bodyCompositionGoalNote ?? "",
                experienceLevel: existing.experienceLevel,
                trainingFrequencyPerWeek: existing.trainingFrequencyPerWeek,
                preferredSessionLengthMinutes: existing.preferredSessionLengthMinutes,
                preferredStyles: Set(existing.preferredStyles),
                equipmentProfile: existing.equipmentProfile,
                goalTypes: Set(existing.goalTypes),
                limitations: existing.limitations,
                unitPreference: existing.unitPreference,
                coachingTone: existing.coachingTone
            ))
        } else {
            _draft = State(initialValue: OnboardingDraft())
        }
    }

    var body: some View {
        Group {
            switch step {
            case .trainingProfile:
                TrainingProfileStepView(draft: $draft) { step = .equipment }
            case .equipment:
                EquipmentProfileStepView(draft: $draft, onNext: { step = .limitations }, onBack: { step = .trainingProfile })
            case .limitations:
                LimitationsStepView(draft: $draft, onFinish: finish, onBack: { step = .equipment })
            }
        }
    }

    private func finish() {
        let repository = appState.athleteRepository
        if let existing = existingAthlete {
            apply(draft, to: existing)
            existing.onboardingCompletedAt = Date()
            repository.save()
        } else {
            repository.createAthlete(draft.makeAthlete())
        }
    }

    private func apply(_ draft: OnboardingDraft, to athlete: Athlete) {
        athlete.name = draft.name.isEmpty ? nil : draft.name
        athlete.age = draft.age
        athlete.heightCM = draft.heightCM
        athlete.weightKG = draft.weightKG
        athlete.biologicalSexForCalculation = draft.biologicalSexForCalculation
        athlete.goalWeightKG = draft.goalWeightKG
        athlete.clothingSizeGoal = draft.clothingSizeGoal.isEmpty ? nil : draft.clothingSizeGoal
        athlete.bodyCompositionGoalNote = draft.bodyCompositionGoalNote.isEmpty ? nil : draft.bodyCompositionGoalNote
        athlete.experienceLevel = draft.experienceLevel
        athlete.trainingFrequencyPerWeek = draft.trainingFrequencyPerWeek
        athlete.preferredSessionLengthMinutes = draft.preferredSessionLengthMinutes
        athlete.preferredStyles = Array(draft.preferredStyles)
        athlete.equipmentProfile = draft.equipmentProfile
        athlete.goalTypes = Array(draft.goalTypes)
        athlete.limitations = draft.limitations
        athlete.unitPreference = draft.unitPreference
        athlete.coachingTone = draft.coachingTone
    }
}
