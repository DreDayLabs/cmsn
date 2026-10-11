import SwiftData
import SwiftUI

/// Home. Training and fuel in one glance: today's planned or finished
/// session, the adjusted targets and what's left, the reason those targets
/// moved, and one next action. The readiness check, the quick paths, and
/// the handoff into `WorkoutSessionView` stay in place.
struct TodayView: View {
    let athlete: Athlete
    @Environment(AppState.self) private var appState

    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    @Query(sort: \NutritionLog.date, order: .reverse) private var nutritionLogs: [NutritionLog]

    @State private var resolvedDay: ResolvedProgramDay?
    @State private var readinessDraft = ReadinessDraft()
    @State private var daysInactive: Int?
    @State private var pendingDay: ResolvedProgramDay?
    @State private var pendingReadiness: ReadinessCheck?
    @State private var navigateToSession = false
    @State private var calendarAuthorizationChecked = false
    @State private var showingRecoveryLog = false

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollViewReader { proxy in
                    ScrollView {
                        screen(proxy: proxy)
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToSession) {
                if let pendingDay, let pendingReadiness {
                    WorkoutSessionView(resolvedDay: pendingDay, readiness: pendingReadiness, athlete: athlete, daysInactiveAtStart: daysInactive)
                }
            }
            .sheet(isPresented: $showingRecoveryLog) {
                RecoveryLogView()
            }
            .onAppear { resolveToday() }
            .task(id: targetSyncID) {
                await primeCalendarIfNeeded()
                resolveToday()
                daysInactive = appState.workoutRepository.daysSinceLastLoggedWork()
                syncTargets()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func screen(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            CMSNScreenHeader(title: "Today", trailing: dateLabel)
                .accessibilityIdentifier("today.screen")

            if let daysInactive, daysInactive >= 7 {
                ReturnStateView(daysInactive: daysInactive)
            }

            if let state = homeState {
                sessionHero(state, proxy: proxy)
                QuickPathActionBar { action in
                    startQuickPath(action)
                }
                sessionCard(state)
                fuelCard(state)
                TrainingDayWhyCard(adjustment: state.adjustment)
                    .id(state.articleID)

                if state.showsReadinessCheck {
                    ReadinessCheckView(draft: $readinessDraft, showsSubmitButton: false) {
                        beginSession()
                    }
                }

                if state.showsRecoveryLog {
                    Button("Log recovery day") { showingRecoveryLog = true }
                        .buttonStyle(.cmsnGhost)
                }
            }
        }
        .padding(20)
    }

    private var dateLabel: String {
        Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func sessionHero(_ state: TodayHomeState, proxy: ScrollViewProxy) -> some View {
        CMSNVideoHero(height: 390, badge: "Background video") {
            VStack(alignment: .leading, spacing: 8) {
                Text(heroStatus(state))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text(state.headline)
                    .font(CMSNTypography.display(104))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.4)
                Text(heroStats(state))
                    .font(.system(size: 15))
                    .foregroundStyle(CMSNColor.white.opacity(0.92))
                Button {
                    perform(state.primaryAction, proxy: proxy, articleID: state.articleID)
                } label: {
                    HStack(spacing: 8) {
                        if state.primaryAction == .startWorkout {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text(visibleActionTitle(state))
                    }
                }
                .buttonStyle(.cmsnPrimary)
                .accessibilityIdentifier("today.primaryAction")
                .accessibilityLabel(state.primaryAction.title)
                .padding(.top, 6)
            }
        }
    }

    private func heroStatus(_ state: TodayHomeState) -> String {
        switch state.session {
        case .planned: return "Planned"
        case .inProgress: return "In progress"
        case .finished: return "Finished"
        case .rest: return "Rest day"
        case .noProgram: return "Program"
        }
    }

    private func heroStats(_ state: TodayHomeState) -> String {
        switch state.session {
        case .planned(let plan):
            let exercises = plan.exerciseNames.count
            let sets = resolvedDay?.resolvedExercises.reduce(0) { $0 + $1.plannedExercise.plannedSets.count } ?? 0
            return "\(countPhrase(exercises, singular: "exercise", plural: "exercises")) · \(sets) sets · 0 logged"
        case .inProgress(let work):
            let exercises = work.exerciseNames.count
            return "\(countPhrase(exercises, singular: "exercise", plural: "exercises")) · \(work.plannedSets) sets · \(work.attemptedSets) logged"
        case .finished(let works):
            let attempted = works.reduce(0) { $0 + $1.attemptedSets }
            let planned = works.reduce(0) { $0 + $1.plannedSets }
            return "\(attempted) of \(planned) sets logged"
        case .rest:
            return "Nothing is planned"
        case .noProgram:
            return "No rotation is set"
        }
    }

    private func visibleActionTitle(_ state: TodayHomeState) -> String {
        switch state.primaryAction {
        case .startWorkout:
            if case .inProgress = state.session { return "Resume session" }
            return "Start workout"
        case .logFood:
            return "Log food"
        case .readWhy:
            return "Read why"
        }
    }

    private func countPhrase(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }

    private func sessionCard(_ state: TodayHomeState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.sessionEyebrow)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            Text(state.sessionTitle)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text(state.sessionDetail)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(state.sessionLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
            }
            ForEach(Array(state.sessionNotes.enumerated()), id: \.offset) { _, note in
                Text(note)
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cmsnCard()
    }

    private func fuelCard(_ state: TodayHomeState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.fuelEyebrow)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            Text(state.fuelFigure)
                .font(CMSNTypography.display(56))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text(state.fuelCaption)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text(state.fuelDetail)
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(state.fuelNote)
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cmsnCard()
    }

    private var homeState: TodayHomeState? {
        let hasProgram = !appState.activeProgram.days.isEmpty
        let logged = TodayHomeState.loggedWork(on: Date(), from: workoutSessions)
        if resolvedDay == nil && hasProgram && logged.isEmpty { return nil }
        return TodayHomeState.resolve(
            hasProgram: hasProgram,
            plan: resolvedDay.map { TodayPlannedSession($0) },
            logged: logged,
            adjustment: adjustment,
            remaining: remaining
        )
    }

    private var adjustment: TrainingDayAdjustment {
        TrainingDayAdjustment.adjust(athlete: athlete, sessions: workoutSessions)
    }

    private var remaining: RemainingMacros {
        RemainingMacros.calculate(targets: adjustment.adjusted, entries: todaysFood)
    }

    private var todaysFood: [LoggedFoodContribution] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return nutritionLogs
            .filter { $0.date >= start && $0.date < end }
            .flatMap(\.entries)
            .map { LoggedFoodContribution(proteinGrams: $0.proteinGrams, calories: $0.calories) }
    }

    private var targetSyncID: String {
        let targets = adjustment.adjusted
        return "\(targets.proteinGrams)-\(targets.carbGrams)-\(targets.fatGrams)-\(targets.calorieEstimate)"
    }

    private func primeCalendarIfNeeded() async {
        guard !calendarAuthorizationChecked else { return }
        calendarAuthorizationChecked = true
        if appState.calendarService.authorizationState == .notDetermined {
            _ = await appState.calendarService.requestAccess()
        }
    }

    private func resolveToday() {
        let resolver = ProgramResolver(calendarService: appState.calendarService)
        let program = appState.activeProgram
        let lastIndex = lastCompletedDayIndex(program: program)
        resolvedDay = resolver.resolveToday(program: program, athlete: athlete, lastCompletedDayIndex: lastIndex)
    }

    private func lastCompletedDayIndex(program: TrainingProgram) -> Int? {
        guard let lastSession = appState.workoutRepository.recentSessions(limit: 20).first(where: { $0.isComplete }) else { return nil }
        return program.days.firstIndex { $0.focus == lastSession.splitFocus }
    }

    private func beginSession() {
        guard let resolvedDay else { return }
        pendingDay = resolvedDay
        pendingReadiness = readinessDraft.makeReadinessCheck()
        navigateToSession = true
    }

    private func startQuickPath(_ action: QuickPathAction) {
        let resolver = ProgramResolver(calendarService: appState.calendarService)
        let focus = resolvedDay?.focus ?? .fullBody
        pendingDay = action.resolve(currentFocus: focus, resolver: resolver, athlete: athlete)
        pendingReadiness = readinessDraft.makeReadinessCheck()
        navigateToSession = true
    }

    private func perform(_ action: TodayHomeState.PrimaryAction, proxy: ScrollViewProxy, articleID: String) {
        switch action {
        case .startWorkout:
            beginSession()
        case .logFood:
            appState.selectedTab = .nutrition
        case .readWhy:
            proxy.scrollTo(articleID, anchor: .top)
        }
    }

    private func syncTargets() {
        let targets = adjustment.adjusted
        _ = appState.nutritionRepository.createOrFetchToday(
            proteinTarget: targets.proteinGrams,
            carbTarget: targets.carbGrams,
            fatTarget: targets.fatGrams,
            calorieEstimate: targets.calorieEstimate
        )
    }
}
