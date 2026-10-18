import SwiftData
import SwiftUI
import UIKit

private enum RunLink: Hashable {
    case live
    case summary(UUID)
    case history
    case shoes
}

struct RunHomeView: View {
    let athlete: Athlete
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Run.startedAt, order: .reverse) private var runs: [Run]

    @State private var path = NavigationPath()
    @State private var preferences = RunPreferenceValues()
    @State private var loaded = false

    private var session: RunSessionController { appState.runSession }
    private var unit: RunDistanceUnit { athlete.unitPreference == .imperial ? .miles : .kilometers }
    private var mine: [Run] { runs.filter { $0.athleteID == athlete.id } }
    private var ended: [Run] { mine.filter { $0.status == .ended } }
    private var active: Run? { mine.first { $0.status == .active } }
    private var healthNotice: Run? {
        mine.first { $0.status == .ended && ($0.healthSyncState == .denied || $0.healthSyncState == .pending || $0.healthSyncState == .unavailable) && $0.healthSyncError != nil }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        if let healthNotice {
                            healthBanner(healthNotice)
                        }
                        if let active, !session.isSessionOpen {
                            resumeCard(active)
                        }
                        Button("Quick Start") { quickStart() }
                            .buttonStyle(.cmsnPrimary)
                            .accessibilityHint("Starts a run with the options below, after the countdown.")
                        options
                        level
                        recent
                        links
                        clubHold
                    }
                    .padding(24)
                }
            }
            .navigationDestination(for: RunLink.self) { link in
                switch link {
                case .live:
                    LiveRunView()
                case .summary(let id):
                    RunSummaryView(runID: id, athlete: athlete)
                case .history:
                    RunHistoryView(athlete: athlete)
                case .shoes:
                    RunShoesView(athlete: athlete)
                }
            }
        }
        .onAppear {
            loadPreferences()
            if session.isSessionOpen, path.isEmpty {
                path.append(RunLink.live)
            }
        }
        .task { await session.retryHealth(in: modelContext) }
        .onChange(of: session.finishedRunID) { _, id in
            guard let id else { return }
            path = NavigationPath()
            path.append(RunLink.summary(id))
        }
        .onChange(of: session.stage) { _, stage in
            if stage == .idle {
                path = NavigationPath()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CMSNWordmark(height: 18)
                Spacer()
                EyebrowLabel(text: "Performance")
            }
            Text("RUN")
                .font(CMSNTypography.displaySmall(44))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 16) {
            EyebrowLabel(text: "This run")
            VStack(alignment: .leading, spacing: 14) {
                optionRow("Where") {
                    picker(RunEnvironment.allCases, preferences.environment) { choice in
                        preferences.environment = choice
                        savePreferences()
                    }
                }
                optionRow("Countdown") {
                    HStack(spacing: 8) {
                        ForEach([3, 6, 9], id: \.self) { seconds in
                            let on = preferences.clampedCountdown == seconds
                            Button("\(seconds)s") {
                                preferences.countdownSeconds = seconds
                                savePreferences()
                            }
                            .font(CMSNTypography.eyebrow())
                            .foregroundStyle(on ? CMSNColor.offBlack : CMSNColor.offWhite)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .cmsnChip(isSelected: on)
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(seconds) second countdown")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                Toggle(isOn: Binding(
                    get: { preferences.autoPauseEnabled },
                    set: { preferences.autoPauseEnabled = $0; savePreferences() }
                )) {
                    Text("Auto-pause")
                        .font(CMSNTypography.body())
                        .foregroundStyle(CMSNColor.offWhite)
                }
                .tint(CMSNColor.offWhite)
                .accessibilityHint("Pauses the clock when you stop and resumes it when you move.")
                Toggle(isOn: Binding(
                    get: { !preferences.cuesSilenced },
                    set: { preferences.cuesSilenced = !$0; savePreferences() }
                )) {
                    Text("Audio cues")
                        .font(CMSNTypography.body())
                        .foregroundStyle(CMSNColor.offWhite)
                }
                .tint(CMSNColor.offWhite)
                .accessibilityHint("Speaks distance and pace. Turn off to keep the run silent.")
                if !preferences.cuesSilenced {
                    picker(CueFrequency.allCases.filter { $0 != .off }, preferences.cueFrequency) { choice in
                        preferences.cueFrequency = choice
                        savePreferences()
                    }
                }
                Toggle(isOn: Binding(
                    get: { preferences.heartRateStrapEnabled },
                    set: { preferences.heartRateStrapEnabled = $0; savePreferences() }
                )) {
                    Text("Heart-rate strap")
                        .font(CMSNTypography.body())
                        .foregroundStyle(CMSNColor.offWhite)
                }
                .tint(CMSNColor.offWhite)
                .accessibilityHint("Looks for a strap only during a run. Off leaves Bluetooth alone.")
            }
            .padding(16)
            .cmsnCard()
        }
    }

    private var level: some View {
        let meters = ended.reduce(0) { $0 + $1.distanceMeters }
        let current = RunLevel.current(lifetimeMeters: meters)
        let streak = RunMath.weeklyStreak(runDates: ended.map(\.startedAt), now: Date(), calendar: .current)
        return VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Level")
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: current.toneHex))
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(current.name)
                        .font(CMSNTypography.body())
                        .foregroundStyle(CMSNColor.offWhite)
                    Text(streak == 0 ? "No weekly streak" : "\(streak)-week streak")
                        .font(CMSNTypography.caption())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                Spacer()
                Text(RunMath.formatDistance(meters, unit: unit, places: 0) + " " + unit.label)
                    .font(CMSNTypography.numeric(16))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            .padding(16)
            .cmsnCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(current.name). \(streak == 0 ? "No weekly streak" : "\(streak) week streak").")
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Recent")
            if ended.isEmpty {
                Text("Your finished runs will list here.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(ended.prefix(3), id: \.id) { run in
                        Button {
                            path.append(RunLink.summary(run.id))
                        } label: {
                            HStack {
                                Text(RunMath.formatDistance(run.distanceMeters, unit: unit) + " " + unit.label)
                                    .font(CMSNTypography.body())
                                    .foregroundStyle(CMSNColor.offWhite)
                                Spacer()
                                Text(run.startedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(CMSNTypography.caption())
                                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                            }
                            .padding(16)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this run.")
                    }
                }
                .cmsnCard()
            }
        }
    }

    private var links: some View {
        VStack(spacing: 0) {
            NavigationLink(value: RunLink.history) {
                linkRow("History")
            }
            .buttonStyle(.plain)
            Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1).padding(.leading, 16)
            NavigationLink(value: RunLink.shoes) {
                linkRow("Shoes")
            }
            .buttonStyle(.plain)
        }
        .cmsnCard()
    }

    /// Reserved Phase 2 slot. Text only — not a button, and it does not navigate.
    private var clubHold: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowLabel(text: "Run Club")
            Text("Not in this release.")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cmsnCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Run Club. Not in this release.")
    }

    private func healthBanner(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Apple Health")
            Text(run.healthSyncError ?? "A run is waiting to sync.")
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)
            if run.healthSyncState == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.cmsnGhost)
                .accessibilityHint("Opens iOS Settings so you can allow Apple Health again.")
            } else {
                Button("Try again") {
                    Task { await session.retryHealth(in: modelContext) }
                }
                .buttonStyle(.cmsnGhost)
            }
        }
        .padding(16)
        .cmsnCard()
    }

    private func resumeCard(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Still open")
            Text("A run was interrupted. Resume keeps the distance already recorded.")
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.offWhite)
            Button("Resume") {
                session.preferences = preferences
                session.resume(run: run, context: modelContext, weightKG: athlete.weightKG, heightCM: athlete.heightCM)
                path.append(RunLink.live)
            }
            .buttonStyle(.cmsnPrimary)
            Button("Discard") { session.discard(run: run, context: modelContext) }
                .buttonStyle(.cmsnText)
                .accessibilityHint("Marks the interrupted run as discarded. It is not saved as a finished run.")
        }
        .padding(16)
        .cmsnCard()
    }

    private func optionRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CMSNTypography.caption())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            content()
        }
    }

    private func picker<Option: Identifiable & Hashable>(
        _ options: [Option],
        _ selected: Option,
        choose: @escaping (Option) -> Void
    ) -> some View where Option.ID: Equatable {
        HStack(spacing: 8) {
            ForEach(options, id: \.id) { option in
                let on = option.id == selected.id
                Button(title(option)) { choose(option) }
                    .font(CMSNTypography.eyebrow())
                    .foregroundStyle(on ? CMSNColor.offBlack : CMSNColor.offWhite)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .cmsnChip(isSelected: on)
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func title<Option>(_ option: Option) -> String {
        switch option {
        case let environment as RunEnvironment: return environment.title
        case let cue as CueFrequency: return cue == .everyFiveMinutes ? "5 min" : (cue == .everyMile ? "Mile" : "Km")
        default: return ""
        }
    }

    private func linkRow(_ title: String) -> some View {
        HStack {
            Text(title).font(CMSNTypography.body()).foregroundStyle(CMSNColor.offWhite)
            Spacer()
            Text("›").font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
        .padding(16)
    }

    private func quickStart() {
        guard !session.isSessionOpen else {
            if path.isEmpty { path.append(RunLink.live) }
            return
        }
        preferences.distanceUnit = unit
        savePreferences()
        session.preferences = preferences
        session.start(context: modelContext, athleteID: athlete.id, weightKG: athlete.weightKG, heightCM: athlete.heightCM)
        path.append(RunLink.live)
    }

    private func loadPreferences() {
        guard !loaded else { return }
        loaded = true
        let athleteID = athlete.id
        var descriptor = FetchDescriptor<RunSettings>(predicate: #Predicate { $0.athleteID == athleteID })
        descriptor.fetchLimit = 1
        if let settings = try? modelContext.fetch(descriptor).first {
            preferences = settings.values(unit: unit)
        } else {
            preferences = RunPreferenceValues.fresh(unit: unit)
            modelContext.insert(RunSettings(athleteID: athlete.id, values: preferences))
            try? modelContext.save()
        }
        session.preferences = preferences
    }

    private func savePreferences() {
        preferences.distanceUnit = unit
        let athleteID = athlete.id
        var descriptor = FetchDescriptor<RunSettings>(predicate: #Predicate { $0.athleteID == athleteID })
        descriptor.fetchLimit = 1
        if let settings = try? modelContext.fetch(descriptor).first {
            settings.apply(preferences)
        } else {
            modelContext.insert(RunSettings(athleteID: athlete.id, values: preferences))
        }
        try? modelContext.save()
        session.preferences = preferences
    }
}