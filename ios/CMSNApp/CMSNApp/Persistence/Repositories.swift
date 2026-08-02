import Foundation
import SwiftData

/// V0 assumes exactly one local athlete (no accounts, no backend — see plan).
/// This repository is the single place that assumption lives, so V2's auth
/// work replaces one file instead of every call site that fetches "the
/// current athlete."
@MainActor
struct AthleteRepository {
    let context: ModelContext

    /// Fetches the one on-device athlete profile, if onboarding has run.
    func currentAthlete() -> Athlete? {
        var descriptor = FetchDescriptor<Athlete>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    func createAthlete(_ athlete: Athlete) -> Athlete {
        context.insert(athlete)
        try? context.save()
        return athlete
    }

    func save() {
        try? context.save()
    }
}

@MainActor
struct WorkoutRepository {
    let context: ModelContext

    func recentSessions(limit: Int = 50) -> [WorkoutSession] {
        var descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The most recent *completed* session for a given focus — what the
    /// suggestion engine and Today screen use to answer "last time this
    /// split was trained."
    func mostRecentCompletedSession(focus: SplitFocus) -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.splitFocus == focus && $0.endedAt != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        var limited = descriptor
        limited.fetchLimit = 1
        return (try? context.fetch(limited))?.first
    }

    /// Every logged set for a given exercise across history, most recent
    /// first — the input to e1RM/progressive-overload suggestions.
    func loggedSets(forExerciseID exerciseID: String, limit: Int = 20) -> [LoggedSet] {
        let sessions = recentSessions(limit: 200)
        let sets = sessions
            .flatMap(\.loggedExercises)
            .filter { $0.exerciseID == exerciseID }
            .sorted { $0.session?.date ?? .distantPast > $1.session?.date ?? .distantPast }
            .flatMap(\.loggedSets)
            .filter { $0.isAttempted }
            .sorted { $0.loggedAt > $1.loggedAt }
        return Array(sets.prefix(limit))
    }

    /// Days since the last session with any logged work — the input to the
    /// Return-state framing (7+/14+/21+ day thresholds).
    func daysSinceLastLoggedWork(referenceDate: Date = Date()) -> Int? {
        let sessions = recentSessions(limit: 1)
        guard let last = sessions.first(where: { $0.hasAnyLoggedWork }) ?? recentSessions(limit: 200).first(where: { $0.hasAnyLoggedWork }) else {
            return nil
        }
        let days = Calendar.current.dateComponents([.day], from: last.date, to: referenceDate).day ?? 0
        return max(0, days)
    }

    @discardableResult
    func createSession(_ session: WorkoutSession) -> WorkoutSession {
        context.insert(session)
        try? context.save()
        return session
    }

    /// Called on every set entry — the "save immediately, never batch to
    /// session end" reliability requirement.
    func saveImmediately() {
        try? context.save()
    }
}

@MainActor
struct NutritionRepository {
    let context: ModelContext

    func log(for date: Date) -> NutritionLog? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let descriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func createOrFetchToday(proteinTarget: Double, carbTarget: Double?, fatTarget: Double?, calorieEstimate: Double?) -> NutritionLog {
        if let existing = log(for: Date()) { return existing }
        let newLog = NutritionLog(
            proteinGramsTarget: proteinTarget,
            carbGramsTarget: carbTarget,
            fatGramsTarget: fatTarget,
            calorieEstimate: calorieEstimate
        )
        context.insert(newLog)
        try? context.save()
        return newLog
    }

    func addEntry(_ entry: NutritionEntry, to log: NutritionLog) {
        entry.log = log
        log.entries.append(entry)
        context.insert(entry)
        try? context.save()
    }
}

@MainActor
struct ScoreRepository {
    let context: ModelContext

    func allEvents(since date: Date? = nil) -> [ScoreEvent] {
        if let date {
            let descriptor = FetchDescriptor<ScoreEvent>(
                predicate: #Predicate { $0.date >= date },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            return (try? context.fetch(descriptor)) ?? []
        }
        let descriptor = FetchDescriptor<ScoreEvent>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func record(_ events: [ScoreEvent]) {
        events.forEach { context.insert($0) }
        try? context.save()
    }
}
