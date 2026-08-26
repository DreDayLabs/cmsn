import SwiftUI

/// Step 3: the injury/limitation intake. Modeled like picking a body area
/// on a diagram, not a medical specialty questionnaire — and it says so.
/// Every area added here flows straight into `ProgramResolver`'s exclusion/
/// substitution logic; nothing here diagnoses or treats anything.
struct LimitationsStepView: View {
    @Binding var draft: OnboardingDraft
    let onFinish: () -> Void
    let onBack: () -> Void

    @State private var selectedArea: BodyArea?
    @State private var selectedSeverity: LimitationSeverity = .mild

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    EyebrowLabel(text: "Step 3 of 3")
                    Text("Anything We Should\nWork Around?")
                        .font(CMSNTypography.displaySmall(32))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    Text("Optional. This adjusts exercise suggestions — it isn't medical advice, and CMSN doesn't diagnose or treat anything.")
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }

                if !draft.limitations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Reported")
                        ForEach(draft.limitations) { limitation in
                            HStack {
                                Text("\(limitation.area.displayName) — \(limitation.severity.displayName)")
                                    .font(CMSNTypography.body())
                                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                                Spacer()
                                Button {
                                    draft.limitations.removeAll { $0.id == limitation.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    EyebrowLabel(text: "Add An Area")
                    FlowToggleGrid(
                        items: BodyArea.allCases,
                        isOn: { $0 == selectedArea },
                        label: \.displayName
                    ) { area in
                        selectedArea = (selectedArea == area) ? nil : area
                    }
                }

                if selectedArea != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        EyebrowLabel(text: "Severity")
                        Picker("Severity", selection: $selectedSeverity) {
                            ForEach(LimitationSeverity.allCases.filter { $0 != .none }) { severity in
                                Text(severity.displayName).tag(severity)
                            }
                        }
                        .pickerStyle(.wheel)
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)

                        Button("Add") {
                            guard let area = selectedArea else { return }
                            draft.limitations.append(BodyLimitation(area: area, severity: selectedSeverity))
                            selectedArea = nil
                            selectedSeverity = .mild
                        }
                        .buttonStyle(.cmsnGhost)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(InjurySafetyLanguage.all, id: \.self) { line in
                        Text(line).font(.system(size: 11)).foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                }

                HStack(spacing: 16) {
                    Button("Back") { onBack() }.buttonStyle(.cmsnGhost)
                    Button("Start Training") { onFinish() }.buttonStyle(.cmsnPrimary)
                }
            }
            .padding(24)
        }
        .background(CMSNColor.offBlack.ignoresSafeArea())
    }
}
