import Foundation

/// One exercise inside a session, reduced to the fields the energy estimate uses.
struct TrainingExerciseRecord: Equatable {
    var exerciseID: String
    var name: String
    var sets: [TrainingSetRecord]
}

struct TrainingSetRecord: Equatable {
    var setType: SetType
    var plannedRepRangeLow: Int
    var plannedRepRangeHigh: Int
    var isAttempted: Bool
    var completedWeightKG: Double?
    var plannedWeightKG: Double?
}

/// A finished or logged session. Duration is the clock from `startedAt` to
/// `endedAt`. There is no separate duration field on `WorkoutSession`.
struct TrainingSessionRecord: Equatable {
    var startedAt: Date
    var endedAt: Date?
    var splitFocus: SplitFocus
    var exercises: [TrainingExerciseRecord]
}

extension TrainingSessionRecord {
    init(_ session: WorkoutSession) {
        startedAt = session.date
        endedAt = session.endedAt
        splitFocus = session.splitFocus
        exercises = session.loggedExercises.map { exercise in
            TrainingExerciseRecord(
                exerciseID: exercise.exerciseID,
                name: exercise.exerciseNameSnapshot,
                sets: exercise.loggedSets.map { set in
                    TrainingSetRecord(
                        setType: set.setType,
                        plannedRepRangeLow: set.plannedRepRangeLow,
                        plannedRepRangeHigh: set.plannedRepRangeHigh,
                        isAttempted: set.isAttempted,
                        completedWeightKG: set.completedWeightKG,
                        plannedWeightKG: set.plannedWeightKG
                    )
                }
            )
        }
    }
}

/// ACSM 2016 carbohydrate bands (Thomas, Erdman & Burke, MSSE 2016).
/// The hour cutoffs apply the examples named in that table:
/// light/skill below the "~1 h/d" moderate example, moderate from 1 h up to
/// 2 h so a typical gym hour stays on the ~1 h example, high from 2 h through
/// 3 h (inside the 1–3 h/d example), and very high only past 3 h.
enum TrainingCarbLoad: Equatable {
    case none
    case light
    case moderate
    case high
    case veryHigh

    /// g/kg/d. `none` means no training-load clamp (rest, or no cited session).
    var gramsPerKilogram: ClosedRange<Double>? {
        switch self {
        case .none: return nil
        case .light: return 3...5
        case .moderate: return 5...7
        case .high: return 6...10
        case .veryHigh: return 8...12
        }
    }

    var name: String {
        switch self {
        case .none: return "rest"
        case .light: return "light"
        case .moderate: return "moderate"
        case .high: return "high"
        case .veryHigh: return "very high"
        }
    }
}

struct TrainingCitation: Equatable, Identifiable {
    var id: String
    var label: String
    var url: URL
}

/// Today's targets after the training that was actually logged, plus the
/// plain-language reason.
///
/// Double counting: `MacroTargetCalculator`'s 1.375 / 1.55 / 1.725 bands
/// already fold a week of training into every day, and they are uncited.
/// This type does not start from those bands. It starts from the
/// non-exercise baseline (Mifflin–St Jeor × PLACEHOLDER 1.2) and adds
/// session energy on top. Rest days therefore stay on that baseline.
///
/// Session energy is NET METs × kg × hours. NET METs are MET − 1 so the
/// resting energy already inside the Mifflin–St Jeor baseline is not
/// counted twice. MET values are the 2024 Adult Compendium codes listed
/// in the approved sources for this change. Anything else is a PLACEHOLDER
/// of 0 kcal, not a guessed burn.
struct TrainingDayAdjustment: Equatable {
    /// Education-library slug. A later library can deep-link to this.
    /// This change does not build that library.
    static let articleID = "fuel-after-training"

    /// PLACEHOLDER. `WorkoutSession` has no duration when `endedAt` is missing.
    /// TODO: read a logged duration once the model stores one. Until then
    /// a missing clock adds no energy.
    static let missingDurationHoursPlaceholder: Double = 0

    var baseline: MacroTargets
    var adjusted: MacroTargets
    var extraKcal: Double
    var trainingMinutes: Int
    var sessionCount: Int
    var appliedCodes: [String]
    var carbLoad: TrainingCarbLoad
    var carbClampedToFloor: Bool
    var carbClampedToCeiling: Bool
    var durationMissing: Bool
    var activityUncited: Bool
    var targetsChanged: Bool
    var explanationSentences: [String]
    var citations: [TrainingCitation]

    var articleID: String { Self.articleID }

    var explanation: String {
        let body = explanationSentences.joined(separator: ". ")
        return body.hasSuffix(".") ? body : body + "."
    }

    static func carbLoad(trainingHours: Double) -> TrainingCarbLoad {
        if trainingHours <= 0 { return .none }
        if trainingHours < 1 { return .light }
        if trainingHours < 2 { return .moderate }
        if trainingHours <= 3 { return .high }
        return .veryHigh
    }

    /// Sessions whose start or finish falls on `day`, and that were either
    /// ended or had at least one attempted set.
    static func sessions(
        on day: Date,
        from sessions: [WorkoutSession],
        alsoIncluding extra: WorkoutSession? = nil,
        calendar: Calendar = .current
    ) -> [WorkoutSession] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        var byID: [UUID: WorkoutSession] = [:]
        for session in sessions + (extra.map { [$0] } ?? []) {
            let anchor = session.endedAt ?? session.date
            guard anchor >= start && anchor < end else { continue }
            guard session.isComplete || session.hasAnyLoggedWork else { continue }
            byID[session.id] = session
        }
        return byID.values.sorted { $0.date < $1.date }
    }

    static func adjust(athlete: Athlete, sessions: [WorkoutSession], on day: Date = Date(), alsoIncluding extra: WorkoutSession? = nil, calendar: Calendar = .current) -> TrainingDayAdjustment {
        let today = TrainingDayAdjustment.sessions(on: day, from: sessions, alsoIncluding: extra, calendar: calendar)
        return adjust(
            weightKG: athlete.weightKG,
            baseline: MacroTargetCalculator.nonExerciseBaseline(for: athlete),
            sessions: today.map(TrainingSessionRecord.init)
        )
    }

    static func adjust(weightKG: Double, baseline: MacroTargets, sessions: [TrainingSessionRecord]) -> TrainingDayAdjustment {
        let withWork = sessions.filter(hasAttemptedWork)
        if sessions.isEmpty || withWork.isEmpty {
            return unchanged(
                baseline: baseline,
                sessionCount: sessions.count,
                sentences: sessions.isEmpty ? restSentences(baseline) : noWorkSentences(baseline),
                citations: [Source.mifflin]
            )
        }

        let contributions = withWork.map { contribution(for: $0, weightKG: weightKG) }
        let cited = contributions.filter { $0.netKcal > 0 }
        let extraKcal = cited.reduce(0) { $0 + $1.netKcal }
        let trainingHours = cited.reduce(0) { $0 + $1.hours }
        let minutes = Int((trainingHours * 60).rounded())
        let durationMissing = contributions.contains { $0.durationMissing }
        let activityUncited = contributions.contains { $0.activityUncited }
        let codes = cited.map(\.activity.code)
        let labels = uniqueLabels(cited.map(\.activity.label))

        guard weightKG > 0, extraKcal > 0 else {
            return unchanged(
                baseline: baseline,
                sessionCount: withWork.count,
                durationMissing: durationMissing || weightKG <= 0,
                activityUncited: activityUncited,
                sentences: placeholderSentences(
                    baseline: baseline,
                    minutes: minutesFrom(contributions),
                    activityLabel: labels.first ?? contributions.compactMap(\.recognizedLabel).first,
                    durationMissing: durationMissing || weightKG <= 0,
                    activityUncited: activityUncited || weightKG <= 0
                ),
                citations: [Source.mifflin]
            )
        }

        let allocation = allocate(
            weightKG: weightKG,
            baseline: baseline,
            extraKcal: extraKcal,
            trainingHours: trainingHours
        )
        let sentences = trainingSentences(
            minutes: minutes,
            sessionCount: cited.count,
            activityLabel: phrase(labels),
            extraKcal: extraKcal,
            baseline: baseline,
            adjusted: allocation.targets,
            load: allocation.load,
            hitFloor: allocation.hitFloor,
            hitCeiling: allocation.hitCeiling,
            codes: codes,
            mets: cited.map(\.activity.met),
            durationMissing: durationMissing,
            activityUncited: activityUncited,
            weightKG: weightKG
        )
        return TrainingDayAdjustment(
            baseline: baseline,
            adjusted: allocation.targets,
            extraKcal: extraKcal,
            trainingMinutes: minutes,
            sessionCount: withWork.count,
            appliedCodes: codes,
            carbLoad: allocation.load,
            carbClampedToFloor: allocation.hitFloor,
            carbClampedToCeiling: allocation.hitCeiling,
            durationMissing: durationMissing,
            activityUncited: activityUncited,
            targetsChanged: allocation.targets != baseline,
            explanationSentences: sentences,
            citations: [Source.compendium, Source.mifflin, Source.acsm, Source.issn, Source.amdr]
        )
    }

    // MARK: - Allocation

    private struct Allocation {
        var targets: MacroTargets
        var load: TrainingCarbLoad
        var hitFloor: Bool
        var hitCeiling: Bool
    }

    /// Extra session energy is added as carbohydrate (4 kcal per gram).
    /// Carbs are then clamped into the ACSM 2016 g/kg band for the load.
    /// Protein stays inside 1.2–2.0 g/kg. Fat is moved only if its share of
    /// the new total would leave the NIH AMDR of 20–35%.
    private static func allocate(weightKG: Double, baseline: MacroTargets, extraKcal: Double, trainingHours: Double) -> Allocation {
        let load = carbLoad(trainingHours: trainingHours)
        var hitFloor = false
        var hitCeiling = false

        var protein = baseline.proteinGrams
        let proteinBefore = protein
        protein = min(max(protein, 1.2 * weightKG), 2.0 * weightKG)

        var carbs = baseline.carbGrams + extraKcal / 4 + (proteinBefore - protein)
        if let band = load.gramsPerKilogram {
            let low = band.lowerBound * weightKG
            let high = band.upperBound * weightKG
            if carbs < low {
                carbs = low
                hitFloor = true
            } else if carbs > high {
                carbs = high
                hitCeiling = true
            }
        }

        protein = protein.rounded()
        carbs = carbs.rounded()
        if let band = load.gramsPerKilogram {
            let low = (band.lowerBound * weightKG).rounded()
            let high = (band.upperBound * weightKG).rounded()
            if carbs < low {
                carbs = low
                hitFloor = true
            } else if carbs > high {
                carbs = high
                hitCeiling = true
            }
        }

        let fat = fatGramsWithinAMDR(proteinGrams: protein, carbGrams: carbs, proposedFatGrams: baseline.fatGrams)
        let calories = protein * 4 + carbs * 4 + fat * 9
        return Allocation(
            targets: MacroTargets(
                proteinGrams: protein,
                carbGrams: carbs,
                fatGrams: fat,
                calorieEstimate: calories
            ),
            load: load,
            hitFloor: hitFloor,
            hitCeiling: hitCeiling
        )
    }

    /// NIH / National Academies adult fat AMDR is 20–35% of energy.
    static func fatGramsWithinAMDR(proteinGrams: Double, carbGrams: Double, proposedFatGrams: Double) -> Double {
        let nonFat = proteinGrams * 4 + carbGrams * 4
        guard nonFat > 0 else { return proposedFatGrams.rounded() }
        var fat = proposedFatGrams
        func share(_ grams: Double) -> Double {
            let fatKcal = grams * 9
            return fatKcal / (nonFat + fatKcal)
        }
        if share(fat) < 0.20 {
            fat = ((0.25 * nonFat) / 9).rounded()
            while share(fat) < 0.20 { fat += 1 }
        } else if share(fat) > 0.35 {
            fat = (((0.35 / 0.65) * nonFat) / 9).rounded()
            while share(fat) > 0.35 && fat > 0 { fat -= 1 }
        } else {
            fat = fat.rounded()
            if share(fat) < 0.20 { fat += 1 }
            if share(fat) > 0.35 && fat > 0 { fat -= 1 }
        }
        return fat
    }

    // MARK: - Session energy

    private struct Contribution {
        var hours: Double
        var activity: CompendiumActivity
        var netKcal: Double
        var durationMissing: Bool
        var activityUncited: Bool
        var recognizedLabel: String?
    }

    /// 2024 Adult Compendium codes used here, and no others.
    /// Herrmann et al., J Sport Health Sci 2024.
    /// https://pacompendium.com/conditioning-exercise/
    private enum CompendiumActivity: Equatable {
        case resistanceMultiple
        case vigorousResistance
        case squatsOrDeadlift
        case circuitOrSupersets
        case bodyweightGeneral
        case bodyweightHighIntensity
        case kettlebellSwings

        var code: String {
            switch self {
            case .resistanceMultiple: return "02054"
            case .vigorousResistance: return "02050"
            case .squatsOrDeadlift: return "02052"
            case .circuitOrSupersets: return "02055"
            case .bodyweightGeneral: return "02056"
            case .bodyweightHighIntensity: return "02057"
            case .kettlebellSwings: return "02058"
            }
        }

        var met: Double {
            switch self {
            case .resistanceMultiple: return 3.5
            case .vigorousResistance: return 6.0
            case .squatsOrDeadlift: return 5.0
            case .circuitOrSupersets: return 5.8
            case .bodyweightGeneral: return 3.0
            case .bodyweightHighIntensity: return 6.5
            case .kettlebellSwings: return 9.8
            }
        }

        var label: String {
            switch self {
            case .resistanceMultiple: return "resistance work"
            case .vigorousResistance: return "vigorous resistance work"
            case .squatsOrDeadlift: return "squat and deadlift work"
            case .circuitOrSupersets: return "superset work"
            case .bodyweightGeneral: return "bodyweight work"
            case .bodyweightHighIntensity: return "hard bodyweight work"
            case .kettlebellSwings: return "kettlebell swings"
            }
        }
    }

    private static func contribution(for session: TrainingSessionRecord, weightKG: Double) -> Contribution {
        let hours = durationHours(session)
        let activity = classify(session)
        let durationMissing = hours == nil
        let activityUncited = activity == nil
        let netKcal: Double
        if let activity, let hours, weightKG > 0 {
            // NET METs = MET − 1. 1 MET ≈ 1 kcal/kg/h.
            // Herrmann et al., 2024 Adult Compendium. https://pacompendium.com/conditioning-exercise/
            netKcal = (activity.met - 1) * weightKG * hours
        } else {
            netKcal = 0
        }
        return Contribution(
            hours: hours ?? missingDurationHoursPlaceholder,
            activity: activity ?? .resistanceMultiple,
            netKcal: netKcal,
            durationMissing: durationMissing,
            activityUncited: activityUncited,
            recognizedLabel: activity?.label ?? session.splitFocus.displayName.lowercased()
        )
    }

    private static func durationHours(_ session: TrainingSessionRecord) -> Double? {
        guard let endedAt = session.endedAt, endedAt > session.startedAt else { return nil }
        let hours = endedAt.timeIntervalSince(session.startedAt) / 3600
        return hours > 0 ? hours : nil
    }

    /// Conservative map onto the approved Compendium codes.
    /// A mixed session uses the general multiple-exercise code (02054, 3.5)
    /// rather than a higher code that only fits part of the work.
    /// Specific codes win only when the whole session matches them.
    /// Squats/deadlifts stay on 02052 even if a set is marked superset,
    /// because that movement code is the closer match and the lower MET.
    private static func classify(_ session: TrainingSessionRecord) -> CompendiumActivity? {
        let exercises = attemptedExercises(session)
        guard !exercises.isEmpty else { return nil }
        if exercises.allSatisfy(isKettlebellSwing) { return .kettlebellSwings }
        if exercises.allSatisfy(isSquatOrDeadlift) { return .squatsOrDeadlift }
        if exercises.contains(where: hasSuperset) { return .circuitOrSupersets }
        if exercises.allSatisfy(isBodyweight) {
            return exercises.allSatisfy(allSetsAreFailure) ? .bodyweightHighIntensity : .bodyweightGeneral
        }
        if isPowerlifting(exercises) { return .vigorousResistance }
        if uncitedFocuses.contains(session.splitFocus) && !exercises.contains(where: isRecognizedResistance) {
            return nil
        }
        return .resistanceMultiple
    }

    private static let uncitedFocuses: Set<SplitFocus> = [
        .cardio, .yoga, .dance, .cycling, .walking, .mobility, .recovery, .restDay
    ]

    private static func attemptedExercises(_ session: TrainingSessionRecord) -> [TrainingExerciseRecord] {
        session.exercises.compactMap { exercise in
            let attempted = exercise.sets.filter(\.isAttempted)
            guard !attempted.isEmpty else { return nil }
            return TrainingExerciseRecord(exerciseID: exercise.exerciseID, name: exercise.name, sets: attempted)
        }
    }

    private static func hasAttemptedWork(_ session: TrainingSessionRecord) -> Bool {
        session.exercises.contains { $0.sets.contains(where: \.isAttempted) }
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    private static func isKettlebellSwing(_ exercise: TrainingExerciseRecord) -> Bool {
        let id = normalized(exercise.exerciseID)
        let name = normalized(exercise.name)
        let blob = id + name
        let swing = blob.contains("swing")
        let kettlebell = blob.contains("kettlebell") || blob.contains("kb")
        return swing && kettlebell
    }

    private static func isSquatOrDeadlift(_ exercise: TrainingExerciseRecord) -> Bool {
        let blob = normalized(exercise.exerciseID) + normalized(exercise.name)
        return blob.contains("squat") || blob.contains("deadlift")
    }

    private static func isBodyweight(_ exercise: TrainingExerciseRecord) -> Bool {
        let blob = normalized(exercise.exerciseID) + normalized(exercise.name)
        let markers = ["pushup", "pullup", "chinup", "plank", "burpee", "airsquat", "situp", "crunch", "mountainclimber", "bodyweight"]
        return markers.contains { blob.contains($0) }
    }

    private static func isLoaded(_ exercise: TrainingExerciseRecord) -> Bool {
        exercise.sets.contains { ($0.completedWeightKG ?? 0) > 0 || ($0.plannedWeightKG ?? 0) > 0 }
    }

    private static func isRecognizedResistance(_ exercise: TrainingExerciseRecord) -> Bool {
        isKettlebellSwing(exercise) || isSquatOrDeadlift(exercise) || isBodyweight(exercise) || isLoaded(exercise)
    }

    private static func hasSuperset(_ exercise: TrainingExerciseRecord) -> Bool {
        exercise.sets.contains { $0.setType == .superset }
    }

    private static func allSetsAreFailure(_ exercise: TrainingExerciseRecord) -> Bool {
        !exercise.sets.isEmpty && exercise.sets.allSatisfy { $0.setType == .failure }
    }

    private static func isPowerlifting(_ exercises: [TrainingExerciseRecord]) -> Bool {
        let working = exercises.flatMap(\.sets).filter { $0.setType != .warmup }
        guard !working.isEmpty else { return false }
        return working.allSatisfy { $0.plannedRepRangeHigh > 0 && $0.plannedRepRangeHigh <= 5 }
    }

    // MARK: - Copy

    private enum Source {
        static let mifflin = TrainingCitation(
            id: "mifflin-1990",
            label: "Mifflin et al., Am J Clin Nutr 1990",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")!
        )
        static let compendium = TrainingCitation(
            id: "compendium-2024",
            label: "Herrmann et al., 2024 Adult Compendium",
            url: URL(string: "https://pacompendium.com/conditioning-exercise/")!
        )
        static let acsm = TrainingCitation(
            id: "acsm-2016",
            label: "Thomas, Erdman & Burke, MSSE 2016",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/26891166/")!
        )
        static let issn = TrainingCitation(
            id: "issn-2017",
            label: "Jäger et al., JISSN 2017",
            url: URL(string: "https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8")!
        )
        static let amdr = TrainingCitation(
            id: "nih-amdr",
            label: "NIH / National Academies DRI, fat 20–35%",
            url: URL(string: "https://ods.od.nih.gov/HealthInformation/nutrientrecommendations.aspx")!
        )
    }

    private static func unchanged(
        baseline: MacroTargets,
        sessionCount: Int,
        durationMissing: Bool = false,
        activityUncited: Bool = false,
        sentences: [String],
        citations: [TrainingCitation]
    ) -> TrainingDayAdjustment {
        TrainingDayAdjustment(
            baseline: baseline,
            adjusted: baseline,
            extraKcal: 0,
            trainingMinutes: 0,
            sessionCount: sessionCount,
            appliedCodes: [],
            carbLoad: .none,
            carbClampedToFloor: false,
            carbClampedToCeiling: false,
            durationMissing: durationMissing,
            activityUncited: activityUncited,
            targetsChanged: false,
            explanationSentences: sentences,
            citations: citations
        )
    }

    private static func restSentences(_ baseline: MacroTargets) -> [String] {
        [
            "No training is logged today, so today's targets are unchanged: about \(whole(baseline.calorieEstimate)) kcal, \(whole(baseline.carbGrams)) g carbohydrate, \(whole(baseline.proteinGrams)) g protein, and \(whole(baseline.fatGrams)) g fat",
            "Nothing was added for a workout",
            "This baseline is Mifflin–St Jeor rest burn times a PLACEHOLDER activity factor of 1.2"
        ]
    }

    private static func noWorkSentences(_ baseline: MacroTargets) -> [String] {
        [
            "A session was logged today, but no sets were completed, so no training energy was added",
            "Today's targets stay unchanged at the non-exercise baseline: about \(whole(baseline.calorieEstimate)) kcal, \(whole(baseline.carbGrams)) g carbohydrate, \(whole(baseline.proteinGrams)) g protein, and \(whole(baseline.fatGrams)) g fat",
            "That baseline is Mifflin–St Jeor rest burn times a PLACEHOLDER activity factor of 1.2"
        ]
    }

    private static func placeholderSentences(
        baseline: MacroTargets,
        minutes: Int,
        activityLabel: String?,
        durationMissing: Bool,
        activityUncited: Bool
    ) -> [String] {
        let opener: String
        if durationMissing && !activityUncited, let activityLabel {
            opener = "You logged \(activityLabel) today, but the session has no finish time, so its energy is a PLACEHOLDER of \(whole(missingDurationHoursPlaceholder)) kcal and was not added"
        } else if activityUncited && minutes > 0 {
            let what = activityLabel.map { " of \($0)" } ?? ""
            opener = "You logged \(minutes) min\(what), but that activity has no energy value in the sources this screen uses, so it adds a PLACEHOLDER of 0 kcal"
        } else {
            opener = "You logged training today, but this screen could not use a cited duration and activity, so workout energy is a PLACEHOLDER of 0 kcal and was not added"
        }
        return [
            opener,
            "Today's targets stay at the non-exercise baseline: about \(whole(baseline.calorieEstimate)) kcal, \(whole(baseline.carbGrams)) g carbohydrate, \(whole(baseline.proteinGrams)) g protein, and \(whole(baseline.fatGrams)) g fat",
            "That baseline is Mifflin–St Jeor rest burn times a PLACEHOLDER activity factor of 1.2"
        ]
    }

    private static func trainingSentences(
        minutes: Int,
        sessionCount: Int,
        activityLabel: String,
        extraKcal: Double,
        baseline: MacroTargets,
        adjusted: MacroTargets,
        load: TrainingCarbLoad,
        hitFloor: Bool,
        hitCeiling: Bool,
        codes: [String],
        mets: [Double],
        durationMissing: Bool,
        activityUncited: Bool,
        weightKG: Double
    ) -> [String] {
        let across = sessionCount > 1 ? " across \(sessionCount) sessions" : ""
        let kcal = whole(extraKcal)
        let delta = whole(adjusted.carbGrams - baseline.carbGrams)
        let opener: String
        if hitFloor || hitCeiling {
            opener = "You trained \(minutes) min\(across) of \(activityLabel), about \(kcal) kcal above rest"
        } else if delta > 0 {
            opener = "You trained \(minutes) min\(across) of \(activityLabel), about \(kcal) kcal above rest, so carbs are up \(delta) g to refuel"
        } else {
            opener = "You trained \(minutes) min\(across) of \(activityLabel), about \(kcal) kcal above rest, so carbs stay at \(whole(adjusted.carbGrams)) g"
        }

        var metSentence = "Net METs from the 2024 Adult Compendium (\(codePhrase(codes: codes, mets: mets))) leave out resting energy already counted by the Mifflin–St Jeor baseline"
        if durationMissing || activityUncited {
            metSentence += ", and another logged session has no cited duration or activity, so that part stays a PLACEHOLDER of 0 kcal"
        }

        let range = load.gramsPerKilogram.map { "\(trim($0.lowerBound))–\(trim($0.upperBound)) g/kg" } ?? ""
        let perKg = String(format: "%.1f", adjusted.carbGrams / weightKG)
        let carbSentence: String
        if hitFloor {
            carbSentence = "Carbs are up \(delta) g so the day meets the low end of the ACSM 2016 \(load.name) range of \(range)"
        } else if hitCeiling {
            carbSentence = "Carbs are up \(delta) g and stop at the top of the ACSM 2016 \(load.name) range of \(range)"
        } else {
            carbSentence = "Carbs are \(perKg) g/kg, inside the ACSM 2016 \(load.name) range of \(range)"
        }

        let proteinSentence = "Protein stays at \(whole(adjusted.proteinGrams)) g, inside the ACSM 2016 and ISSN 2017 range of 1.2–2.0 g/kg, and fat stays inside the NIH adult range of 20–35% of energy"
        return [opener, metSentence, carbSentence, proteinSentence]
    }

    private static func codePhrase(codes: [String], mets: [Double]) -> String {
        let unique = uniqueLabels(codes)
        let metText = uniqueLabels(mets.map { String(format: "%.1f", $0) }).joined(separator: " and ")
        if unique.count == 1, let code = unique.first {
            return "code \(code), \(metText) METs"
        }
        return "codes \(unique.joined(separator: " and ")), \(metText) METs"
    }

    private static func phrase(_ labels: [String]) -> String {
        switch labels.count {
        case 0: return "training"
        case 1: return labels[0]
        case 2: return "\(labels[0]) and \(labels[1])"
        default: return "mixed training"
        }
    }

    private static func uniqueLabels(_ labels: [String]) -> [String] {
        var seen: [String] = []
        for label in labels where !seen.contains(label) {
            seen.append(label)
        }
        return seen
    }

    private static func minutesFrom(_ contributions: [Contribution]) -> Int {
        let hours = contributions.reduce(0) { partial, item in
            item.durationMissing ? partial : partial + item.hours
        }
        return Int((hours * 60).rounded())
    }

    private static func whole(_ value: Double) -> Int {
        Int(value.rounded())
    }

    private static func trim(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.1f", value)
    }
}
