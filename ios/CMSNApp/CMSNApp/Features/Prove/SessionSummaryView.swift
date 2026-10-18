import SwiftData
import SwiftUI

/// Prove. Shows what actually happened — planned vs. completed, PRs,
/// score movement, protein and calories still open today, a recovery
/// recommendation, and an optional (never mandatory) apparel-feedback
/// prompt. Partial sessions are presented
/// exactly as honestly and positively as complete ones — no "you failed to
/// finish" framing anywhere in this screen.
struct SessionSummaryView: View {
    let session: WorkoutSession
    let scoreBreakdown: ScoreBreakdown
    let athlete: Athlete

    @Query(sort: \NutritionLog.date, order: .reverse) private var nutritionLogs: [NutritionLog]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    @Environment(AppState.self) private var appState
    @State private var showingApparelFeedback = false
    @State private var shareImage: UIImage?

    private var totalSetsAttempted: Int {
        session.loggedExercises.flatMap(\.loggedSets).filter(\.isAttempted).count
    }
    private var totalSetsPlanned: Int {
        session.loggedExercises.flatMap(\.loggedSets).count
    }
    private var wasFullyCompleted: Bool { session.wasFullyCompleted }

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    completionSummary
                    nutritionRemainder
                    TrainingDayWhyCard(adjustment: adjustment)
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
        .task(id: targetSyncID) {
            let targets = adjustment.adjusted
            appState.nutritionRepository.createOrFetchToday(
                proteinTarget: targets.proteinGrams,
                carbTarget: targets.carbGrams,
                fatTarget: targets.fatGrams,
                calorieEstimate: targets.calorieEstimate
            )
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
        .cmsnCard()
    }

    /// Today's training-day targets minus today's diary. The targets include
    /// this session when it has a finish time and a cited activity.
    private var nutritionRemainder: some View {
        let remainder = remainingMacros
        return VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Nutrition")
            Text(proteinFigure(remainder))
                .font(CMSNTypography.displaySmall(32))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text(proteinCaption(remainder))
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            if remainder.hasLoggedFood {
                Text("\(whole(remainder.proteinLoggedGrams))g logged of \(whole(remainder.proteinTargetGrams))g")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            Text(calorieLine(remainder))
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            if let note = contextNote(remainder) {
                Text(note)
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            Button("Log Food") {
                appState.selectedTab = .nutrition
            }
            .buttonStyle(.cmsnGhost)
        }
        .padding(20)
        .cmsnCard()
    }

    private var adjustment: TrainingDayAdjustment {
        TrainingDayAdjustment.adjust(athlete: athlete, sessions: workoutSessions, alsoIncluding: session)
    }

    private var remainingMacros: RemainingMacros {
        RemainingMacros.calculate(targets: adjustment.adjusted, entries: todaysEntries)
    }

    private var targetSyncID: String {
        let targets = adjustment.adjusted
        return "\(targets.proteinGrams)-\(targets.carbGrams)-\(targets.fatGrams)-\(targets.calorieEstimate)"
    }

    private var todaysEntries: [NutritionEntry] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return nutritionLogs
            .filter { $0.date >= start && $0.date < end }
            .flatMap(\.entries)
    }

    private func whole(_ value: Double) -> Int {
        Int(value.rounded())
    }

    private func proteinFigure(_ remaining: RemainingMacros) -> String {
        if !remaining.hasLoggedFood {
            return "\(whole(remaining.proteinTargetGrams))g"
        }
        let left = remaining.proteinRemainingGrams
        if left.rounded() < 0 {
            return "\(whole(abs(left)))g over"
        }
        return "\(whole(left))g"
    }

    private func proteinCaption(_ remaining: RemainingMacros) -> String {
        if !remaining.hasLoggedFood { return "protein target" }
        if remaining.proteinRemainingGrams.rounded() < 0 { return "today's protein target" }
        return "protein left"
    }

    private func calorieLine(_ remaining: RemainingMacros) -> String {
        if !remaining.hasLoggedFood {
            return "~\(whole(remaining.calorieTarget)) kcal"
        }
        let left = remaining.caloriesRemaining
        if left.rounded() < 0 {
            return "\(whole(abs(left))) kcal over today's estimate"
        }
        return "\(whole(left)) kcal left"
    }

    private func contextNote(_ remaining: RemainingMacros) -> String? {
        if !remaining.hasLoggedFood {
            return "Nothing logged yet. This is today's full target — log a meal and what's left will show up here."
        }
        if remaining.entriesMissingCalories > 0 {
            return "Some foods were logged without calories, so the calorie number only reflects what was recorded."
        }
        return nil
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
        .cmsnCard()
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
                    Text("Share This Session").font(CMSNTypography.button()).lineLimit(1)
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
