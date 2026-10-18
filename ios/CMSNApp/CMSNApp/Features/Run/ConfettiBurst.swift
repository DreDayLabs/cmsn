import SwiftUI

/// White paper on black. No chromatic confetti. Skipped entirely when
/// Reduce Motion is on; the haptic still fires from the summary.
struct ConfettiBurst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = false

    var body: some View {
        if reduceMotion {
            Color.clear.allowsHitTesting(false)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    guard started else { return }
                    for index in 0..<48 {
                        let seed = Double(index)
                        let x = fraction(seed * 12.3) * size.width
                        let fall = (time * 90 + seed * 37).truncatingRemainder(dividingBy: size.height + 40)
                        let y = fall - 20
                        let rect = CGRect(x: x, y: y, width: 3 + fraction(seed) * 4, height: 8)
                        let alpha = 0.35 + fraction(seed * 3) * 0.65
                        context.fill(Path(rect), with: .color(Color.white.opacity(alpha)))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { started = true }
        }
    }

    private func fraction(_ value: Double) -> Double {
        let raw = sin(value) * 43758.5453
        return raw - floor(raw)
    }
}
