import EventKit
import Foundation

/// Reads today's Calendar for a scheduled workout (e.g. an event titled
/// "Leg Day") so a rescheduled or manually-planned day overrides the default
/// program rotation — the "walks in the gym, app already knows" moment.
///
/// iOS 17+ full-access EventKit API (`requestFullAccessToEvents`). Priming
/// copy is shown by the caller (see `TodayView`) before this is invoked, per
/// App Store review expectations around permission prompts.
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
    /// first match, or `nil` if nothing overrides the default rotation, or if
    /// access hasn't been granted.
    func todaysOverrideFocus(referenceDate: Date = Date()) -> SplitFocus? {
        guard authorizationState == .authorized else { return nil }

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
    func todaysOverrideEvent(referenceDate: Date = Date()) -> EKEvent? {
        guard authorizationState == .authorized else { return nil }
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
