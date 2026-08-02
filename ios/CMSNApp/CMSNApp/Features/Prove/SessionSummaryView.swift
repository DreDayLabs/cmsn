import SwiftUI

/// Prove. Shows what actually happened — planned vs. completed, PRs,
/// score movement, a recovery recommendation, and an optional (never
/// mandatory) apparel-feedback prompt. Partial sessions are presented
/// exactly as honestly and positively as complete ones — no "you failed to
/// finish" framing anywhere in this screen.
struct SessionSummaryView: View {
    let session: WorkoutSession
    let scoreBreakdown: ScoreBreakdown
    let athlete: Athlete

    @Environment(AppState.self) private var appState
    @State private var showingApparelFeedback = false
    @State private var shareImage: UIImage?

    private var totalSetsAttempted: Int {
        session.loggedExercises.flatMap(\.loggedSets).filter(\.isAttempted).count
    }
    private var totalSetsPlanned: Int {
        session.loggedExercises.flatMap(\.loggedSets).count
    }
    private var wasFullyCompleted: Bool { totalSetsAttempted >= totalSetsPlanned && totalSetsPlanned > 0 }

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    completionSummary
                    scoreSection
                    recoveryRecommendation
                    shareSection

                    Button("Log How Your Gear Performed") {
                        showingApparelFeedback = true
                    }
                    .buttonStyle(.cmsnGhost)
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showingApparelFeedback) {
            ApparelFeedbackView(session: session)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: wasFullyCompleted ? "Session Complete" : "Session Logged")
            Text(session.splitFocus.displayName)
                .font(CMSNTypography.displaySmall(40))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            if !wasFullyCompleted {
                Text("You didn't hit everything on the plan today — that's still real, logged work. It counts.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
        }
    }

    private var completionSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Work")
            Text("\(totalSetsAttempted) of \(totalSetsPlanned) planned sets")
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            ForEach(session.loggedExercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { exercise in
                let attempted = exercise.loggedSets.filter(\.isAttempted).count
                Text("· \(exercise.exerciseNameSnapshot): \(attempted)/\(exercise.loggedSets.count)")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
        }
        .padding(20)
        .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "CMSN Score")
            Text("+\(Int(scoreBreakdown.total))")
                .font(CMSNTypography.displaySmall(32))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            scoreRow("Work", scoreBreakdown.work)
            scoreRow("Consistency", scoreBreakdown.consistency)
            scoreRow("Progress", scoreBreakdown.progress)
            scoreRow("Discipline & Recovery", scoreBreakdown.discipline)
        }
        .padding(20)
        .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
    }

    private func scoreRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).font(CMSNTypography.bodyQuiet()).foregroundStyle(CMSNColor.Semantic.textSecondary)
            Spacer()
            Text("\(Int(value))").font(CMSNTypography.numeric(14)).foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }

    private var recoveryRecommendation: some View {
        let anyDiscomfort = session.loggedExercises.flatMap(\.loggedSets).contains { $0.discomfortReported }
        let message: String = anyDiscomfort
            ? "You reported some discomfort today. Consider a lighter session or full rest tomorrow, and \(InjurySafetyLanguage.professionalCue.lowercased())"
            : (session.readiness?.readinessBand == .low
                ? "Your readiness was low going in — prioritize sleep and protein tonight before your next session."
                : "Solid session. A normal rest/recovery day tomorrow keeps this sustainable.")
        return VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Recovery")
            Text(message).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let shareImage {
                ShareLink(item: Image(uiImage: shareImage), preview: SharePreview("CMSN Session", image: Image(uiImage: shareImage))) {
                    Text("Share This Session").font(CMSNTypography.eyebrow()).kerning(1.6)
                }
                .buttonStyle(.cmsnPrimary)
            } else {
                Button("Generate Share Card") {
                    shareImage = ShareCardRenderer.renderImage(
                        focus: session.splitFocus,
                        setsCompleted: totalSetsAttempted,
                        totalScore: scoreBreakdown.total,
                        date: session.date
                    )
                }
                .buttonStyle(.cmsnGhost)
            }
        }
    }
}
