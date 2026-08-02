import SwiftUI

/// The post-session apparel feedback loop — the "Dress" side of the
/// five-loop system. Always optional, always skippable, designed to clear
/// in under 20 seconds. This is genuinely just a few taps: garment, size,
/// four yes/no toggles, one free-text field.
struct ApparelFeedbackView: View {
    let session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var garmentName: String = ""
    @State private var sizeWorn: String = ""
    @State private var stayedInPlace: Bool?
    @State private var waistbandSecure: Bool?
    @State private var restrictedMovement: Bool?
    @State private var sweatManaged: Bool?
    @State private var seamIrritation: Bool?
    @State private var wouldWearAgain: Bool?
    @State private var freeTextNote: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                CMSNColor.offBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            EyebrowLabel(text: "Under 20 Seconds")
                            Text("How'd The Gear Do?")
                                .font(CMSNTypography.displaySmall(30))
                                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        }

                        labeledField("Garment", text: $garmentName, placeholder: "e.g. CMSN Compression Pant")
                        labeledField("Size", text: $sizeWorn, placeholder: "e.g. L")

                        yesNoRow("Stayed in place?", selection: $stayedInPlace)
                        yesNoRow("Waistband secure?", selection: $waistbandSecure)
                        yesNoRow("Restricted movement?", selection: $restrictedMovement)
                        yesNoRow("Sweat managed well?", selection: $sweatManaged)
                        yesNoRow("Any seam irritation?", selection: $seamIrritation)
                        yesNoRow("Would you wear it again?", selection: $wouldWearAgain)

                        labeledField("Anything else?", text: $freeTextNote, placeholder: "Optional note")

                        Button("Submit") { submit() }
                            .buttonStyle(.cmsnPrimary)
                            .disabled(garmentName.isEmpty)
                    }
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
            }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(CMSNTypography.bodyQuiet()).foregroundStyle(CMSNColor.Semantic.textSecondary)
            TextField(placeholder, text: text)
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .padding(10)
                .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
        }
    }

    private func yesNoRow(_ label: String, selection: Binding<Bool?>) -> some View {
        HStack {
            Text(label).font(CMSNTypography.body()).foregroundStyle(CMSNColor.Semantic.textPrimary)
            Spacer()
            Button("Yes") { selection.wrappedValue = true }
                .buttonStyle(.cmsnText)
                .opacity(selection.wrappedValue == true ? 1 : 0.4)
            Button("No") { selection.wrappedValue = false }
                .buttonStyle(.cmsnText)
                .opacity(selection.wrappedValue == false ? 1 : 0.4)
        }
    }

    private func submit() {
        let feedback = ApparelFeedback(
            garmentName: garmentName,
            sizeWorn: sizeWorn,
            stayedInPlace: stayedInPlace,
            waistbandSecure: waistbandSecure,
            restrictedMovement: restrictedMovement,
            sweatManaged: sweatManaged,
            seamIrritation: seamIrritation,
            wouldWearAgain: wouldWearAgain,
            freeTextNote: freeTextNote
        )
        feedback.session = session
        session.apparelFeedback = feedback
        modelContext.insert(feedback)
        try? modelContext.save()
        dismiss()
    }
}
