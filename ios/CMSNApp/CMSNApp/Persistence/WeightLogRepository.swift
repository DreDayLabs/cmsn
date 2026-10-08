import Foundation
import SwiftData

/// Seeds body-weight history from the single `Athlete.weightKG` that
/// shipped before weight was a log. Idempotent: a second call does not
/// add rows, and deleting every entry later does not bring the seed back.
enum WeightHistorySeeder {
    /// Inserts one sample per athlete who has a positive `weightKG` and
    /// no history yet, then records that seeding has happened. Safe to
    /// call from the V2→V3 migration and again at launch.
    static func seedIfUnmarked(in context: ModelContext) throws {
        let markers = try context.fetch(FetchDescriptor<WeightHistorySeedMarker>())
        guard markers.isEmpty else { return }
        try seedMissingEntries(in: context)
        context.insert(WeightHistorySeedMarker())
        try context.save()
    }

    /// One starting sample per athlete with a real weight and zero
    /// entries. Does not save and does not write the seed marker — the
    /// caller decides when the seed is finished.
    static func seedMissingEntries(in context: ModelContext) throws {
        let athletes = try context.fetch(FetchDescriptor<Athlete>())
        let existing = try context.fetch(FetchDescriptor<WeightEntry>())
        let athletesWithHistory = Set(existing.map(\.athleteID))
        for athlete in athletes {
            guard athlete.weightKG > 0, !athletesWithHistory.contains(athlete.id) else { continue }
            let recordedAt = athlete.onboardingCompletedAt ?? athlete.createdAt
            let entry = WeightEntry(
                athleteID: athlete.id,
                recordedAt: recordedAt,
                createdAt: recordedAt,
                weightKG: athlete.weightKG
            )
            context.insert(entry)
        }
    }
}

/// Reads and writes `WeightEntry` rows and keeps `Athlete.weightKG` equal
/// to the chronologically latest sample.
@MainActor
struct WeightLogRepository {
    let context: ModelContext

    func entries(for athleteID: UUID) -> [WeightEntry] {
        // Filter in memory. A person's weigh-ins are a short list, and a
        // `#Predicate` on `UUID` has been unreliable across iOS 17 point
        // releases. The cross-athlete test covers the filter.
        let descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.recordedAt, order: .forward)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.athleteID == athleteID }
    }

    /// Latest sample by when it was weighed, then by when it was written,
    /// then by id so the choice is stable when two rows share a timestamp.
    static func latest(in entries: [WeightEntry]) -> WeightEntry? {
        entries.max { lhs, rhs in
            if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt < rhs.recordedAt }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Sets `athlete.weightKG` from `entries`. Pass the list explicitly so
    /// a row that was just inserted or deleted is included even if a fetch
    /// has not caught up yet. An empty list leaves the profile weight
    /// alone — macro targets still need a body weight.
    func syncProfileWeight(for athlete: Athlete, entries: [WeightEntry]) {
        guard let latest = Self.latest(in: entries) else { return }
        athlete.weightKG = latest.weightKG
    }

    @discardableResult
    func addEntry(weightKG: Double, recordedAt: Date = Date(), athlete: Athlete) -> WeightEntry? {
        guard weightKG.isFinite, weightKG > 0 else { return nil }
        let entry = WeightEntry(athleteID: athlete.id, recordedAt: recordedAt, weightKG: weightKG)
        context.insert(entry)
        var history = entries(for: athlete.id)
        if !history.contains(where: { $0.id == entry.id }) {
            history.append(entry)
        }
        syncProfileWeight(for: athlete, entries: history)
        try? context.save()
        return entry
    }

    func delete(_ entry: WeightEntry, athlete: Athlete) {
        let remaining = entries(for: athlete.id).filter { $0.id != entry.id }
        context.delete(entry)
        syncProfileWeight(for: athlete, entries: remaining)
        try? context.save()
    }

    /// First sample for a profile that does not have one yet. If history
    /// already exists and the profile weight was just edited (onboarding
    /// resume), log that edit so the chart and the macros still agree.
    func recordInitialWeightIfNeeded(for athlete: Athlete) {
        guard athlete.weightKG > 0 else { return }
        let history = entries(for: athlete.id)
        if history.isEmpty {
            let recordedAt = athlete.onboardingCompletedAt ?? athlete.createdAt
            _ = addEntry(weightKG: athlete.weightKG, recordedAt: recordedAt, athlete: athlete)
            return
        }
        if let latest = Self.latest(in: history), abs(latest.weightKG - athlete.weightKG) > 0.05 {
            _ = addEntry(weightKG: athlete.weightKG, recordedAt: Date(), athlete: athlete)
        }
    }
}
