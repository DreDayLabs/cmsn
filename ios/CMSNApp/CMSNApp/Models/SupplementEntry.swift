import Foundation

/// General confidence label on the evidence behind an entry — deliberately
/// NOT a personalized dosing recommendation. This is a library, not a
/// coach: see `brand/08-app-strategy.md` §8 for the FDA general-wellness
/// framing this stays inside of.
enum EvidenceLevel: String, Codable, CaseIterable {
    case limited, moderate, strong

    var displayName: String {
        switch self {
        case .limited: return "Limited evidence"
        case .moderate: return "Moderate evidence"
        case .strong: return "Strong evidence"
        }
    }
}

/// One entry in the static supplement education library. Every field is
/// written in hedged language ("may support") — never "will," never a
/// disease/treatment/prevention claim, never a personalized dose. Seeded as
/// a fixed Swift array in `SeedData`; nothing here is generated per-user.
struct SupplementEducationEntry: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var whatItIs: String
    /// Hedged bullet points only — reviewed against the "may support, never
    /// will" rule before shipping any new entry.
    var mayHelpSupport: [String]
    var evidenceLevel: EvidenceLevel
    var commonForms: [String]
    var labelUseReminder: String
    var cautions: [String]
    var consultProfessionalWhen: [String]
    var sourceReferences: [String]
    var lastReviewed: Date
}

enum SupplementDisclaimer {
    static let footer = "This is general education, not medical advice or a personalized recommendation. CMSN does not determine that you need any supplement. Consult a physician before starting any new supplement, especially if pregnant, nursing, on medication, or managing a health condition."
}
