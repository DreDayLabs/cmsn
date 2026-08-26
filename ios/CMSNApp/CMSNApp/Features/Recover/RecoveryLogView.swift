import SwiftUI

/// Standalone recovery-day logging — reachable whenever today resolves to
/// `.restDay`/`.recovery`, or any time the athlete wants to log a rest day
/// outside the normal training flow. Completing this earns real Discipline
/// score, on par with training — "recovery is part of performance," not an
/// afterthought.
struct RecoveryLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var sleepQuality: Int = 3
    @State private var soreness: Int = 2
    @State private var hydrationGlasses: Int = 6
    @State private var didMobilityOrWalk = false
    @State private var logged = false

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            EyebrowLabel(text: "Recover")
                            Text("Rest Day")
                                .font(CMSNTypography.displaySmall(36))
                                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                            Text("Constant exertion isn't discipline — a followed rest day counts just as much as a workout.")
                                .font(CMSNTypography.bodyQuiet())
                                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        }

                        stepperRow(title: "Sleep quality", value: $sleepQuality)
                        stepperRow(title: "Soreness", value: $soreness)

                        HStack {
                            Text("Water (glasses)").foregroundStyle(CMSNColor.Semantic.textPrimary)
                            Spacer()
                            Stepper("\(hydrationGlasses)", value: $hydrationGlasses, in: 0...20).fixedSize()
                        }
                        .font(CMSNTypography.body())

                        Toggle("Did some mobility work or walked today", isOn: $didMobilityOrWalk)
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)

                        if logged {
                            Text("Rest day logged. Discipline credit added to your CMSN Score.")
                                .font(CMSNTypography.body())
                                .foregroundStyle(CMSNColor.Semantic.scorePositive)
                        } else {
                            Button("Log Rest Day") { logRestDay() }
                                .buttonStyle(.cmsnPrimary)
                        }
                    }
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func stepperRow(title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title).foregroundStyle(CMSNColor.Semantic.textPrimary)
            Spacer()
            Stepper("\(value.wrappedValue)/5", value: value, in: 1...5).fixedSize()
        }
        .font(CMSNTypography.body())
    }

    private func logRestDay() {
        let events = ScoreCalculator.eventsForRestDayAdherence()
        appState.scoreRepository.record(events)
        logged = true
    }
}
