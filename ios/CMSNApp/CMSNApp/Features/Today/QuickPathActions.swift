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

    var systemImage: String {
        switch self {
        case .fifteenMinutes: return "timer"
        case .dumbbellsOnly: return "dumbbell"
        case .walk: return "figure.walk"
        case .soreToday: return "bandage"
        case .comingBack: return "arrow.uturn.backward"
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

/// A horizontal row of quick-path buttons on the Today screen.
struct QuickPathActionBar: View {
    let onSelect: (QuickPathAction) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(QuickPathAction.allCases) { action in
                    Button {
                        onSelect(action)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: action.systemImage)
                            Text(action.title.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .kerning(1.2)
                        }
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
