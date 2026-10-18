import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var run: WatchRunController

    var body: some View {
        Group {
            if run.finished || run.phase == .ended {
                finished
            } else if run.remaining != nil || run.phase == .running || run.phase == .autoPaused || run.phase == .manualPaused {
                live
            } else {
                start
            }
        }
        .background(Color.black)
    }

    private var ink: Color {
        run.nightMode
            ? Color(red: 200 / 255, green: 200 / 255, blue: 200 / 255)
            : Color(red: 244 / 255, green: 244 / 255, blue: 244 / 255)
    }

    private var quiet: Color {
        Color(red: 138 / 255, green: 138 / 255, blue: 138 / 255)
    }

    private var start: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("CMSN Performance")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(quiet)
                Text("Run")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(ink)
                Picker("Where", selection: Binding(
                    get: { run.environment },
                    set: { run.environment = $0 }
                )) {
                    Text("Outdoor").tag(RunEnvironment.outdoor)
                    Text("Indoor").tag(RunEnvironment.indoor)
                }
                .accessibilityLabel("Indoor or outdoor")
                Picker("Countdown", selection: Binding(
                    get: { run.countdownSeconds },
                    set: { run.countdownSeconds = $0 }
                )) {
                    Text("3s").tag(3)
                    Text("6s").tag(6)
                    Text("9s").tag(9)
                }
                .accessibilityLabel("Countdown length")
                Button("Start") { run.start() }
                    .buttonStyle(.borderedProminent)
                    .tint(ink)
                    .foregroundStyle(.black)
                    .accessibilityHint("Starts the countdown, then the run.")
            }
            .padding(.horizontal, 4)
        }
    }

    private var live: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let remaining = run.remaining {
                Text("\(remaining)")
                    .font(.system(size: run.nightMode ? 54 : 46, weight: .medium, design: .rounded))
                    .foregroundStyle(ink)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Starting in \(remaining)")
            } else {
                HStack {
                    Button(run.nightMode ? "Day" : "Night") { run.toggleNight() }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(quiet)
                        .accessibilityLabel(run.nightMode ? "Night visibility on" : "Night visibility off")
                        .accessibilityHint("Dims the numbers for a dark street.")
                    Spacer()
                }
                Text(RunMath.formatDistance(run.distanceMeters, unit: .kilometers))
                    .font(.system(size: run.nightMode ? 40 : 34, weight: .medium, design: .rounded))
                    .foregroundStyle(ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("km · \(RunMath.formatDuration(run.movingSeconds))")
                    .font(.system(size: 13))
                    .foregroundStyle(quiet)
                Text(run.heartRate.map { "\(Int($0.rounded())) bpm" } ?? "Heart —")
                    .font(.system(size: 13))
                    .foregroundStyle(quiet)
                Button(run.phase == .running ? "Pause" : "Resume") { run.togglePause() }
                    .font(.system(size: 14, weight: .medium))
                    .accessibilityLabel(run.phase == .running ? "Pause run" : "Resume run")
                hold
            }
            if let statusMessage = run.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(quiet)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
    }

    private var hold: some View {
        HoldWatchButton { run.commitHold() }
    }

    private var finished: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Saved")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ink)
            Text(RunMath.formatDistance(run.distanceMeters, unit: .kilometers) + " km")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(ink)
            Text(run.statusMessage ?? "It syncs to the iPhone when the watch can reach it.")
                .font(.system(size: 12))
                .foregroundStyle(quiet)
            Button("New run") {
                run.finished = false
                run.phase = .ready
            }
            .accessibilityHint("Returns to the start screen. The finished run stays saved.")
        }
        .padding(.horizontal, 4)
    }
}

private struct HoldWatchButton: View {
    var onCommit: () -> Void
    @State private var holding = false
    @State private var committed = false

    var body: some View {
        Text(committed ? "Ending" : "Hold to end")
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(holding ? Color.white.opacity(0.16) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.7), lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !holding, !committed else { return }
                        holding = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            guard holding, !committed else { return }
                            committed = true
                            onCommit()
                        }
                    }
                    .onEnded { _ in
                        holding = false
                    }
            )
            .accessibilityLabel("End run")
            .accessibilityHint("Press and hold to end. A tap will not end the run.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "End run") {
                guard !committed else { return }
                committed = true
                onCommit()
            }
    }
}
