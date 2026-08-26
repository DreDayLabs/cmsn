import SwiftUI

/// Manual, in-session substitution — separate from `ProgramResolver`'s
/// automatic equipment/injury substitution, this is the athlete choosing to
/// swap an exercise for their own reasons (machine's taken, don't like it,
/// etc.). Candidates share a muscle group with the original.
struct SubstitutionPicker: View {
    let original: any ExerciseRepresentable
    let equipmentProfile: EquipmentProfile
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss

    private var candidates: [Exercise] {
        let available = equipmentProfile.availableEquipment
        return SeedData.exercises.filter { candidate in
            candidate.id != original.id
                && !Set(candidate.primaryMuscleGroups).isDisjoint(with: Set(original.primaryMuscleGroups))
                && (candidate.equipmentRequired.isEmpty || candidate.equipmentRequired.contains { available.contains($0) })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                List(candidates, id: \.id) { candidate in
                    Button {
                        onSelect(candidate)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.name).font(CMSNTypography.body())
                            Text(candidate.equipmentRequired.map(\.rawValue).joined(separator: ", "))
                                .font(CMSNTypography.bodyQuiet())
                                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        }
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    }
                    .listRowBackground(CMSNColor.offBlack)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Swap \(original.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
