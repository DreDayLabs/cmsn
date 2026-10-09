import Charts
import SwiftData
import SwiftUI

/// Body-weight history. Lives under Settings → Account because the number
/// is profile data (the same `weightKG` macros already read), not a CMSN
/// Score dimension and not a meal. The chart is the athlete's own record
/// on this device — no goal badge, no streak, no color for "up" or "down".
struct WeightLogView: View {
    let athlete: Athlete
    @Environment(\.modelContext) private var modelContext

    @State private var entries: [WeightEntry] = []
    @State private var showingComposer = false

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    chartSection
                    historySection
                    Button("Log Weight") { showingComposer = true }
                        .buttonStyle(.cmsnPrimary)
                    Text("Stored on this device. Your latest entry is the weight your targets use.")
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                .padding(24)
            }
        }
        .task { reload() }
        .sheet(isPresented: $showingComposer, onDismiss: reload) {
            LogWeightSheet(athlete: athlete)
        }
    }

    private var currentKG: Double {
        WeightLogRepository.latest(in: entries)?.weightKG ?? athlete.weightKG
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Body Weight")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.1f", athlete.unitPreference.displayWeight(fromKilograms: currentKG)))
                    .font(CMSNTypography.numeric(48))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text(athlete.unitPreference.weightUnitLabel)
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(athlete.unitPreference.formattedWeight(kilograms: currentKG))
            Text(trendLine)
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
    }

    private var trendLine: String {
        guard entries.count >= 2,
              let earliest = entries.min(by: { $0.recordedAt < $1.recordedAt }),
              let latest = WeightLogRepository.latest(in: entries) else {
            if let only = entries.first {
                return "Started \(only.recordedAt.formatted(date: .abbreviated, time: .omitted))."
            }
            return "No entries yet."
        }
        let delta = athlete.unitPreference.displayWeight(fromKilograms: latest.weightKG - earliest.weightKG)
        let since = earliest.recordedAt.formatted(date: .abbreviated, time: .omitted)
        if abs(delta) < 0.05 {
            return "Unchanged since \(since)."
        }
        return "\(String(format: "%+.1f", delta)) \(athlete.unitPreference.weightUnitLabel) since \(since)."
    }

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Trend")
            if entries.isEmpty {
                Text("Log a weight to start a record.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            } else {
                trendChart
                    .frame(height: 180)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(trendLine)
            }
        }
        .padding(20)
        .cmsnCard()
    }

    private var trendChart: some View {
        let units = athlete.unitPreference
        let points = entries.map { units.displayWeight(fromKilograms: $0.weightKG) }
        let domain = Self.yDomain(for: points)
        let span = (domain.upperBound - domain.lowerBound)
        return Chart(entries) { entry in
            LineMark(
                x: .value("Date", entry.recordedAt),
                y: .value("Weight", units.displayWeight(fromKilograms: entry.weightKG))
            )
            .foregroundStyle(CMSNColor.offWhite)
            .lineStyle(StrokeStyle(lineWidth: 1.5))

            PointMark(
                x: .value("Date", entry.recordedAt),
                y: .value("Weight", units.displayWeight(fromKilograms: entry.weightKG))
            )
            .foregroundStyle(CMSNColor.offWhite)
            .symbolSize(36)
        }
        .chartYScale(domain: domain)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(CMSNColor.Semantic.divider)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(CMSNTypography.caption())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(CMSNColor.Semantic.divider)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(span < 5 ? String(format: "%.1f", number) : String(format: "%.0f", number))
                            .font(CMSNTypography.caption())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                }
            }
        }
    }

    private var newestFirst: [WeightEntry] {
        entries.sorted { lhs, rhs in
            if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt > rhs.recordedAt }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Entries")
            if newestFirst.isEmpty {
                Text("Nothing logged.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            ForEach(newestFirst) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(athlete.unitPreference.formattedWeight(kilograms: entry.weightKG))
                            .font(CMSNTypography.numeric(16))
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        Text(entry.recordedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(CMSNTypography.caption())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        delete(entry)
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func reload() {
        entries = WeightLogRepository(context: modelContext).entries(for: athlete.id)
    }

    private func delete(_ entry: WeightEntry) {
        WeightLogRepository(context: modelContext).delete(entry, athlete: athlete)
        reload()
    }

    /// Pad the axis so a flat line doesn't sit on the plot edge.
    static func yDomain(for values: [Double]) -> ClosedRange<Double> {
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        if low == high {
            let pad = max(1, abs(low) * 0.02)
            return (low - pad)...(high + pad)
        }
        let pad = max(0.5, (high - low) * 0.2)
        return (low - pad)...(high + pad)
    }
}

/// Capture one sample in the athlete's unit. Stored as kilograms.
private struct LogWeightSheet: View {
    let athlete: Athlete
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var draft: Double
    @State private var recordedDay = Date()
    @State private var rejected = false
    @FocusState private var weightFocused: Bool

    init(athlete: Athlete) {
        self.athlete = athlete
        let display = athlete.unitPreference.displayWeight(fromKilograms: athlete.weightKG)
        _draft = State(initialValue: (display * 10).rounded() / 10)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            EyebrowLabel(text: "New Entry")
                            Text("Log Weight")
                                .font(CMSNTypography.displaySmall(34))
                                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Weight")
                                    .font(CMSNTypography.body())
                                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                                Spacer()
                                TextField(athlete.unitPreference.weightUnitLabel, value: $draft, format: .number.precision(.fractionLength(0...1)))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .focused($weightFocused)
                                    .frame(width: 100)
                                    .font(CMSNTypography.numeric(16))
                                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                                Text(athlete.unitPreference.weightUnitLabel)
                                    .font(CMSNTypography.body())
                                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                            }
                            DatePicker(
                                "Date",
                                selection: $recordedDay,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .tint(CMSNColor.offWhite)
                            .font(CMSNTypography.body())
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        }
                        .padding(16)
                        .cmsnCard()

                        if rejected {
                            Text("Enter a weight above zero.")
                                .font(CMSNTypography.bodyQuiet())
                                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        }

                        Button("Save Entry") { save() }
                            .buttonStyle(.cmsnPrimary)
                    }
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.buttonStyle(.cmsnText)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { weightFocused = false }
                        .font(CMSNTypography.body())
                        .foregroundStyle(CMSNColor.offWhite)
                }
            }
        }
    }

    private func save() {
        let kilograms = athlete.unitPreference.kilograms(fromDisplay: draft)
        let recordedAt = commitDate()
        let saved = WeightLogRepository(context: modelContext).addEntry(
            weightKG: kilograms,
            recordedAt: recordedAt,
            athlete: athlete
        )
        guard saved != nil else {
            rejected = true
            return
        }
        dismiss()
    }

    /// Today is "now", so a same-day log sorts after a seed written earlier
    /// today. Any other day is the start of that day.
    private func commitDate() -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(recordedDay) { return Date() }
        return calendar.startOfDay(for: recordedDay)
    }
}
