import EventKit
import Foundation

/// Reads today's Calendar for a scheduled workout (e.g. an event titled
/// "Leg Day") so a rescheduled or manually-planned day overrides the default
/// program rotation — the "walks in the gym, app already knows" moment.
///
/// iOS 17+ full-access EventKit API (`requestFullAccessToEvents`). Settings
/// calls `requestAccess()` only after the user turns Today's calendar on.
/// Today never calls it. The read is today's event titles on all calendars,
/// plus the matched event's identifier. Notes, attendees, and event writes
/// are not used.
@MainActor
final class CalendarSplitService {
    private let eventStore = EKEventStore()

    enum AuthorizationState: Equatable {
        case notDetermined, authorized, denied
    }

    var authorizationState: AuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .fullAccess, .authorized: return .authorized
        case .denied, .restricted, .writeOnly: return .denied
        @unknown default: return .denied
        }
    }

    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    /// Scans today's calendar events for a title matching a known
    /// `SplitFocus` keyword (see `SplitFocus.calendarKeywords`). Returns the
    /// first match, or `nil` if the user has not opted in, access has not
    /// been granted, or nothing overrides the default rotation.
    /// `userOptedIn` defaults off so a forgotten caller cannot read titles.
    func todaysOverrideFocus(userOptedIn: Bool = false, referenceDate: Date = Date()) -> SplitFocus? {
        guard CalendarAccessPolicy.gate(userOptedIn: userOptedIn, authorization: authorizationState) == .readTitles else {
            return nil
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let todaysEvents = eventStore.events(matching: predicate)

        for event in todaysEvents {
            let title = event.title?.lowercased() ?? ""
            for focus in SplitFocus.allCases {
                guard !focus.calendarKeywords.isEmpty else { continue }
                if focus.calendarKeywords.contains(where: { title.contains($0) }) {
                    return focus
                }
            }
        }
        return nil
    }

    /// The matched event's title, kept for display ("From your calendar:
    /// 'Leg Day @ 6pm'") and for `WorkoutSession.sourceCalendarEventIdentifier`.
    func todaysOverrideEvent(userOptedIn: Bool = false, referenceDate: Date = Date()) -> EKEvent? {
        guard CalendarAccessPolicy.gate(userOptedIn: userOptedIn, authorization: authorizationState) == .readTitles else {
            return nil
        }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let todaysEvents = eventStore.events(matching: predicate)
        return todaysEvents.first { event in
            let title = event.title?.lowercased() ?? ""
            return SplitFocus.allCases.contains { !$0.calendarKeywords.isEmpty && $0.calendarKeywords.contains { title.contains($0) } }
        }
    }
}

/// Decides whether CMSN may read today's event titles or ask iOS for access.
/// Opt-in defaults off. Today must not be the caller that requests access.
enum CalendarAccessPolicy {
    enum Gate: Equatable {
        /// User has not turned Today's calendar on. Do not read or ask.
        case off
        /// User opted in, but iOS has not been asked yet. Do not read.
        /// Only the Settings toggle may request access in this state.
        case waitingForPrompt
        /// User opted in and iOS is allowing full or legacy read access.
        case readTitles
        /// User opted in and iOS has denied, restricted, or write-only access.
        case blocked
    }

    static func gate(
        userOptedIn: Bool,
        authorization: CalendarSplitService.AuthorizationState
    ) -> Gate {
        guard userOptedIn else { return .off }
        switch authorization {
        case .notDetermined: return .waitingForPrompt
        case .authorized: return .readTitles
        case .denied: return .blocked
        }
    }

    /// True only after an explicit opt-in, and only while iOS has not asked yet.
    /// A denied or revoked grant does not ask again.
    static func shouldRequestPermission(
        userOptedIn: Bool,
        authorization: CalendarSplitService.AuthorizationState
    ) -> Bool {
        userOptedIn && authorization == .notDetermined
    }

    static func statusLine(
        userOptedIn: Bool,
        authorization: CalendarSplitService.AuthorizationState
    ) -> String {
        switch gate(userOptedIn: userOptedIn, authorization: authorization) {
        case .off:
            return "Off. CMSN does not ask until you turn this on."
        case .waitingForPrompt:
            return "On. iOS has not asked yet."
        case .readTitles:
            return "On. Today's event titles can set the workout."
        case .blocked:
            return "Blocked. iOS is not allowing calendar access."
        }
    }
}
