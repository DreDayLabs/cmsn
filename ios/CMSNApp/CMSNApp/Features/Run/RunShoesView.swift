import SwiftData
import SwiftUI

struct RunShoesView: View {
    let athlete: Athlete
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RunShoe.createdAt, order: .reverse) private var shoes: [RunShoe]
    @Query private var runs: [Run]
    @State private var name = ""

    private var unit: RunDistanceUnit { athlete.unitPreference == .imperial ? .miles : .kilometers }
    private var mine: [RunShoe] { shoes.filter { $0.athleteID == athlete.id } }

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    EyebrowLabel(text: "Shoes")
                    Text("Mileage")
                        .font(CMSNTypography.displaySmall(40))
                        .foregroundStyle(CMSNColor.offWhite)
                    add
                    list
                    Text("A pair is marked soon at 80 percent of its distance, and due when it passes it. The default is 500 miles.")
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
                .padding(24)
            }
        }
        .navigationTitle("Shoes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var add: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name this pair", text: $name)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.offWhite)
                .padding(16)
                .cmsnCard()
                .accessibilityLabel("Shoe name")
            Button("Add pair") { addShoe() }
                .buttonStyle(.cmsnPrimary)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityHint("Saves this pair and starts its mileage at zero.")
        }
    }

    private var list: some View {
        VStack(spacing: 12) {
            if mine.isEmpty {
                Text("No shoes yet.")
                    .font(CMSNTypography.bodyQuiet())
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(mine, id: \.id) { shoe in
                shoeCard(shoe)
            }
        }
    }

    private func shoeCard(_ shoe: RunShoe) -> some View {
        let distance = mileage(for: shoe.id)
        let reminder = ShoeMileage.reminder(accumulatedMeters: distance, limitMeters: shoe.replacementDistanceMeters)
        let fraction = shoe.replacementDistanceMeters > 0 ? min(1, distance / shoe.replacementDistanceMeters) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(shoe.name)
                    .font(CMSNTypography.body())
                    .foregroundStyle(CMSNColor.offWhite)
                Spacer()
                if shoe.retiredAt != nil {
                    Text("Retired")
                        .font(CMSNTypography.caption())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
            }
            Text("\(RunMath.formatDistance(distance, unit: unit, places: 1)) \(unit.label)")
                .font(CMSNTypography.numeric(22))
                .foregroundStyle(CMSNColor.offWhite)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(CMSNColor.Semantic.border)
                    Rectangle().fill(CMSNColor.offWhite).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 3)
            Text(reminderText(reminder))
                .font(CMSNTypography.caption())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            if shoe.retiredAt == nil {
                Button("Retire") {
                    shoe.retiredAt = Date()
                    try? modelContext.save()
                }
                .buttonStyle(.cmsnText)
                .accessibilityHint("Stops new runs from using this pair. Its history stays.")
            }
        }
        .padding(16)
        .cmsnCard()
        .accessibilityElement(children: .combine)
    }

    private func mileage(for shoeID: UUID) -> Double {
        runs.filter { $0.shoeID == shoeID && $0.status == .ended }.reduce(0) { $0 + $1.distanceMeters }
    }

    private func reminderText(_ reminder: ShoeReminder) -> String {
        switch reminder {
        case .none: return "Inside the replacement window."
        case .soon: return "Coming up on replacement."
        case .due: return "Past the replacement distance."
        }
    }

    private func addShoe() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(RunShoe(athleteID: athlete.id, name: trimmed))
        try? modelContext.save()
        name = ""
    }
}
