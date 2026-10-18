import SwiftUI
import UIKit

struct RunShareCardView: View {
    let distance: String
    let pace: String
    let duration: String
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CMSNWordmark(height: 22, color: CMSNColor.offWhite)
            Text("CMSN PERFORMANCE")
                .font(CMSNTypography.eyebrow())
                .kerning(2.4)
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            Text(distance)
                .font(CMSNTypography.displaySmall(64))
                .foregroundStyle(CMSNColor.offWhite)
            Text(pace)
                .font(CMSNTypography.numeric(22))
                .foregroundStyle(CMSNColor.offWhite)
            Text(duration)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            Spacer()
            Text(date.formatted(date: .abbreviated, time: .omitted).uppercased())
                .font(CMSNTypography.eyebrow())
                .kerning(1.8)
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
            Text("EARN YOUR CMSN")
                .font(CMSNTypography.eyebrow())
                .kerning(2.6)
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
        .padding(32)
        .frame(width: 360, height: 480, alignment: .topLeading)
        .background(CMSNColor.offBlack)
    }
}

enum RunShareCardRenderer {
    @MainActor
    static func render(distance: String, pace: String, duration: String, date: Date) -> URL? {
        let view = RunShareCardView(distance: distance, pace: pace, duration: duration, date: date)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cmsn-run-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
