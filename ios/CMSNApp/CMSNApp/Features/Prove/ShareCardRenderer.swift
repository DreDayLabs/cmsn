import SwiftUI
import UIKit

/// The shareable accomplishment card — black/white, wordmark included,
/// no network call required (rendered entirely on-device via `ImageRenderer`).
struct ShareCardView: View {
    let focus: SplitFocus
    let setsCompleted: Int
    let totalScore: Double
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CMSNWordmark(height: 24, color: CMSNColor.offWhite)
            Text(focus.displayName.uppercased())
                .font(CMSNTypography.displaySmall(44))
                .foregroundStyle(CMSNColor.offWhite)
            Text("\(setsCompleted) sets logged")
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.offWhite.opacity(0.7))
            Text("+\(Int(totalScore)) CMSN Score")
                .font(CMSNTypography.numeric(20))
                .foregroundStyle(CMSNColor.offWhite)
            Spacer()
            Text(date.formatted(date: .abbreviated, time: .omitted).uppercased())
                .font(.system(size: 9, weight: .semibold))
                .kerning(1.6)
                .foregroundStyle(CMSNColor.offWhite.opacity(0.4))
            Text("EARN YOUR CMSN")
                .font(.system(size: 9, weight: .semibold))
                .kerning(2)
                .foregroundStyle(CMSNColor.offWhite.opacity(0.4))
        }
        .padding(32)
        .frame(width: 360, height: 480, alignment: .topLeading)
        .background(CMSNColor.offBlack)
    }
}

/// Renders `ShareCardView` to a `UIImage` on-device — no server round trip.
enum ShareCardRenderer {
    @MainActor
    static func renderImage(focus: SplitFocus, setsCompleted: Int, totalScore: Double, date: Date = Date()) -> UIImage? {
        let view = ShareCardView(focus: focus, setsCompleted: setsCompleted, totalScore: totalScore, date: date)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
