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
                    .padding(24)
                }
            }
            .task { reload() }
            .refreshable { reload() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "CMSN Score")
            Text("\(Int(breakdown.total))")
                .font(CMSNTypography.displaySmall(64))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }

    private var dimensionBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            dimensionBar(title: ScoreDimension.work.displayName, raw: breakdown.work, weight: ScoreWeights.work)
            dimensionBar(title: ScoreDimension.consistency.displayName, raw: breakdown.consistency, weight: ScoreWeights.consistency)
            dimensionBar(title: ScoreDimension.progress.displayName, raw: breakdown.progress, weight: ScoreWeights.progress)
            dimensionBar(title: ScoreDimension.discipline.displayName, raw: breakdown.discipline, weight: ScoreWeights.disciplineAndRecovery)
        }
        .padding(20)
        .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
    }

    private func dimensionBar(title: String, raw: Double, weight: Double) -> some View {
        let contribution = raw * weight
        let maxBarRaw: Double = max(1, recentEvents.map { $0.points }.reduce(0, +))
        let fraction = min(1, raw / max(maxBarRaw, 1))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).kerning(1.2)
                Spacer()
                Text("\(Int(contribution)) pts · \(Int(weight * 100))% weight")
                    .font(CMSNTypography.bodyQuiet())
            }
            .foregroundStyle(CMSNColor.Semantic.textSecondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(CMSNColor.Semantic.divider)
                    Rectangle().fill(CMSNColor.offWhite).frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Recent Activity")
            if recentEvents.isEmpty {
                Text("Complete a session to start earning score.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            ForEach(recentEvents.prefix(20)) { event in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.reason).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Text(event.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 10))
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                    Spacer()
                    Text("+\(Int(event.points))")
                        .font(CMSNTypography.numeric(14))
                        .foregroundStyle(CMSNColor.Semantic.scorePositive)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func reload() {
        let events = appState.scoreRepository.allEvents()
        recentEvents = events
        breakdown = ScoreCalculator.compositeScore(from: events)
    }
}
