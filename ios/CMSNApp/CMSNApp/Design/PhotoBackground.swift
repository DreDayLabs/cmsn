import SwiftUI

/// Full-bleed background photo that never influences layout.
///
/// `Image.resizable().aspectRatio(contentMode: .fill)` reports the *scaled*
/// size, which for a portrait photo on a taller phone screen is wider than the
/// display. Dropping one straight into a `ZStack` therefore makes the stack
/// itself wider than the screen, and leading-aligned content gets pushed off
/// the left edge. `.clipped()` hides the overflow drawing but does not undo
/// the layout, which is why it looks fine in a static preview and clips on
/// device.
///
/// Pinning the image to the container's exact bounds inside a `GeometryReader`
/// keeps it purely decorative — the same role `LoopingVideoBackground` plays
/// on the welcome screen, which is why that one never had this problem.
struct PhotoBackground: View {
    let imageName: String
    var height: CGFloat? = nil

    var body: some View {
        GeometryReader { geo in
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .frame(height: height)
    }
}
