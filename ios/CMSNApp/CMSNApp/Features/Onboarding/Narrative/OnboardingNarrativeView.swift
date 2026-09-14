import SwiftUI
import SwiftData

/// Coordinates the full first-run narrative: motivation -> what's new ->
/// join the crew -> the existing profile-intake wizard -> about -> workout
/// plan -> score intro -> `MainTabView`.
///
/// Gates on `firstRunNarrativeCompletedAt`, not `onboardingCompletedAt` — the
/// embedded `OnboardingFlowView` sets the latter as soon as the profile
/// wizard finishes, several steps before this narrative is actually done.
/// If `RootView` gated on `onboardingCompletedAt` it would swap straight to
/// `MainTabView` mid-narrative, destroying this view's state. See
/// `Athlete.swift` for the field and `RootView.swift` for the gate.
struct OnboardingNarrativeView: View {
    let existingAthlete: Athlete?
    @Environment(AppState.self) private var appState
    @Query private var athletes: [Athlete]

    @State private var step: Step = .motivation

    private enum Step { case motivation, whatsNew, joinCrew, profileIntake, about, workoutPlan, scoreIntro }

    private var athlete: Athlete? { athletes.first ?? existingAthlete }

    var body: some View {
        Group {
            switch step {
            case .motivation:
                NarrativeWelcomeView(onContinue: { step = .whatsNew })
            case .whatsNew:
                WhatsNewCarouselView(onContinue: { step = .joinCrew })
            case .joinCrew:
                JoinCrewView(onBegin: { step = .profileIntake })
            case .profileIntake:
                OnboardingFlowView(existingAthlete: existingAthlete, onFinish: { step = .about })
            case .about:
                EarnYourCMSNView(onContinue: { step = .workoutPlan })
            case .workoutPlan:
                if let athlete {
                    WorkoutPlanConfirmView(athlete: athlete, onContinue: { step = .scoreIntro })
                } else {
                    // Shouldn't happen — profileIntake always persists an
                    // Athlete before advancing — but fail forward rather
                    // than strand the user on a blank screen.
                    ProgressView().onAppear { step = .scoreIntro }
                }
            case .scoreIntro:
                ScoreIntroView(onFinish: finish)
            }
        }
    }

    private func finish() {
        guard let athlete = appState.athleteRepository.currentAthlete() else { return }
        athlete.firstRunNarrativeCompletedAt = Date()
        appState.athleteRepository.save()
    }
}
