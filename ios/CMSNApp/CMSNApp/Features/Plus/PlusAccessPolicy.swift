import Foundation

/// The complete paid-access policy. Views never interpret StoreKit transactions.
/// A failed/unavailable verification preserves the last verified paid decision.
struct PlusAccessPolicy: Codable, Equatable {
    enum State: String { case runway, plus, free }
    enum Capability: String, CaseIterable {
        case manualLogging, runRecording, watchRecording, records, export, basicScore, basicMacros, manualFood
        case planning, coaching, fueling
        var requiresPlus: Bool {
            switch self {
            case .planning, .coaching, .fueling: return true
            default: return false
            }
        }
    }
    private(set) var assessmentCompletedAt: Date?
    private(set) var paidAccess = false
    private(set) var lastVerifiedAt: Date?
    static let runwayDuration: TimeInterval = 7 * 24 * 60 * 60

    mutating func completeAssessment(at date: Date) {
        // Editing/repeating the assessment must not restart the runway.
        if assessmentCompletedAt == nil { assessmentCompletedAt = date }
    }
    mutating func applyVerifiedPaidAccess(_ active: Bool, at date: Date) {
        paidAccess = active
        lastVerifiedAt = date
    }
    var runwayEndsAt: Date? { assessmentCompletedAt?.addingTimeInterval(Self.runwayDuration) }
    func state(at now: Date) -> State {
        if paidAccess { return .plus }
        if let start = assessmentCompletedAt, let end = runwayEndsAt, now >= start, now < end { return .runway }
        return .free
    }
    func allows(_ capability: Capability, at now: Date) -> Bool {
        !capability.requiresPlus || state(at: now) != .free
    }
}

/// Persisted at workout creation. This decision never changes mid-session.
struct PlusSessionAccess: Codable, Equatable {
    let coachingEnabled: Bool
    init(policy: PlusAccessPolicy, at date: Date) {
        coachingEnabled = policy.allows(.coaching, at: date)
    }
}
