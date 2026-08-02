import SwiftUI
import Combine

/// A simple, self-contained rest-timer countdown. Starts automatically when
/// presented (a working set was just logged) and can be skipped — it never
/// blocks logging the next set.
struct RestTimerView: View {
    let totalSeconds: Int
    let onSkip: () -> Void

    @State private var remainingSeconds: Int
    @State private var cancellable: AnyCancellable?

    init(totalSeconds: Int, onSkip: @escaping () -> Void) {
        self.totalSeconds = totalSeconds
        self.onSkip = onSkip
        _remainingSeconds = State(initialValue: totalSeconds)
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(timeString)
                .font(CMSNTypography.numeric(24))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
            ProgressView(value: progress)
                .tint(CMSNColor.offWhite)
            Button("Skip") {
                onSkip()
            }
            .buttonStyle(.cmsnText)
        }
        .padding(16)
        .overlay(Rectangle().strokeBorder(CMSNColor.Semantic.divider, lineWidth: 1))
        .onAppear(perform: start)
        .onDisappear { cancellable?.cancel() }
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 1 }
        return 1 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    private var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func start() {
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if remainingSeconds > 0 {
                    remainingSeconds -= 1
                } else {
                    onSkip()
                }
            }
    }
}
