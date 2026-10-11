import SwiftUI

/// The CMSN Score tab: the four-dimension breakdown plus a recent-events
/// feed. Deliberately no global leaderboard in V0 — that's a V2/backend
/// feature (see plan) — this is a local, honest record of the athlete's
/// own work, consistency, progress, and discipline.
struct ScoreView: View {
    let athlete: Athlete
    @Environment(AppState.self) private var appState

    @State private var breakdown: ScoreBreakdown = ScoreBreakdown(work: 0, consistency: 0, progress: 0, discipline: 0, total: 0)
    @State private var recentEvents: [ScoreEvent] = []

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        dimensionBreakdown
                        recentActivity
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { reload() }
            .refreshable { reload() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                CMSNWordmark(height: 16)
                Spacer()
                Text("This week")
                    .font(.system(size: 15))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            Text("CMSN score")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .padding(.top, 8)
            // The figure is the real weighted total. "/ 100" is the approved
            // frame from the v01 board. The score is not capped at 100.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(breakdown.total.rounded()))")
                    .font(CMSNTypography.display(148))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text("/ 100")
                    .font(CMSNTypography.display(44))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            Text("Earned in the gym, the kitchen and recovery.")
                .font(.system(size: 15))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CMSN score")
        .accessibilityValue("\(Int(breakdown.total.rounded())) of 100")
    }

    private var dimensionBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            dimensionBar(title: ScoreDimension.work.displayName, raw: breakdown.work, weight: ScoreWeights.work)
            dimensionBar(title: ScoreDimension.consistency.displayName, raw: breakdown.consistency, weight: ScoreWeights.consistency)
            dimensionBar(title: ScoreDimension.progress.displayName, raw: breakdown.progress, weight: ScoreWeights.progress)
            dimensionBar(title: ScoreDimension.discipline.displayName, raw: breakdown.discipline, weight: ScoreWeights.disciplineAndRecovery)
        }
        .padding(20)
        .cmsnCard()
    }

    private func dimensionBar(title: String, raw: Double, weight: Double) -> some View {
        let contribution = raw * weight
        let fraction = min(1, raw / 40)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Spacer(minLength: 8)
                Text("\(Int(contribution.rounded())) pts")
                    .font(CMSNTypography.numeric(15))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text("\(Int((weight * 100).rounded()))% weight")
                    .font(CMSNTypography.numeric(15))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(CMSNColor.Semantic.track)
                    Capsule()
                        .fill(CMSNColor.white)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 8)
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activity")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            if recentEvents.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "diamond")
                        .font(.system(size: 18))
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(CMSNColor.black))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No activity yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Text("Complete a session to start earning score.")
                            .font(.system(size: 13))
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button("Start") {
                        appState.selectedTab = .today
                    }
                    .buttonStyle(.cmsnCompactPrimary)
                }
                .padding(14)
                .cmsnCard()
            }
            ForEach(recentEvents.prefix(20)) { event in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.reason).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Text(event.date.formatted(date: .abbreviated, time: .omitted))
                            .font(CMSNTypography.caption())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                    Spacer()
                    Text("+\(Int(event.points))")
                        .font(CMSNTypography.numeric(14))
                        .foregroundStyle(CMSNColor.Semantic.scorePositive)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func reload() {
        let events = appState.scoreRepository.allEvents()
        recentEvents = events
        breakdown = ScoreCalculator.compositeScore(from: events)
    }
}
