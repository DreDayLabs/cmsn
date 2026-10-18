import SwiftUI
import UIKit

/// In-run screen. The pace is set large enough to read with the phone at
/// arm's length. Back is hidden: the run ends only by holding the control.
struct LiveRunView: View {
    @Environment(AppState.self) private var appState

    private var session: RunSessionController { appState.runSession }

    var body: some View {
        ZStack {
            CMSNColor.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 28) {
                headline
                metrics
                Spacer(minLength: 12)
                if let note = session.permissionNote {
                    Text(note)
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                controls
            }
            .padding(24)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .background(PopGestureLock())
        .onAppear { _ = session.displayTick }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    session.preferences.paceHeadline = session.preferences.paceHeadline == .current ? .average : .current
                } label: {
                    EyebrowLabel(text: session.preferences.paceHeadline.title)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(session.preferences.paceHeadline == .current ? "Showing current pace" : "Showing average pace")
                .accessibilityHint("Switches the large number between current pace and average pace.")
                Spacer()
                EyebrowLabel(text: session.preferences.environment.title)
            }
            Text(session.headlinePaceText)
                .font(CMSNTypography.numeric(72, weight: .medium))
                .foregroundStyle(CMSNColor.offWhite)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel(spokenHeadline)
            Text(session.preferences.distanceUnit.paceSuffix)
                .font(CMSNTypography.body())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
    }

    private var metrics: some View {
        HStack(alignment: .top, spacing: 12) {
            metric("Distance", RunMath.formatDistance(session.distanceMeters, unit: session.preferences.distanceUnit), session.preferences.distanceUnit.label)
            metric("Time", RunMath.formatDuration(session.movingSeconds()), session.phase == .running ? "Moving" : "Paused")
            metric("Heart", session.heartRate.map { String(Int($0.rounded())) } ?? "—", "bpm")
        }
        .accessibilityElement(children: .combine)
    }

    private func metric(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowLabel(text: label)
            Text(value)
                .font(CMSNTypography.numeric(28))
                .foregroundStyle(CMSNColor.offWhite)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(unit)
                .font(CMSNTypography.caption())
                .foregroundStyle(CMSNColor.Semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button(session.phase == .running ? "Pause" : "Resume") {
                session.togglePause()
            }
            .buttonStyle(.cmsnGhost)
            .disabled(session.stage != .live)
            .accessibilityLabel(session.phase == .running ? "Pause run" : "Resume run")

            if session.stage == .live {
                HoldToEndControl { session.commitHoldToEnd() }
            } else if case .countdown(let remaining) = session.stage {
                Text("\(remaining)")
                    .font(CMSNTypography.numeric(64, weight: .medium))
                    .foregroundStyle(CMSNColor.offWhite)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Starting in \(remaining)")
                Button("Cancel") { session.cancelCountdown() }
                    .buttonStyle(.cmsnText)
                    .accessibilityHint("Cancels the countdown. The run has not started.")
            }
        }
    }

    private var spokenHeadline: String {
        let kind = session.preferences.paceHeadline.title
        let pace = session.headlinePaceText
        let distance = RunMath.formatDistance(session.distanceMeters, unit: session.preferences.distanceUnit)
        let time = RunMath.formatDuration(session.movingSeconds())
        return "\(kind) \(pace) per \(session.preferences.distanceUnit.label). Distance \(distance). Elapsed \(time)."
    }
}

/// Stops the interactive swipe-back that would leave a live run without
/// the hold-to-end control on screen. The session itself lives on AppState,
/// so a tab change does not end it either.
private struct PopGestureLock: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
