import SwiftUI

/// The minimum-user's one-or-two-tap paths, verbatim from the product spec:
/// "give me a 15-minute workout," "I only have dumbbells," "I want to walk
/// today," "I am sore," "I have not trained in two weeks." Each resolves
/// directly to a `ResolvedProgramDay` via `ProgramResolver`, bypassing the
/// full rotation — CMSN should not build primarily for the middle user, and
/// this is the concrete mechanism that keeps the minimum user served.
enum QuickPathAction: String, CaseIterable, Identifiable {
    case fifteenMinutes, dumbbellsOnly, walk, soreToday, comingBack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fifteenMinutes: return "15 Minutes"
        case .dumbbellsOnly: return "Dumbbells Only"
        case .walk: return "Just Walk"
        case .soreToday: return "I'm Sore"
        case .comingBack: return "Coming Back"
        }
    }

    /// Sentence-case pill. The enum `title` stays for anything that already
    /// matches on it; the bar renders this so the row is not tracked caps.
    var chipTitle: String {
        switch self {
        case .fifteenMinutes: return "15 minutes"
        case .dumbbellsOnly: return "Dumbbells only"
        case .walk: return "Just walk"
        case .soreToday: return "I'm sore"
        case .comingBack: return "Coming back"
        }
    }

    @MainActor
    func resolve(currentFocus: SplitFocus, resolver: ProgramResolver, athlete: Athlete) -> ResolvedProgramDay {
        switch self {
        case .fifteenMinutes:
            return resolver.resolveQuickSession(focus: currentFocus, equipmentOverride: nil, maxExercises: 3, athlete: athlete)
        case .dumbbellsOnly:
            return resolver.resolveQuickSession(focus: currentFocus, equipmentOverride: .home, maxExercises: 5, athlete: athlete)
        case .walk:
            return resolver.resolveQuickSession(focus: .walking, equipmentOverride: nil, maxExercises: 1, athlete: athlete)
        case .soreToday:
            return resolver.resolveQuickSession(focus: .recovery, equipmentOverride: nil, maxExercises: 3, athlete: athlete)
        case .comingBack:
            return resolver.resolveQuickSession(focus: .fullBody, equipmentOverride: nil, maxExercises: 3, athlete: athlete)
        }
    }
}

/// Quick-path pills in two rows, so every chip is on screen.
struct QuickPathActionBar: View {
    let onSelect: (QuickPathAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick path")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text("Short on time or kit? Reshape today's session.")
                .font(.system(size: 15))
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            // Two fixed rows. A wrapping layout reported a one-row height
            // and then clipped "I'm sore" and "Coming back".
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    chip(.fifteenMinutes)
                    chip(.dumbbellsOnly)
                    chip(.walk)
                }
                HStack(spacing: 8) {
                    chip(.soreToday)
                    chip(.comingBack)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chip(_ action: QuickPathAction) -> some View {
        Button {
            onSelect(action)
        } label: {
            Text(action.chipTitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .lineLimit(1)
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .cmsnChip(isSelected: false)
        }
        .buttonStyle(.plain)
    }
}
