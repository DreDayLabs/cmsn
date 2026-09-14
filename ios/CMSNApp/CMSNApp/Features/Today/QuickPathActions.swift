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

/// Horizontal quick-path row — text-only uppercase labels, no SF Symbol
/// icon chips. Icon-in-card rows are a generic fitness-app pattern; CMSN's
/// chrome is quiet type, matching the site's eyebrow language.
struct QuickPathActionBar: View {
    let onSelect: (QuickPathAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Quick Path")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(QuickPathAction.allCases) { action in
                        Button {
                            onSelect(action)
                        } label: {
                            Text(action.title.uppercased())
                                .font(CMSNTypography.eyebrow())
                                .kerning(1.6)
                                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .cmsnChip(isSelected: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
