import Foundation

/// The CMSN Score's per-dimension weighting. Recovery/rest is weighted
/// *above* raw output by design — these are named constants specifically so
/// they're the first thing tuned once real user data exists; the product
/// doc flags them as a testable hypothesis, not a final answer.
enum ScoreWeights {
    static let work = 0.25
    static let consistency = 0.25
    static let progress = 0.20
    static let disciplineAndRecovery = 0.30

    static var sum: Double { work + consistency + progress + disciplineAndRecovery }
}

/// Raw, pre-weight point values for each scoring action. Deliberately plain
/// whole numbers, not tuned/mystical — easy to reason about and to retune.
enum ScorePoints {
    static let perAttemptedSet = 2.0
    static let bonusForHittingPlannedRange = 1.0
    static let sessionCompletionBonus = 10.0
    static let partialSessionBonus = 5.0 // half of completion — never zero, never penalized
    static let estimatedOneRepMaxPR = 15.0
    static let onScheduleConsistencyBonus = 8.0
    static let restDayAdherenceBonus = 8.0
    static let proteinTargetHitBonus = 5.0
    static let returnAfter7Days = 10.0
    static let returnAfter14Days = 16.0
    static let returnAfter21PlusDays = 22.0
}

struct ScoreBreakdown: Equatable {
    var work: Double
    var consistency: Double
    var progress: Double
    var discipline: Double
    var total: Double
}

/// Turns logged activity into `ScoreEvent`s, and turns a set of
/// `ScoreEvent`s into a weighted composite. Every rule here traces directly
/// to a product-doctrine line: "every completed effort counts," "recovery
/// is part of performance," "returning after a break earns recognition."
enum ScoreCalculator {
    // MARK: - Event generation

    /// Scores one workout session. Partial sessions are scored honestly and
    /// positively — a session with zero completed exercises but some
    /// attempted sets still earns `partialSessionBonus`, never zero.
    static func events(forSession session: WorkoutSession, previousBestE1RMByExercise: [String: Double] = [:]) -> [ScoreEvent] {
        var events: [ScoreEvent] = []
        var bestSeenThisSession: [String: Double] = [:]

        for exercise in session.loggedExercises {
            for set in exercise.loggedSets where set.isAttempted {
                events.append(ScoreEvent(
                    dimension: .work,
                    points: ScorePoints.perAttemptedSet,
                    reason: "Logged a set on \(exercise.exerciseNameSnapshot)",
                    relatedSessionID: session.id
                ))

                if set.isWithinPlannedRange {
                    events.append(ScoreEvent(
                        dimension: .work,
                        points: ScorePoints.bonusForHittingPlannedRange,
                        reason: "Hit the target range on \(exercise.exerciseNameSnapshot)",
                        relatedSessionID: session.id
                    ))
                }

                if let reps = set.completedReps, let weight = set.completedWeightKG, reps > 0, weight > 0 {
                    let e1rm = OneRepMaxEstimator.epley(weight: weight, reps: reps)
                    let previousBest = previousBestE1RMByExercise[exercise.exerciseID] ?? 0
                    let bestSoFarThisSession = bestSeenThisSession[exercise.exerciseID] ?? 0
                    if e1rm > previousBest && e1rm > bestSoFarThisSession {
                        bestSeenThisSession[exercise.exerciseID] = e1rm
                        events.append(ScoreEvent(
                            dimension: .progress,
                            points: ScorePoints.estimatedOneRepMaxPR,
                            reason: "New estimated 1RM on \(exercise.exerciseNameSnapshot)",
                            relatedSessionID: session.id
                        ))
                    }
                }
            }
        }

        if session.isComplete {
            events.append(ScoreEvent(dimension: .work, points: ScorePoints.sessionCompletionBonus, reason: "Completed today's session", relatedSessionID: session.id))
        } else if session.hasAnyLoggedWork {
            events.append(ScoreEvent(dimension: .work, points: ScorePoints.partialSessionBonus, reason: "Logged partial work — it still counts", relatedSessionID: session.id))
        }

        return events
    }

    /// Awarded when a session happens on (or reasonably near) the athlete's
    /// planned cadence — the Consistency dimension is about *returning*, not
    /// about volume, which already lives under Work.
    static func eventsForOnScheduleConsistency(sessionID: UUID) -> [ScoreEvent] {
        [ScoreEvent(dimension: .consistency, points: ScorePoints.onScheduleConsistencyBonus, reason: "Trained on schedule", relatedSessionID: sessionID)]
    }

    /// A completed rest/recovery day earns Discipline credit — this is the
    /// mechanism that stops the app from teaching "constant exertion =
    /// discipline."
    static func eventsForRestDayAdherence(date: Date = Date()) -> [ScoreEvent] {
        [ScoreEvent(date: date, dimension: .discipline, points: ScorePoints.restDayAdherenceBonus, reason: "Rest day honored")]
    }

    static func eventsForProteinTargetHit(log: NutritionLog) -> [ScoreEvent] {
        guard log.hasHitProteinTarget else { return [] }
        return [ScoreEvent(date: log.date, dimension: .discipline, points: ScorePoints.proteinTargetHitBonus, reason: "Hit daily protein target")]
    }

    /// Returning after an inactive stretch is scored *positively*, scaled by
    /// how long the break was — the longer the gap, the more the return
    /// itself is worth recognizing, per the Return-loop doctrine ("you do
    /// not have to restart").
    static func eventsForReturnAfterInactivity(daysInactive: Int, sessionID: UUID? = nil) -> [ScoreEvent] {
        guard daysInactive >= 7 else { return [] }
        let points: Double
        switch daysInactive {
        case 7..<14: points = ScorePoints.returnAfter7Days
        case 14..<21: points = ScorePoints.returnAfter14Days
        default: points = ScorePoints.returnAfter21PlusDays
        }
        return [ScoreEvent(
            dimension: .consistency,
            points: points,
            reason: "Returned after \(daysInactive) days away — no restart needed",
            relatedSessionID: sessionID
        )]
    }

    // MARK: - Composite score

    /// Sums raw points per dimension, then combines them using
    /// `ScoreWeights` — the weights are what make discipline/recovery worth
    /// more per point than an equal amount of raw work, by design.
    static func compositeScore(from events: [ScoreEvent]) -> ScoreBreakdown {
        var rawByDimension: [ScoreDimension: Double] = [:]
        for event in events {
            rawByDimension[event.dimension, default: 0] += event.points
        }

        let work = rawByDimension[.work] ?? 0
        let consistency = rawByDimension[.consistency] ?? 0
        let progress = rawByDimension[.progress] ?? 0
        let discipline = rawByDimension[.discipline] ?? 0

        let total = work * ScoreWeights.work
            + consistency * ScoreWeights.consistency
            + progress * ScoreWeights.progress
            + discipline * ScoreWeights.disciplineAndRecovery

        return ScoreBreakdown(work: work, consistency: consistency, progress: progress, discipline: discipline, total: total)
    }
}
