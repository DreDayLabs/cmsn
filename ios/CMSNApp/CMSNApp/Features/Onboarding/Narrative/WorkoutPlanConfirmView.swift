import SwiftUI

/// Closing capstone of the first-run narrative's workout section. Not a
/// second data-collection form — `TrainingProfileStepView` already asked for
/// session length and weekly frequency during profile intake. This screen
/// confirms/lets them adjust those two fields with a friendlier picker,
/// writes any change straight back to the `Athlete`, and reiterates that the
/// plan adapts monthly from data already on file (weight, goal weight, body
/// composition target) rather than asking for it again.
struct WorkoutPlanConfirmView: View {
    let athlete: Athlete
    let onContinue: () -> Void

    private static let durationOptions = [15, 30, 45, 60, 90]
    /// `1` doubles as "just today" — the model has no separate one-off
    /// flag, and framing a single session as "1x" is honest, not a stretch.
    private static let frequencyOptions = [1, 2, 3, 4, 5, 6, 7]

    @State private var duration: Int
    @State private var frequency: Int

    init(athlete: Athlete, onContinue: @escaping () -> Void) {
        self.athlete = athlete
        self.onContinue = onContinue
        _duration = State(initialValue: Self.nearest(to: athlete.preferredSessionLengthMinutes, in: Self.durationOptions))
        _frequency = State(initialValue: min(max(athlete.trainingFrequencyPerWeek, 1), 7))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                PhotoBackground(imageName: "WorkoutBuilder", height: 260)

                LinearGradient(
                    colors: [
                        .clear,
                        CMSNColor.offBlack.opacity(0.25),
                        CMSNColor.offBlack.opacity(0.85),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)

                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "Build Your Week")
                    Text("BUILD YOUR\nWEEK.")
                        .font(CMSNTypography.display(38))
                        .lineSpacing(-4)
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 18)
            }
            .ignoresSafeArea(edges: .top)

            section(title: "Session Length (min)") {
                pillRow(Self.durationOptions, selected: duration, label: { "\($0)" }) { duration = $0 }
            }

            section(title: "Days Per Week") {
                pillRow(Self.frequencyOptions, selected: frequency, label: { $0 == 1 ? "Just today" : "\($0)x" }) { frequency = $0 }
            }

            Text("Your plan adjusts monthly based on weight, goal weight, and body composition target — set in your profile.")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .frame(maxWidth: 300, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 30)

            Spacer()

            Button("Build My Plan", action: save)
                .buttonStyle(.cmsnPrimary)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(CMSNColor.offBlack.ignoresSafeArea())
    }

    private func save() {
        athlete.preferredSessionLengthMinutes = duration
        athlete.trainingFrequencyPerWeek = frequency
        onContinue()
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel(text: title)
            content()
        }
        .padding(.horizontal, 32)
        .padding(.top, 34)
    }

    private func pillRow(_ values: [Int], selected: Int, label: @escaping (Int) -> String, onPick: @escaping (Int) -> Void) -> some View {
        FlowLayout(spacing: 10) {
            ForEach(values, id: \.self) { value in
                Button {
                    onPick(value)
                } label: {
                    Text(label(value))
                        .font(CMSNTypography.body())
                        .padding(.vertical, 11)
                        .padding(.horizontal, 16)
                        .foregroundStyle(value == selected ? CMSNColor.offBlack : CMSNColor.Semantic.textPrimary)
                        .background(value == selected ? CMSNColor.offWhite : Color.clear)
                        .overlay(Rectangle().strokeBorder(value == selected ? CMSNColor.offWhite : CMSNColor.offWhite.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private static func nearest(to value: Int, in options: [Int]) -> Int {
        options.min(by: { abs($0 - value) < abs($1 - value) }) ?? options[options.count / 2]
    }
}

/// A genuine wrapping flow layout (unlike `FlowToggleGrid`'s equal-width
/// grid cells, these pills size to their own content and wrap left-to-right,
/// top-to-bottom). `Layout` conformance instead of an `alignmentGuide` hack
/// so multi-line wrapping actually offsets the Y axis, not just X.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > width, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: width.isFinite ? width : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    WorkoutPlanConfirmView(athlete: Athlete(age: 28, heightCM: 178, weightKG: 82), onContinue: {})
}
