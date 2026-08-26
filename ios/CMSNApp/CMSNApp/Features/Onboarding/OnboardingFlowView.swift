import SwiftUI

/// The three-step onboarding wizard. `existingAthlete` handles the edge
/// case where an `Athlete` row exists but `onboardingCompletedAt` was never
/// set (e.g. the app was killed mid-onboarding) — the draft resumes from
/// whatever's already saved rather than starting over.
struct OnboardingFlowView: View {
    let existingAthlete: Athlete?
    /// Called once the wizard has saved the athlete profile. Distinct from
    /// `Athlete.hasCompletedOnboarding` flipping true: the caller (typically
    /// `OnboardingNarrativeView`) uses this to advance its own step machine
    /// rather than relying on a model change to drive navigation.
    let onFinish: () -> Void
    @Environment(AppState.self) private var appState

    @State private var draft: OnboardingDraft
    @State private var step: Step = .trainingProfile

    private enum Step { case trainingProfile, equipment, limitations }

    init(existingAthlete: Athlete?, onFinish: @escaping () -> Void = {}) {
        self.existingAthlete = existingAthlete
        self.onFinish = onFinish
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
        onFinish()
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
