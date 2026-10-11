import SwiftUI
import AVFoundation

/// Silent, looping, chrome-less background video — no controls, no scrubber,
/// no audio. SwiftUI's `VideoPlayer` doesn't loop natively; `AVPlayerLooper`
/// is the documented gapless way to do it, but it must be retained for as
/// long as playback continues (a common gotcha) — held here on the
/// `Coordinator`, not as a local variable that would be deallocated
/// immediately after `makeUIView` returns.
struct LoopingVideoBackground: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) else {
            return view
        }
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        context.coordinator.looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        view.backgroundColor = .black
        view.playerLayer.player = queuePlayer
        view.playerLayer.videoGravity = .resizeAspectFill
        queuePlayer.play()
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var looper: AVPlayerLooper?
    }
}

final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// The one bundled Higgsfield loop. Welcome, Today, the session form
/// slot, and the workouts hero all play this file. Do not point them at
/// a second asset.
enum CMSNVideo {
    static let welcomeName = "welcome-loop"
    static let welcomeExtension = "mp4"
}

/// Rounded full-bleed video card. The picture fills the card; type sits
/// on a bottom gradient so it stays readable without a second panel.
struct CMSNVideoHero<Overlay: View>: View {
    var height: CGFloat
    var badge: String?
    @ViewBuilder var overlay: () -> Overlay

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LoopingVideoBackground(
                resourceName: CMSNVideo.welcomeName,
                resourceExtension: CMSNVideo.welcomeExtension
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
