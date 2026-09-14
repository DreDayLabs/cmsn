import Foundation

/// Where the athlete trains — the single biggest driver of what a generated
/// session looks like. First-class on the athlete/session model per the
/// product spec, not a buried settings toggle, because it's what resolves
/// "I only have dumbbells" in one tap.
enum EquipmentProfile: String, Codable, CaseIterable, Identifiable {
    case residentialGym
    case fullServiceGym
    case home
    case travel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .residentialGym: return "Residential Gym"
        case .fullServiceGym: return "Full-Service Gym"
        case .home: return "Home"
        case .travel: return "Travel"
        }
    }

    var summary: String {
        switch self {
        case .residentialGym:
            return "Smith machine, dumbbells, kettlebells, cables, bands, a few machines, cardio equipment, studio space."
        case .fullServiceGym:
            return "Squat racks, barbells, platforms, full machine selection, heavier dumbbells, specialty equipment."
        case .home:
            return "Bodyweight, bands, dumbbells, kettlebells, a bench."
        case .travel:
            return "Hotel fitness center, bodyweight, bands, short sessions."
        }
    }

    /// What this profile actually has on hand, used by `ProgramResolver` to
    /// decide whether an exercise's required equipment is available.
    var availableEquipment: Set<EquipmentType> {
        switch self {
        case .residentialGym:
            return [.smithMachine, .dumbbells, .kettlebell, .cable, .band, .machine, .cardioMachine, .bodyweight, .bench]
        case .fullServiceGym:
            return [.barbell, .smithMachine, .dumbbells, .kettlebell, .cable, .band, .machine, .cardioMachine, .bodyweight, .bench]
        case .home:
            return [.dumbbells, .kettlebell, .band, .bodyweight, .bench]
        case .travel:
            return [.band, .bodyweight]
        }
    }
}

enum EquipmentType: String, Codable, CaseIterable {
    case barbell, smithMachine, dumbbells, kettlebell, cable, band, machine, cardioMachine, bodyweight, bench, other
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest, back, shoulders, biceps, triceps, forearms
    case quadriceps, hamstrings, glutes, calves
    case core, fullBody, cardio
}

enum ExerciseTrackingType: String, Codable {
    case repsAndWeight
    case repsOnly
    case time
    case distance
    case assisted
}

enum SetType: String, Codable, CaseIterable {
    case warmup, working, failure, dropSet, superset
}

/// A rotating split template. `.custom` covers a user-authored rotation;
/// EventKit calendar events can override any of these on a given day.
enum SplitFocus: String, Codable, CaseIterable, Identifiable {
    case push, pull, legs
    case upperBody, lowerBody
    case chest, back, arms, core
    case fullBody
    case cardio, kettlebell, mobility, yoga, dance, cycling, walking, recovery
    case restDay
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .push: return "Push"
        case .pull: return "Pull"
        case .legs: return "Legs"
        case .upperBody: return "Upper Body"
        case .lowerBody: return "Lower Body"
        case .chest: return "Chest"
        case .back: return "Back"
        case .arms: return "Arms"
        case .core: return "Core"
        case .fullBody: return "Full Body"
        case .cardio: return "Cardio"
        case .kettlebell: return "Kettlebell"
        case .mobility: return "Mobility"
        case .yoga: return "Yoga"
        case .dance: return "Dance"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .recovery: return "Recovery"
        case .restDay: return "Rest Day"
        case .custom: return "Custom"
        }
    }

    /// Keywords `CalendarSplitService` matches against today's calendar event
    /// titles to detect an override (e.g. an event titled "Leg Day").
    var calendarKeywords: [String] {
        switch self {
        case .push: return ["push"]
        case .pull: return ["pull"]
        case .legs: return ["leg", "legs", "leg day"]
        case .upperBody: return ["upper", "upper body"]
        case .lowerBody: return ["lower", "lower body"]
        case .chest: return ["chest"]
        case .back: return ["back"]
        case .arms: return ["arms", "arm day"]
        case .core: return ["core", "abs"]
        case .fullBody: return ["full body", "total body"]
        case .cardio: return ["cardio", "run", "running"]
        case .kettlebell: return ["kettlebell", "kb"]
        case .mobility: return ["mobility", "stretch"]
        case .yoga: return ["yoga"]
        case .dance: return ["dance"]
        case .cycling: return ["cycling", "spin", "bike"]
        case .walking: return ["walk", "walking"]
        case .recovery: return ["recovery", "rest", "active recovery"]
        case .restDay: return ["rest day", "off day"]
        case .custom: return []
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// Multi-select — the spec is explicit that goal type is plural, and that
/// weight loss is never assumed as the universal definition of "improvement."
enum GoalType: String, Codable, CaseIterable, Identifiable {
    case strength, muscleGain, fatLoss, recomposition, endurance, mobility
    case generalFitness, clothingSizeGoal, eventPrep, consistency, returnToTraining

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .muscleGain: return "Muscle Gain"
        case .fatLoss: return "Fat Loss"
        case .recomposition: return "Recomposition"
        case .endurance: return "Endurance"
        case .mobility: return "Mobility"
        case .generalFitness: return "General Fitness"
        case .clothingSizeGoal: return "Clothing-Size Goal"
        case .eventPrep: return "Event Prep"
        case .consistency: return "Consistency"
        case .returnToTraining: return "Return to Training"
        }
    }
}

enum TrainingStyle: String, Codable, CaseIterable, Identifiable {
    case strength, hypertrophy, cardio, kettlebell, mobility, yoga, dance, cycling, walking, recovery, hybrid
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum UnitPreference: String, Codable, CaseIterable, Identifiable {
    case imperial, metric
    var id: String { rawValue }
}

enum CoachingTone: String, Codable, CaseIterable, Identifiable {
    case direct, encouraging, technical
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// Used only as a physiological input to the Mifflin-St Jeor calorie
/// estimate — never surfaced as an identity field, never required, never
/// used to branch product experience or content.
enum BiologicalSexForCalculation: String, Codable, CaseIterable, Identifiable {
    case male, female, preferNotToSay
    var id: String { rawValue }
}
