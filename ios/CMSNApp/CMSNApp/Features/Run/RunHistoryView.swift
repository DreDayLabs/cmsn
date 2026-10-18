import SwiftData
import SwiftUI

struct RunHistoryView: View {
    let athlete: Athlete
    @Query(sort: \Run.startedAt, order: .reverse) private var runs: [Run]
    @State private var granularity: TrendGranularity = .week

    private var unit: RunDistanceUnit { athlete.unitPreference == .imperial ? .miles : .kilometers }
    private var ended: [Run] { runs.filter { $0.athleteID == athlete.id && $0.status == .ended } }
    private var summaries: [RunSummary] { ended.map { $0.summary() } }
    private var lifetime: Double { summaries.reduce(0) { $0 + $1.distanceMeters } }
    private var level: RunLevel { RunLevel.current(lifetimeMeters: lifetime) }

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    levelCard
                    trend
                    badges
                    list
                }
                .padding(24)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Lifetime")
            Text(RunMath.formatDistance(lifetime, unit: unit, places: 1) + " " + unit.label)
                .font(CMSNTypography.displaySmall(44))
                .foregroundStyle(CMSNColor.offWhite)
        }
    }

    private var levelCard: some View {
        let upcoming = RunLevel.next(after: level)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: level.toneHex))
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
                Text(level.name)
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.offWhite)
                Spacer()
            }
            if let upcoming {
                Text("Next is \(upcoming.name)")
                    .font(CMSNTypography.caption())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(CMSNColor.Semantic.border)
                        Rectangle()
                            .fill(CMSNColor.offWhite)
                            .frame(width: geo.size.width * RunLevel.progress(lifetimeMeters: lifetime))
                    }
                }
                .frame(height: 3)
            } else {
                Text("House. The top of the ladder.")
                    .font(CMSNTypography.caption())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
        }
        .padding(16)
        .cmsnCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Run level \(level.name)")
    }

    private var trend: some View {
        let buckets = RunMath.trendBuckets(
            runs: summaries,
            granularity: granularity,
            now: Date(),
            calendar: Calendar.current,
            count: granularity == .week ? 8 : 6
        )
        let maxDistance = max(buckets.map(\.distanceMeters).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel(text: "Mileage")
                Spacer()
                ForEach(TrendGranularity.allCases) { item in
                    Button(item.title) { granularity = item }
                        .font(CMSNTypography.eyebrow())
                        .foregroundStyle(granularity == item ? CMSNColor.offBlack : CMSNColor.offWhite)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .cmsnChip(isSelected: granularity == item)
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(granularity == item ? .isSelected : [])
                }
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(buckets) { bucket in
                    VStack(spacing: 6) {
                        Rectangle()
                            .fill(CMSNColor.offWhite)
                            .frame(height: max(2, 88 * bucket.distanceMeters / maxDistance))
                            .accessibilityLabel(trendLabel(bucket))
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 110, alignment: .bottom)
            .padding(16)
            .cmsnCard()
            if let latest = buckets.last, let pace = latest.paceSecondsPerMeter {
                Text("Latest \(granularity.title.lowercased()) pace \(RunMath.formatPace(RunMath.paceSecondsPerUnit(pace, unit: unit)))\(unit.paceSuffix)")
                    .font(CMSNTypography.caption())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
        }
    }

    private var badges: some View {
        let streak = RunMath.weeklyStreak(runDates: ended.map(\.startedAt), now: Date(), calendar: .current)
        let earned = RunMath.badges(runs: summaries, streak: streak)
        let board = RunMath.board(runs: summaries)
        return VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Badges")
            if earned.isEmpty && board.isEmpty {
                Text("Finish a 5K, or string weeks together, and they show up here.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(earned) { badge in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(badge.title).font(CMSNTypography.body()).foregroundStyle(CMSNColor.offWhite)
                            Text(badge.detail).font(CMSNTypography.caption()).foregroundStyle(CMSNColor.Semantic.textSecondary)
                        }
                    }
                    ForEach(board) { hit in
                        Text(hit.kind == .longest
                             ? "\(hit.kind.title) · \(RunMath.formatDistance(hit.distanceMeters, unit: unit)) \(unit.label)"
                             : "\(hit.kind.title) · \(RunMath.formatDuration(hit.seconds))")
                            .font(CMSNTypography.body())
                            .foregroundStyle(CMSNColor.offWhite)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cmsnCard()
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Runs")
            if ended.isEmpty {
                Text("No finished runs yet.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(ended, id: \.id) { run in
                        NavigationLink {
                            RunSummaryView(runID: run.id, athlete: athlete)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(RunMath.formatDistance(run.distanceMeters, unit: unit) + " " + unit.label)
                                        .font(CMSNTypography.body())
                                        .foregroundStyle(CMSNColor.offWhite)
                                    Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(CMSNTypography.caption())
                                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                                }
                                Spacer()
                                Text(run.paceSecondsPerMeter.map { RunMath.formatPace(RunMath.paceSecondsPerUnit($0, unit: unit)) } ?? "—")
                                    .font(CMSNTypography.numeric(16))
                                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                            }
                            .padding(16)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the run summary.")
                        if run.id != ended.last?.id {
                            Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1).padding(.leading, 16)
                        }
                    }
                }
                .cmsnCard()
            }
        }
    }

    private func trendLabel(_ bucket: TrendBucket) -> String {
        let distance = RunMath.formatDistance(bucket.distanceMeters, unit: unit)
        return "\(bucket.start.formatted(date: .abbreviated, time: .omitted)) \(distance) \(unit.label)"
    }
}
