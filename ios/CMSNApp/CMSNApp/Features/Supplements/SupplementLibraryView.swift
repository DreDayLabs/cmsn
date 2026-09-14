import SwiftUI
import SwiftData

/// A browsable, static education library — deliberately not a
/// recommendation flow. There is no "CMSN thinks you need X" path anywhere
/// in this screen; the athlete comes here to read, not to be told what to buy.
struct SupplementLibraryView: View {
    @State private var selectedEntry: SupplementEducationEntry?
    @State private var bankSearch = ""
    @State private var showingAddCustom = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomSupplement.createdAt, order: .reverse) private var customSupplements: [CustomSupplement]

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

                    bankSection
                    customSection

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
        .sheet(isPresented: $showingAddCustom) {
            AddCustomSupplementView { name, note in
                modelContext.insert(CustomSupplement(name: name, note: note))
                try? modelContext.save()
            }
        }
    }

    /// The bank: grouped by function, filtered by search. Function-first on
    /// purpose — grouping by demographic would read as "people like you
    /// should take these," which the disclaimer explicitly disclaims.
    private var bankSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                EyebrowLabel(text: "Supplement Bank")
                Text("\(SupplementBankData.totalCount) more, grouped by what they're for. Same rule as above: education, not prescription.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            TextField("Search the bank…", text: $bankSearch)
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .padding(12)
                .cmsnChip(isSelected: false)

            ForEach(filteredGroups) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name.uppercased())
                        .font(CMSNTypography.eyebrow())
                        .kerning(1.8)
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        .padding(.top, 8)
                    ForEach(group.entries) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            SupplementRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if filteredGroups.isEmpty && !bankSearch.isEmpty {
                Text("Nothing in the bank matches \"\(bankSearch)\" — add it below as your own entry if you take it.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
        }
        .padding(.top, 10)
    }

    private var filteredGroups: [SupplementBankGroup] {
        let query = bankSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return SupplementBankData.groups }
        return SupplementBankData.groups.compactMap { group in
            let hits = group.entries.filter {
                $0.name.lowercased().contains(query) || $0.whatItIs.lowercased().contains(query)
            }
            return hits.isEmpty ? nil : SupplementBankGroup(name: group.name, entries: hits)
        }
    }

    /// User-added entries: name + note only, no evidence badge — CMSN
    /// hasn't reviewed them, so they get no implied endorsement.
    private var customSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Your Supplements")
            ForEach(customSupplements) { supplement in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(supplement.name)
                            .font(CMSNTypography.body())
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        if !supplement.note.isEmpty {
                            Text(supplement.note)
                                .font(CMSNTypography.bodyQuiet())
                                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        }
                    }
                    Spacer()
                    Button {
                        modelContext.delete(supplement)
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    }
                }
                .padding(14)
                .cmsnCard()
            }
            Button("Add A Supplement") { showingAddCustom = true }
                .buttonStyle(.cmsnGhost)
        }
        .padding(.top, 10)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Education, not prescription")
            Text("Library")
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
            .font(CMSNTypography.micro())
            .kerning(1.4)
            .foregroundStyle(CMSNColor.Semantic.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .cmsnChip(isSelected: false)
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
                        .font(CMSNTypography.caption())
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

private struct AddCustomSupplementView: View {
    let onAdd: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var note = ""

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    EyebrowLabel(text: "Add A Supplement")
                    Spacer()
                    Button("Close") { dismiss() }.buttonStyle(.cmsnText)
                }
                .padding(.top, 20)

                Text("Track something you already take. Your entries get no evidence badge — CMSN hasn't reviewed them.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)

                TextField("Name", text: $name)
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .padding(12)
                    .cmsnChip(isSelected: false)
                TextField("Note (optional — brand, why, timing)", text: $note)
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .padding(12)
                    .cmsnChip(isSelected: false)

                Button("Add") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    onAdd(trimmed, note.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }
                .buttonStyle(.cmsnPrimary)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SupplementLibraryView()
}
