import SwiftUI

/// A browsable, static education library — deliberately not a
/// recommendation flow. There is no "CMSN thinks you need X" path anywhere
/// in this screen; the athlete comes here to read, not to be told what to buy.
struct SupplementLibraryView: View {
    @State private var selectedEntry: SupplementEducationEntry?

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    ForEach(SupplementLibraryData.entries) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            SupplementRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(SupplementDisclaimer.footer)
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        .padding(.top, 12)
                }
                .padding(24)
            }
        }
        .sheet(item: $selectedEntry) { entry in
            SupplementDetailView(entry: entry)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Education, not prescription")
            Text("Supplements")
                .font(CMSNTypography.displaySmall(36))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }
}

private struct SupplementRow: View {
    let entry: SupplementEducationEntry

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.name)
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Text(entry.whatItIs)
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            EvidenceBadge(level: entry.evidenceLevel)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1)
        }
    }
}

private struct EvidenceBadge: View {
    let level: EvidenceLevel

    var body: some View {
        Text(level.displayName.uppercased())
            .font(.system(size: 8, weight: .semibold))
            .kerning(1.2)
            .foregroundStyle(CMSNColor.Semantic.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
    }
}

private struct SupplementDetailView: View {
    let entry: SupplementEducationEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(entry.name)
                        .font(CMSNTypography.displaySmall(30))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)

                    Text(entry.whatItIs)
                        .font(CMSNTypography.body())
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)

                    section(title: "May Help Support", lines: entry.mayHelpSupport)
                    section(title: "Common Forms", lines: entry.commonForms)

                    Text(entry.labelUseReminder)
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)

                    section(title: "Cautions", lines: entry.cautions)
                    section(title: "Consult A Professional If", lines: entry.consultProfessionalWhen)
                    section(title: "Sources", lines: entry.sourceReferences)

                    Text("Last reviewed \(entry.lastReviewed.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 11))
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)

                    Divider().overlay(CMSNColor.Semantic.divider)

                    Text(SupplementDisclaimer.footer)
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                .padding(24)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("Close") { dismiss() }
                .buttonStyle(.cmsnText)
                .padding(24)
        }
    }

    private func section(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: title)
            ForEach(lines, id: \.self) { line in
                Text("· \(line)")
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
            }
        }
    }
}

#Preview {
    SupplementLibraryView()
}
