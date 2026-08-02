import Foundation

/// Body-area selector for the injury/limitation intake — deliberately modeled
/// like picking a medical specialty (per the product spec) without acting like
/// one. This enum drives exercise exclusion/substitution; it never drives
/// diagnosis or treatment language anywhere in the app.
enum BodyArea: String, Codable, CaseIterable, Identifiable {
    case neck, upperBack, lowerBack, shoulder, elbow, wrist, hand, chest
    case hip, glute, quadriceps, hamstring, knee, calf, shin, ankle, foot
    case generalSoreness, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neck: return "Neck"
        case .upperBack: return "Upper Back"
        case .lowerBack: return "Lower Back"
        case .shoulder: return "Shoulder"
        case .elbow: return "Elbow"
        case .wrist: return "Wrist"
        case .hand: return "Hand"
        case .chest: return "Chest"
        case .hip: return "Hip"
        case .glute: return "Glute"
        case .quadriceps: return "Quadriceps"
        case .hamstring: return "Hamstring"
        case .knee: return "Knee"
        case .calf: return "Calf"
        case .shin: return "Shin"
        case .ankle: return "Ankle"
        case .foot: return "Foot"
        case .generalSoreness: return "General Soreness"
        case .other: return "Other"
        }
    }
}

/// Severity is what actually drives the response (exclude vs. substitute vs.
/// just note it) — the area alone isn't enough. `.clinicianDirected` is the
/// strictest: any exercise touching that area is excluded outright rather
/// than substituted, and the copy defers entirely to the user's own
/// professional guidance rather than offering a CMSN workaround.
enum LimitationSeverity: String, Codable, CaseIterable, Identifiable, Comparable {
    case none
    case mild
    case recurring
    case significant
    case recoveringFromKnownInjury
    case clinicianDirected

    var id: String { rawValue }

    private var ordinal: Int {
        switch self {
        case .none: return 0
        case .mild: return 1
        case .recurring: return 2
        case .significant: return 3
        case .recoveringFromKnownInjury: return 4
        case .clinicianDirected: return 5
        }
    }

    static func < (lhs: LimitationSeverity, rhs: LimitationSeverity) -> Bool {
        lhs.ordinal < rhs.ordinal
    }

    var displayName: String {
        switch self {
        case .none: return "No current issue"
        case .mild: return "Mild discomfort"
        case .recurring: return "Recurring discomfort"
        case .significant: return "Significant discomfort"
        case .recoveringFromKnownInjury: return "Recovering from a known injury"
        case .clinicianDirected: return "Clinician-directed limitation"
        }
    }

    /// Whether an exercise loading this area should be removed outright
    /// (true) vs. offered as a reduced-load/substituted alternative (false).
    var requiresExclusionRatherThanSubstitution: Bool {
        self >= .significant
    }
}

/// One reported limitation. Stored as a plain Codable struct (not a SwiftData
/// model) because it's small, always owned by exactly one `Athlete`, and
/// SwiftData supports arrays of Codable value types directly.
struct BodyLimitation: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var area: BodyArea
    var severity: LimitationSeverity
    var note: String?
    var reportedAt: Date = Date()
}

/// Non-negotiable copy boundary, enforced in code rather than left to
/// per-screen discipline: every string shown alongside a `BodyLimitation`
/// must pass through this list before shipping. Nothing in the app names a
/// medical condition, diagnoses, or prescribes treatment/rehab.
enum InjurySafetyLanguage {
    static let stopCue = "Stop if the movement causes sharp or increasing pain."
    static let reduceLoadCue = "Reduce the weight when your form changes."
    static let faintCue = "Sit or lie down safely if you feel faint."
    static let breathingCue = "Hydrate and allow your breathing to settle."
    static let emergencyCue = "Seek immediate help for severe symptoms."
    static let professionalCue = "Consult a qualified professional for persistent pain or injury."

    static let all: [String] = [stopCue, reduceLoadCue, faintCue, breathingCue, emergencyCue, professionalCue]

    /// Disclaimer footer required on every screen that reacts to a reported
    /// limitation (substitution pickers, injury intake, workout adjustments).
    static let disclaimerFooter = "CMSN adjusts training suggestions based on what you report. This is not medical advice and CMSN does not diagnose or treat any condition."
}
