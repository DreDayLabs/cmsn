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
                VStack(alignment: .leading, spacing: 20) {
                    header
                    completionSummary
                    nutritionRemainder
                    TrainingDayWhyCard(adjustment: adjustment)
                    scoreSection
                    recoveryRecommendation
                    shareSection

                    Button("Log how your gear performed") {
                        showingApparelFeedback = true
                    }
                    .buttonStyle(.cmsnGhost)
                    .accessibilityLabel("Log How Your Gear Performed")
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(CMSNColor.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("\(session.splitFocus.displayName) · Complete")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Session logged")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            Text("IT COUNTS.")
                .font(CMSNTypography.display(64))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, -6)
            Text(headerDetail)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerDetail: String {
        if wasFullyCompleted {
            return "You hit the plan. That's logged."
        }
        return "You didn't hit everything on the plan today. That's still real, logged work."
    }

    private var completionSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(totalSetsAttempted)")
                    .font(CMSNTypography.display(80))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text("/ \(totalSetsPlanned)")
                    .font(CMSNTypography.display(36))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            .padding(.vertical, -8)
            Text("planned sets done")
                .font(.system(size: 15))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)

            VStack(spacing: 0) {
                ForEach(session.loggedExercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { exercise in
                    let attempted = exercise.loggedSets.filter(\.isAttempted).count
                    HStack {
                        Text(exercise.exerciseNameSnapshot)
                            .font(.system(size: 16))
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                            .lineLimit(2)
                        Spacer(minLength: 12)
                        Text("\(attempted)/\(exercise.loggedSets.count)")
                            .font(CMSNTypography.numeric(16))
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    /// Today's training-day targets minus today's diary. The targets include
    /// this session when it has a finish time and a cited activity.
    private var nutritionRemainder: some View {
        let remainder = remainingMacros
        return VStack(alignment: .leading, spacing: 14) {
            Text("Next: refuel")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(proteinNumber(remainder))
                            .font(CMSNTypography.display(48))
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Text(proteinUnit(remainder))
                            .font(.system(size: 16))
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                    Text(refuelCaption(remainder))
                        .font(.system(size: 14))
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                Spacer(minLength: 8)
                Button("Log food") {
                    appState.selectedTab = .nutrition
                }
                .buttonStyle(.cmsnCompactPrimary)
                .accessibilityLabel("Log Food")
            }
            if remainder.entriesMissingCalories > 0, let note = contextNote(remainder) {
                Text(note)
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    private func proteinNumber(_ remaining: RemainingMacros) -> String {
        if !remaining.hasLoggedFood {
            return "\(whole(remaining.proteinTargetGrams))"
        }
        let left = remaining.proteinRemainingGrams
        if left.rounded() < 0 {
            return "\(whole(abs(left)))"
        }
        return "\(whole(left))"
    }

    private func proteinUnit(_ remaining: RemainingMacros) -> String {
        if remaining.hasLoggedFood, remaining.proteinRemainingGrams.rounded() < 0 {
            return "g over"
        }
        return "g protein"
    }

    private func refuelCaption(_ remaining: RemainingMacros) -> String {
        if !remaining.hasLoggedFood {
            return "~\(whole(remaining.calorieTarget)) kcal · Nothing logged yet"
        }
        return calorieLine(remaining)
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
            Text("CMSN score")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            Text("+\(Int(scoreBreakdown.total))")
                .font(CMSNTypography.display(48))
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
            Text(label).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textSecondary)
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
            Text("Recovery")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
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
