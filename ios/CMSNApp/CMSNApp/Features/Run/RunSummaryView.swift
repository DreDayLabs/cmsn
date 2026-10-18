import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct RunSummaryView: View {
    let runID: UUID
    let athlete: Athlete

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var runs: [Run]
    @Query private var shoes: [RunShoe]

    @State private var photoItem: PhotosPickerItem?
    @State private var shareURL: URL?
    @State private var celebrated = false

    private var run: Run? { runs.first { $0.id == runID } }
    private var unit: RunDistanceUnit { athlete.unitPreference == .imperial ? .miles : .kilometers }

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            if let run {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header(run)
                        stats(run)
                        if run.environment == .outdoor, run.route?.samples().count ?? 0 >= 2 {
                            PaceRouteMap(points: run.route?.samples() ?? [])
                                .frame(height: 240)
                                .cmsnCard()
                        } else {
                            Text("No route for this run.")
                                .font(CMSNTypography.bodyQuiet())
                                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        }
                        if !records(for: run).isEmpty {
                            recordBlock(records(for: run))
                        }
                        splits(run)
                        tags(run)
                        notes(run)
                        photo(run)
                        share(run)
                    }
                    .padding(24)
                }
                if !records(for: run).isEmpty && !reduceMotion {
                    ConfettiBurst().ignoresSafeArea()
                }
            }
        }
        .navigationTitle("Run")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { celebrateIfNeeded() }
        .onChange(of: photoItem) { _, item in
            guard let item, let run else { return }
            Task { await attach(item, to: run) }
        }
    }

    private func header(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: run.startedAt.formatted(date: .abbreviated, time: .shortened))
            Text(RunMath.formatDistance(run.distanceMeters, unit: unit) + " " + unit.label)
                .font(CMSNTypography.displaySmall(52))
                .foregroundStyle(CMSNColor.offWhite)
        }
    }

    private func stats(_ run: Run) -> some View {
        let pace = run.paceSecondsPerMeter.map { RunMath.formatPace(RunMath.paceSecondsPerUnit($0, unit: unit)) } ?? "—"
        return VStack(spacing: 0) {
            row("Pace", pace + " " + unit.paceSuffix)
            divider
            row("Time", RunMath.formatDuration(run.movingSeconds))
            divider
            row("Elevation", String(format: "%.0f m", run.elevationGainMeters))
            divider
            row("Calories", String(format: "%.0f", run.calories.rounded()))
            if let heart = run.averageHeartRate {
                divider
                row("Heart", "\(Int(heart.rounded())) bpm")
            }
        }
        .cmsnCard()
    }

    private func recordBlock(_ hits: [PersonalRecordHit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Personal records")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(hits) { hit in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hit.kind.title)
                            .font(CMSNTypography.body())
                            .foregroundStyle(CMSNColor.offWhite)
                        Text(recordDetail(hit))
                            .font(CMSNTypography.caption())
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cmsnCard()
        }
        .accessibilityElement(children: .combine)
    }

    private func splits(_ run: Run) -> some View {
        let ordered = run.splits.sorted { $0.index < $1.index }
        return VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Splits")
            if ordered.isEmpty {
                Text("No full split yet.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(ordered, id: \.id) { split in
                        let pace = RunMath.formatPace(RunMath.paceSecondsPerUnit(split.elapsedSeconds / max(split.distanceMeters, 1), unit: unit))
                        row(
                            split.isPartial ? "\(split.index) · partial" : "\(split.index)",
                            "\(RunMath.formatDistance(split.distanceMeters, unit: unit)) \(unit.label) · \(pace)"
                        )
                        if split.id != ordered.last?.id { divider }
                    }
                }
                .cmsnCard()
            }
        }
    }

    private func tags(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            chipRow("Ground", RunGround.allCases, run.ground) { choice in
                run.ground = run.ground == choice ? nil : choice
                save()
            }
            chipRow("Effort", RunEffort.allCases, run.effort) { choice in
                run.effort = run.effort == choice ? nil : choice
                save()
            }
            chipRow("Mood", RunMood.allCases, run.mood) { choice in
                run.mood = run.mood == choice ? nil : choice
                save()
            }
            shoePicker(run)
        }
    }

    private func chipRow<Option: Identifiable & Hashable>(
        _ title: String,
        _ options: [Option],
        _ selected: Option?,
        choose: @escaping (Option) -> Void
    ) -> some View where Option: RawRepresentable, Option.RawValue == String, Option.ID: Equatable {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: title)
            let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(options, id: \.id) { option in
                    let on = selected?.id == option.id
                    Button {
                        choose(option)
                    } label: {
                        Text(label(option))
                            .font(CMSNTypography.eyebrow())
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(on ? CMSNColor.offBlack : CMSNColor.Semantic.textPrimary)
                            .cmsnChip(isSelected: on)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(label(option))")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private func shoePicker(_ run: Run) -> some View {
        let mine = shoes.filter { $0.athleteID == athlete.id && $0.retiredAt == nil }
        return VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Shoes")
            if mine.isEmpty {
                Text("Add a pair from Shoes, then tag this run.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(mine, id: \.id) { shoe in
                        let on = run.shoeID == shoe.id
                        Button {
                            run.shoeID = on ? nil : shoe.id
                            save()
                        } label: {
                            HStack {
                                Text(shoe.name)
                                    .font(CMSNTypography.body())
                                    .foregroundStyle(on ? CMSNColor.offBlack : CMSNColor.offWhite)
                                Spacer()
                            }
                            .padding(16)
                            .cmsnChip(isSelected: on)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Shoes \(shoe.name)")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func notes(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Notes")
            TextField("How it felt", text: notesBinding(run), axis: .vertical)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.offWhite)
                .lineLimit(3...6)
                .padding(16)
                .cmsnCard()
        }
    }

    private func photo(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Photo")
            if let data = run.photoJPEG, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
                    .cmsnCard()
                    .accessibilityLabel("Photo attached to this run")
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Text(run.photoJPEG == nil ? "Add photo" : "Replace photo")
                    .font(CMSNTypography.eyebrow())
                    .foregroundStyle(CMSNColor.offWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .cmsnCard()
            .accessibilityHint("Chooses a photo from your library. The camera is not used.")
        }
    }

    private func share(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let shareURL {
                ShareLink(item: shareURL) {
                    Text("Share card")
                        .font(CMSNTypography.eyebrow())
                        .foregroundStyle(CMSNColor.offBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(CMSNColor.white)
                }
                .accessibilityLabel("Share run card")
            } else {
                Button("Share card") { makeShare(run) }
                    .buttonStyle(.cmsnPrimary)
                    .accessibilityLabel("Make a share card")
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(CMSNTypography.body()).foregroundStyle(CMSNColor.offWhite)
            Spacer()
            Text(value).font(CMSNTypography.numeric(16)).foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
        .padding(16)
    }

    private var divider: some View {
        Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1).padding(.leading, 16)
    }

    private func records(for run: Run) -> [PersonalRecordHit] {
        let history = runs.filter { $0.id != run.id && $0.status == .ended && $0.athleteID == athlete.id }.map { $0.summary() }
        return RunMath.records(for: run.summary(), against: history)
    }

    private func recordDetail(_ hit: PersonalRecordHit) -> String {
        if hit.kind == .longest {
            return RunMath.formatDistance(hit.distanceMeters, unit: unit) + " " + unit.label
        }
        let pace = RunMath.formatPace(hit.seconds / (hit.distanceMeters / unit.meters))
        if let previous = hit.previousSeconds {
            return "\(RunMath.formatDuration(hit.seconds)) · was \(RunMath.formatDuration(previous)) · \(pace)\(unit.paceSuffix)"
        }
        return "\(RunMath.formatDuration(hit.seconds)) · \(pace)\(unit.paceSuffix)"
    }

    private func label<Option>(_ option: Option) -> String {
        switch option {
        case let ground as RunGround: return ground.title
        case let effort as RunEffort: return effort.title
        case let mood as RunMood: return mood.title
        default: return ""
        }
    }

    private func celebrateIfNeeded() {
        guard !celebrated, let run, !records(for: run).isEmpty else { return }
        celebrated = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    private func makeShare(_ run: Run) {
        let pace = run.paceSecondsPerMeter.map {
            RunMath.formatPace(RunMath.paceSecondsPerUnit($0, unit: unit)) + unit.paceSuffix
        } ?? "—"
        shareURL = RunShareCardRenderer.render(
            distance: RunMath.formatDistance(run.distanceMeters, unit: unit) + " " + unit.label,
            pace: pace,
            duration: RunMath.formatDuration(run.movingSeconds),
            date: run.startedAt
        )
    }

    private func attach(_ item: PhotosPickerItem, to run: Run) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        run.photoJPEG = Self.jpeg(from: data)
        save()
    }

    private func notesBinding(_ run: Run) -> Binding<String> {
        Binding(
            get: { run.notes },
            set: {
                run.notes = $0
                try? modelContext.save()
            }
        )
    }

    private func save() {
        try? modelContext.save()
    }

    private static func jpeg(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxSide: CGFloat = 1600
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return rendered.jpegData(compressionQuality: 0.72) ?? data
    }
}
