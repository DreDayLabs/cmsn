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
