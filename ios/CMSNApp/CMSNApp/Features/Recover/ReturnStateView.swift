import SwiftUI

/// The Return loop's explicit UI: shown when the athlete has been away for
/// 7+ days. Deliberately reassuring, never a shame/streak-reset screen —
/// "you do not have to restart" is the actual doctrine line this implements.
struct ReturnStateView: View {
    let daysInactive: Int

    private var headline: String {
        switch daysInactive {
        case 7..<14: return "Good to see you back."
        case 14..<21: return "Welcome back."
        default: return "You're here. That's what matters."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "\(daysInactive) days away")
            Text(headline)
                .font(CMSNTypography.displaySmall(26))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            Text("You do not have to restart. Continue from where you are — today's session is scaled to make that easy.")
                .font(CMSNTypography.bodyQuiet())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
    }
}

#Preview {
    ZStack {
        CMSNColor.offBlack.ignoresSafeArea()
        ReturnStateView(daysInactive: 16).padding()
    }
}
