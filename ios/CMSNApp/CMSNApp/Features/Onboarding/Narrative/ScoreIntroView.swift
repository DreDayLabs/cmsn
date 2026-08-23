import SwiftUI

/// Closing screen of the first-run narrative — introduces the CMSN Score
/// honestly. A brand-new athlete has no `ScoreEvent`s yet, so this
/// deliberately shows a real (empty) `ScoreCalculator` result rather than a
/// fabricated "sample" score: the ring starts at zero and fills as the
/// athlete actually earns it, matching "earned, not given."
struct ScoreIntroView: View {
    let onFinish: () -> Void

    @State private var animateIn = false
    private let breakdown = ScoreCalculator.compositeScore(from: [])

    var body: some View {
        ZStack {
            Image("Score")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    CMSNColor.offBlack.opacity(0.45),
                    CMSNColor.offBlack.opacity(0.62),
                    CMSNColor.offBlack.opacity(0.85),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            content
        }
        .onAppear { animateIn = true }
    }

    private var content: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                EyebrowLabel(text: "Your Score")
                Text("REAL WORK\nKEEPS SCORE.")
                    .font(CMSNTypography.display(26))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 70)

            ZStack {
                Circle()
                    .stroke(CMSNColor.Semantic.divider, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: animateIn ? CGFloat(breakdown.total) / 100 : 0)
                    .stroke(CMSNColor.offWhite, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.1).delay(0.2), value: animateIn)

                VStack(spacing: 4) {
                    Text("\(Int(breakdown.total))")
                        .font(CMSNTypography.numeric(52))
                        .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    Text("EARN IT.")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.4)
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                }
            }
            .frame(width: 180, height: 180)
            .padding(.top, 30)

            VStack(spacing: 0) {
                dimensionRow(title: "Work", weight: ScoreWeights.work)
                dimensionRow(title: "Consistency", weight: ScoreWeights.consistency)
                dimensionRow(title: "Progress", weight: ScoreWeights.progress)
                dimensionRow(title: "Discipline & Recovery", weight: ScoreWeights.disciplineAndRecovery)
            }
            .padding(.horizontal, 32)
            .padding(.top, 34)

            Spacer()

            Text("Earned, not given.")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
                .padding(.bottom, 18)

            Button("Enter the App", action: onFinish)
                .buttonStyle(.cmsnPrimary)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }

    private func dimensionRow(title: String, weight: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1)
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                Spacer()
                Text("\(Int(weight * 100))%")
                    .font(.system(size: 11))
                    .foregroundStyle(CMSNColor.Semantic.textSecondary)
            }
            Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 3)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(CMSNColor.Semantic.divider).frame(height: 1)
        }
    }
}

#Preview {
    ScoreIntroView(onFinish: {})
}
