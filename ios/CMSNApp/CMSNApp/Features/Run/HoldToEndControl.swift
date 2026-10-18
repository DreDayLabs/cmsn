import SwiftUI

/// Ends a run only after a continuous hold. A tap resets the bar and does
/// not finish anything. VoiceOver gets an explicit action because a hold
/// is not available there; that action is labeled as ending the run.
struct HoldToEndControl: View {
    var duration: TimeInterval = 1.2
    var onCommit: () -> Void

    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var committed = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Hold to end")
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            GeometryReader { geo in
                Rectangle()
                    .fill(CMSNColor.offWhite)
                    .frame(width: max(0, geo.size.width * progress), height: 3)
            }
            .frame(height: 3)
        }
        .background(CMSNColor.Semantic.surface)
        .overlay(
            RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                .strokeBorder(CMSNColor.Semantic.textPrimary, lineWidth: CMSNSpacing.hairline)
        )
        .contentShape(Rectangle())
        .gesture(hold)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("End run")
        .accessibilityHint("Press and hold to end the run. A short tap will not end it.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "End run") {
            guard !committed else { return }
            committed = true
            onCommit()
        }
    }

    private var hold: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !holding, !committed else { return }
                holding = true
                withAnimation(.linear(duration: duration)) { progress = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    guard holding, !committed else { return }
                    committed = true
                    onCommit()
                }
            }
            .onEnded { _ in
                holding = false
                if !committed {
                    withAnimation(.easeOut(duration: 0.12)) { progress = 0 }
                }
            }
    }
}
