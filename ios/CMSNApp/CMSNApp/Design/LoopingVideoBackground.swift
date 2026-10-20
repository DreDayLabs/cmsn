import SwiftUI
import AVFoundation
import Combine

/// Silent, looping, chrome-less background video — no controls, no scrubber,
/// no audio. SwiftUI's `VideoPlayer` doesn't loop natively; `AVPlayerLooper`
/// is the documented gapless way to do it, but it must be retained for as
/// long as playback continues (a common gotcha) — held here on the
/// `Coordinator`, not as a local variable that would be deallocated
/// immediately after `makeUIView` returns.
struct LoopingVideoBackground: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String
    var isPlaying: Bool = true

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.attach(resourceName: resourceName, resourceExtension: resourceExtension, to: view)
        context.coordinator.setPlaying(isPlaying)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        context.coordinator.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ uiView: PlayerLayerView, coordinator: Coordinator) {
        coordinator.stop()
        uiView.playerLayer.player = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var looper: AVPlayerLooper?
        private var player: AVQueuePlayer?
        private var wantsPlayback = false
        private var observers: [NSObjectProtocol] = []

        func attach(resourceName: String, resourceExtension: String, to view: PlayerLayerView) {
            guard player == nil,
                  let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) else {
                return
            }
            CMSNAmbientAudio.prepareForSilentVideo()
            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            queue.volume = 0
            queue.actionAtItemEnd = .none
            queue.preventsDisplaySleepDuringVideoPlayback = false
            queue.allowsExternalPlayback = false
            queue.audiovisualBackgroundPlaybackPolicy = .pauses
            looper = AVPlayerLooper(player: queue, templateItem: item)
            player = queue
            view.playerLayer.player = queue
            observeAppActivity()
        }

        func setPlaying(_ playing: Bool) {
            wantsPlayback = playing
            apply()
        }

        func stop() {
            wantsPlayback = false
            player?.pause()
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            player = nil
            looper = nil
        }

        private func observeAppActivity() {
            let center = NotificationCenter.default
            let names: [Notification.Name] = [
                UIApplication.didEnterBackgroundNotification,
                UIApplication.willEnterForegroundNotification,
                UIApplication.didBecomeActiveNotification,
            ]
            for name in names {
                observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    self?.apply()
                })
            }
        }

        private func apply() {
            guard let player else { return }
            let foreground = UIApplication.shared.applicationState == .active
            if wantsPlayback && foreground {
                if player.timeControlStatus != .playing {
                    player.play()
                }
            } else {
                player.pause()
            }
        }
    }
}

/// Videos are muted and have no audio track. Ambient keeps them from
/// taking the playback session, so a user's music keeps playing. A run
/// cue already owns `.playback`; leave that category in place.
enum CMSNAmbientAudio {
    static func prepareForSilentVideo() {
        let session = AVAudioSession.sharedInstance()
        if session.category == .playback { return }
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)
    }
}

final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// The bundled welcome film. Onboarding and the in-session hero still
/// play this file. Main tabs use `CMSNPageClip`.
enum CMSNVideo {
    static let welcomeName = "welcome-loop"
    static let welcomeExtension = "mp4"
}

/// One emblem loop per main surface. The masters are the 27 Aug 2026
/// Seedance loops in `media/higgsfield/videos/`; the bundle files are
/// fast-start remuxes of those masters. No page-to-video document exists
/// in the repo, so each surface takes the emblem whose movement fits it.
enum CMSNPageClip: String, CaseIterable {
    case today
    case run
    case nutrition
    case score
    case library
    case settings
    case mealBuilder

    var resourceName: String {
        switch self {
        case .today: return "today-loop"
        case .run: return "run-loop"
        case .nutrition: return "nutrition-loop"
        case .score: return "score-loop"
        case .library: return "library-loop"
        case .settings: return "settings-loop"
        case .mealBuilder: return "meal-builder-loop"
        }
    }

    var resourceExtension: String { "mp4" }

    var posterAssetName: String { resourceName + "-poster" }

    /// Higgsfield filename under `media/higgsfield/videos/`. Not bundled.
    var sourceFileName: String {
        switch self {
        case .today:
            return "hf_20260827_154002_e6b78ec9-327b-4e84-92b6-3385038e355b.mp4"
        case .run:
            return "hf_20260827_154001_bd4d0fad-7285-41ce-a916-28fbb69f5d1f.mp4"
        case .nutrition:
            return "hf_20260827_160041_0890250b-a672-47e6-89a7-e80af5fe5727.mp4"
        case .score:
            return "hf_20260827_154001_15dff1dc-ad65-4394-bcb7-7522fc57c1b7.mp4"
        case .library:
            return "hf_20260827_154001_5c8331b0-e55f-4cb8-a9ec-d3fe75a27072.mp4"
        case .settings:
            return "hf_20260827_154001_d3165081-70f8-4ea1-a875-9979ff9d74ab.mp4"
        case .mealBuilder:
            return "hf_20260827_154001_997ef16c-ae01-4429-80b0-2e42442db87d.mp4"
        }
    }
}

/// Full-bleed page film. Plays only while `isActive` is true, the scene
/// is foreground, and the athlete has not asked for a still (Low Power
/// Mode or Reduce Motion). Otherwise the poster frame holds.
struct CMSNPageVideoBackground: View {
    let clip: CMSNPageClip
    var isActive: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var showsVideo: Bool {
        isActive && scenePhase == .active && !reduceMotion && !lowPower
    }

    var body: some View {
        Color.clear
            .overlay {
                ZStack {
                    CMSNColor.offBlack
                    if showsVideo {
                        LoopingVideoBackground(
                            resourceName: clip.resourceName,
                            resourceExtension: clip.resourceExtension,
                            isPlaying: true
                        )
                    } else {
                        Image(clip.posterAssetName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.82), location: 0),
                            .init(color: Color.black.opacity(0.48), location: 0.42),
                            .init(color: Color.black.opacity(0.62), location: 0.72),
                            .init(color: Color.black.opacity(0.88), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipped()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
    }
}

/// Rounded full-bleed video card. The picture fills the card; type sits
/// on a bottom gradient so it stays readable without a second panel.
/// Pass `playsVideo: false` when the page already has `CMSNPageVideoBackground`
/// so the card is a scrim over that one film.
struct CMSNVideoHero<Overlay: View>: View {
    var height: CGFloat
    var badge: String?
    var playsVideo: Bool = true
    var resourceName: String = CMSNVideo.welcomeName
    var resourceExtension: String = CMSNVideo.welcomeExtension
    @ViewBuilder var overlay: () -> Overlay

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if playsVideo {
                LoopingVideoBackground(
                    resourceName: resourceName,
                    resourceExtension: resourceExtension,
                    isPlaying: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.black.opacity(0.28)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.02),
                    Color.black.opacity(0.78),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if let badge {
                Text(badge)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CMSNColor.Semantic.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
            }

            overlay()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous))
    }
}
