import Foundation
import Observation

@MainActor
@Observable
final class PlusEntitlementService {
    private(set) var policy: PlusAccessPolicy
    private(set) var now: Date
    private let defaults: UserDefaults
    private static let key = "cmsn.plus.access.v1"

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        self.now = now
        policy = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(PlusAccessPolicy.self, from: $0) } ?? PlusAccessPolicy()
    }
    var state: PlusAccessPolicy.State { policy.state(at: now) }
    var hasPlus: Bool { state != .free }
    func allows(_ capability: PlusAccessPolicy.Capability) -> Bool { policy.allows(capability, at: now) }
    func refreshClock(_ date: Date = Date()) { now = date }
    func completeAssessment(at date: Date) {
        policy.completeAssessment(at: date)
        persist()
        refreshClock()
    }
    /// Call only with verified Apple state. Offline/error paths do not call this.
    func applyVerifiedPaidAccess(_ active: Bool, at date: Date = Date()) {
        policy.applyVerifiedPaidAccess(active, at: date)
        now = date
        persist()
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(policy) { defaults.set(data, forKey: Self.key) }
    }
}
