import SwiftUI

/// The "walks in the gym, opens the app" screen — Prepare. Resolves today's
/// session (rotation, calendar override, equipment, injuries), surfaces the
/// Return-state framing when relevant, and hosts both the full readiness
/// check and the minimum-user quick-path row before handing off to
/// `WorkoutSessionView`.
struct TodayView: View {
    let athlete: Athlete
    @Environment(AppState.self) private var appState

    @State private var resolvedDay: ResolvedProgramDay?
    @State private var readinessDraft = ReadinessDraft()
    @State private var daysInactive: Int?
    @State private var showingReadinessCheck = false
    @State private var pendingDay: ResolvedProgramDay?
    @State private var pendingReadiness: ReadinessCheck?
    @State private var navigateToSession = false
    @State private var calendarAuthorizationChecked = false
    @State private var showingRecoveryLog = false

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        if let daysInactive, daysInactive >= 7 {
                            ReturnStateView(daysInactive: daysInactive)
                        }

                        QuickPathActionBar { action in
                            startQuickPath(action)
                        }

                        if let resolvedDay {
                            focusCard(for: resolvedDay)
                            if resolvedDay.focus == .restDay || resolvedDay.focus == .recovery {
                                Button("Log Recovery Day") { showingRecoveryLog = true }
                                    .buttonStyle(.cmsnGhost)
                            }
                        }

                        if showingReadinessCheck {
                            ReadinessCheckView(draft: $readinessDraft) {
                                beginSession()
                            }
                        }
                    }
                    .padding(24)
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
            .task {
                await primeCalendarIfNeeded()
                resolveToday()
                daysInactive = appState.workoutRepository.daysSinceLastLoggedWork()
                showingReadinessCheck = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CMSNWordmark(height: 16)
                Spacer()
                EyebrowLabel(text: Date().formatted(.dateTime.weekday(.wide)))
            }
            Text(resolvedDay?.focus.displayName ?? "Today")
                .font(CMSNTypography.displaySmall(40))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }

    private func focusCard(for day: ResolvedProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if day.isCalendarOverride {
                EyebrowLabel(text: "From Your Calendar")
            }
            Text("\(day.resolvedExercises.count) exercises · about \(day.estimatedMinutes) min")
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)

            ForEach(day.adjustmentNotes, id: \.self) { note in
                Text(note)
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }

            ForEach(day.resolvedExercises) { resolved in
                Text("· \(resolved.exercise.name)")
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
            }
        }
        .padding(20)
        .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
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
}
