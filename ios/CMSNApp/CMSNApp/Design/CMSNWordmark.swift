import SwiftUI

/// The real CMSN wordmark — the exact path data used in
/// `public/brand/cmsn-lockup-*.svg` and `app/page.tsx`'s `<Wordmark>`
/// component on the marketing site, redrawn as native SwiftUI `Shape`s
/// instead of rasterizing the SVG. Same mark, same coordinate system
/// (a 344×100 viewBox), so it stays pixel-faithful to the site at any size —
/// chest-hit small or nav-bar tiny, per the "small CMSN is quiet" rule in
/// `brand/02-identity-and-logo.md`.
///
/// Two shapes because the source SVG uses two stroke styles: the four
/// letterforms use round caps/joins, the trailing "//" uses butt caps.
private enum WordmarkGeometry {
    static let viewBoxWidth: CGFloat = 344
    static let viewBoxHeight: CGFloat = 100

    static func scale(for rect: CGRect) -> (scale: CGFloat, dx: CGFloat, dy: CGFloat) {
        let scale = min(rect.width / viewBoxWidth, rect.height / viewBoxHeight)
        let dx = rect.minX + (rect.width - viewBoxWidth * scale) / 2
        let dy = rect.minY + (rect.height - viewBoxHeight * scale) / 2
        return (scale, dx, dy)
    }

    static func point(_ x: CGFloat, _ y: CGFloat, scale: CGFloat, dx: CGFloat, dy: CGFloat) -> CGPoint {
        CGPoint(x: x * scale + dx, y: y * scale + dy)
    }
}

/// The "CMSN" letterforms — round-capped strokes. Mirrors:
/// - `M58 10 H32 Q10 10 10 32 V68 Q10 90 32 90 H58` (C)
/// - `M82 90 L93 10 L108 62 L123 10 L134 90` (M)
/// - `M204 12 H178 Q160 12 160 30 Q160 47 178 49 L186 50 Q204 52 204 69 Q204 88 186 88 H160` (S)
/// - `M232 90 V10 L280 90 V10` (N)
struct CMSNWordmarkLettersShape: Shape {
    func path(in rect: CGRect) -> Path {
        let (s, dx, dy) = WordmarkGeometry.scale(for: rect)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { WordmarkGeometry.point(x, y, scale: s, dx: dx, dy: dy) }

        var path = Path()

        // C
        path.move(to: p(58, 10))
        path.addLine(to: p(32, 10))
        path.addQuadCurve(to: p(10, 32), control: p(10, 10))
        path.addLine(to: p(10, 68))
        path.addQuadCurve(to: p(32, 90), control: p(10, 90))
        path.addLine(to: p(58, 90))

        // M
        path.move(to: p(82, 90))
        path.addLine(to: p(93, 10))
        path.addLine(to: p(108, 62))
        path.addLine(to: p(123, 10))
        path.addLine(to: p(134, 90))

        // S
        path.move(to: p(204, 12))
        path.addLine(to: p(178, 12))
        path.addQuadCurve(to: p(160, 30), control: p(160, 12))
        path.addQuadCurve(to: p(178, 49), control: p(160, 47))
        path.addLine(to: p(186, 50))
        path.addQuadCurve(to: p(204, 69), control: p(204, 52))
        path.addQuadCurve(to: p(186, 88), control: p(204, 88))
        path.addLine(to: p(160, 88))

        // N
        path.move(to: p(232, 90))
        path.addLine(to: p(232, 10))
        path.addLine(to: p(280, 90))
        path.addLine(to: p(280, 10))

        return path
    }
}

/// The trailing "//" mark — butt-capped strokes. Mirrors:
/// `M290 90 L310 10` and `M314 90 L334 10`.
struct CMSNWordmarkSlashesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let (s, dx, dy) = WordmarkGeometry.scale(for: rect)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { WordmarkGeometry.point(x, y, scale: s, dx: dx, dy: dy) }

        var path = Path()
        path.move(to: p(290, 90))
        path.addLine(to: p(310, 10))
        path.move(to: p(314, 90))
        path.addLine(to: p(334, 10))
        return path
    }
}

/// Drop-in wordmark view. `height` behaves like the site's `<Wordmark
/// height={18} />` — pass the pixel height you want, width follows the
/// 344:100 aspect ratio automatically.
struct CMSNWordmark: View {
    var height: CGFloat = 18
    var color: Color = CMSNColor.offWhite

    private var strokeWidthRatio: CGFloat { 10.0 / 100.0 }

    var body: some View {
        let lineWidth = height * strokeWidthRatio
        ZStack {
            CMSNWordmarkLettersShape()
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            CMSNWordmarkSlashesShape()
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .miter))
        }
        .frame(width: height * (344.0 / 100.0), height: height)
        .accessibilityLabel("CMSN")
        .accessibilityAddTraits(.isImage)
    }
}

#Preview {
    VStack(spacing: 24) {
        CMSNWordmark(height: 20, color: .black)
        CMSNWordmark(height: 60, color: .white)
    }
    .padding(40)
    .background(CMSNColor.offBlack)
}
