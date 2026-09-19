import SwiftUI

/// CMSN identity — Revision 02. Founder-approved 2026-09-14 ("this is perfect").
///
/// The same geometry the marketing site renders from `lib/brand-mark.ts`, which
/// is itself lifted verbatim from `brand/identity/revision-02/` and verified
/// against `brand/identity/revision-02/revision-spec.json`:
///
/// - N visible y      -175.3261 .. 1175.3179
/// - slash visible y  -202.3390 .. 1202.3308  (104% of the N's visible height)
/// - external gap     650 cap-height units from the N
/// - stroke width     174.33u  (= one unit of clear space)
///
/// Revision 02 is **filled outline** artwork, not a stroked monoline. The
/// previous implementation in this file redrew a stroked 344x100 approximation
/// that was never the approved mark; it has been removed.
///
/// Coordinates below are unit-space (0...1) against the **framed** artboard —
/// the ink plus the approved 220-unit clear space on all four sides. That makes
/// `height` mean exactly what `<Wordmark height={…} />` means in the browser,
/// so a spec written for one platform transfers to the other unchanged.
///
/// This code is generated from the approved masters. Do not hand-edit the
/// coordinates: regenerate from `brand/identity/revision-02/` instead.
///
/// Rejected and unavailable by founder decision: the spelled-out COMMISSION
/// display wordmark, and any stacked or vertical lockup.
private enum CMSNMarkGeometry {
    /// Framed lockup artboard: 9522.4447 x 1844.6698 cap-height units.
    static let lockupAspect: CGFloat = 5.162141
    /// Standalone symbol, tight ink box: 70.9946 x 91.9997 units.
    static let symbolAspect: CGFloat = 0.771683

    /// Aspect-fit a unit-space mark into `rect`, centred.
    static func projector(for rect: CGRect, aspect: CGFloat) -> (CGFloat, CGFloat) -> CGPoint {
        let drawn = CGSize(
            width: min(rect.width, rect.height * aspect),
            height: min(rect.height, rect.width / aspect)
        )
        let originX = rect.minX + (rect.width - drawn.width) / 2
        let originY = rect.minY + (rect.height - drawn.height) / 2
        return { u, v in
            CGPoint(x: originX + u * drawn.width, y: originY + v * drawn.height)
        }
    }
}

/// The horizontal CMSN// lockup — the primary mark. Filled, not stroked.
struct CMSNLockupShape: Shape {
    func path(in rect: CGRect) -> Path {
        let p = CMSNMarkGeometry.projector(for: rect, aspect: CMSNMarkGeometry.lockupAspect)
        var path = Path()

        // C
        path.move(to: p(0.192670, 0.771049))
        path.addLine(to: p(0.051042, 0.771049))
        path.addCurve(to: p(0.023103, 0.626827), control1: p(0.033551, 0.771049), control2: p(0.023103, 0.717116))
        path.addLine(to: p(0.023103, 0.368238))
        path.addCurve(to: p(0.053934, 0.229011), control1: p(0.023103, 0.326343), control2: p(0.026112, 0.229011))
        path.addLine(to: p(0.192670, 0.229011))
        path.addLine(to: p(0.192670, 0.323514))
        path.addLine(to: p(0.053934, 0.323514))
        path.addCurve(to: p(0.041410, 0.368298), control1: p(0.041410, 0.323514), control2: p(0.041410, 0.348314))
        path.addLine(to: p(0.041410, 0.626887))
        path.addCurve(to: p(0.051042, 0.676606), control1: p(0.041410, 0.665471), control2: p(0.043567, 0.676606))
        path.addLine(to: p(0.192670, 0.676606))
        path.addLine(to: p(0.192670, 0.771109))
        path.closeSubpath()

        // M
        path.move(to: p(0.406558, 0.771049))
        path.addLine(to: p(0.388251, 0.771049))
        path.addLine(to: p(0.388251, 0.358005))
        path.addCurve(to: p(0.387621, 0.361075), control1: p(0.388041, 0.359028), control2: p(0.387831, 0.360051))
        path.addCurve(to: p(0.380450, 0.396649), control1: p(0.385219, 0.372752), control2: p(0.382736, 0.384851))
        path.addCurve(to: p(0.380240, 0.397672), control1: p(0.380380, 0.397010), control2: p(0.380310, 0.397371))
        path.addLine(to: p(0.322054, 0.679375))
        path.addCurve(to: p(0.309484, 0.679134), control1: p(0.318521, 0.696530), control2: p(0.313006, 0.696410))
        path.addLine(to: p(0.252068, 0.397431))
        path.addCurve(to: p(0.244687, 0.361315), control1: p(0.249456, 0.384911), control2: p(0.246984, 0.372872))
        path.addLine(to: p(0.244687, 0.770989))
        path.addLine(to: p(0.226380, 0.770989))
        path.addLine(to: p(0.226380, 0.228891))
        path.addCurve(to: p(0.234088, 0.182241), control1: p(0.226380, 0.205656), control2: p(0.229645, 0.185913))
        path.addCurve(to: p(0.244232, 0.214144), control1: p(0.238519, 0.178569), control2: p(0.242822, 0.192113))
        path.addCurve(to: p(0.264603, 0.328570), control1: p(0.244757, 0.221668), control2: p(0.247789, 0.247972))
        path.addLine(to: p(0.315839, 0.579936))
        path.addLine(to: p(0.367612, 0.329233))
        path.addCurve(to: p(0.375051, 0.292334), control1: p(0.370049, 0.316712), control2: p(0.372591, 0.304313))
        path.addCurve(to: p(0.388566, 0.216431), control1: p(0.380077, 0.267896), control2: p(0.387656, 0.230937))
        path.addCurve(to: p(0.398605, 0.182061), control1: p(0.389767, 0.193558), control2: p(0.394058, 0.178931))
        path.addCurve(to: p(0.406546, 0.228951), control1: p(0.403153, 0.185191), control2: p(0.406546, 0.205295))
        path.addLine(to: p(0.406546, 0.771049))
        path.closeSubpath()

        // S
        path.move(to: p(0.598279, 0.771049))
        path.addLine(to: p(0.435452, 0.771049))
        path.addLine(to: p(0.435452, 0.676546))
        path.addLine(to: p(0.598279, 0.676546))
        path.addCurve(to: p(0.602127, 0.631762), control1: p(0.599993, 0.676546), control2: p(0.602127, 0.676546))
        path.addLine(to: p(0.602127, 0.576325))
        path.addCurve(to: p(0.530497, 0.547131), control1: p(0.590117, 0.558508), control2: p(0.554762, 0.551766))
        path.addCurve(to: p(0.444268, 0.487781), control1: p(0.477244, 0.537019), control2: p(0.453002, 0.528351))
        path.addCurve(to: p(0.441236, 0.452628), control1: p(0.442332, 0.478812), control2: p(0.441236, 0.466051))
        path.addLine(to: p(0.441236, 0.323334))
        path.addCurve(to: p(0.468218, 0.228831), control1: p(0.441236, 0.288061), control2: p(0.444746, 0.228831))
        path.addLine(to: p(0.630077, 0.228831))
        path.addLine(to: p(0.630077, 0.323334))
        path.addLine(to: p(0.468218, 0.323334))
        path.addCurve(to: p(0.459543, 0.328751), control1: p(0.463158, 0.323334), control2: p(0.460639, 0.326644))
        path.addLine(to: p(0.459543, 0.423495))
        path.addCurve(to: p(0.531173, 0.452688), control1: p(0.471553, 0.441312), control2: p(0.506908, 0.448053))
        path.addCurve(to: p(0.617402, 0.512039), control1: p(0.584427, 0.462801), control2: p(0.608669, 0.471469))
        path.addCurve(to: p(0.620434, 0.547191), control1: p(0.619338, 0.521007), control2: p(0.620434, 0.533768))
        path.addLine(to: p(0.620434, 0.631762))
        path.addCurve(to: p(0.615420, 0.728613), control1: p(0.620434, 0.673115), control2: p(0.618790, 0.704777))
        path.addCurve(to: p(0.598268, 0.770989), control1: p(0.612692, 0.747935), control2: p(0.607491, 0.770989))
        path.closeSubpath()

        // N
        path.move(to: p(0.816015, 0.866094))
        path.addLine(to: p(0.677279, 0.323996))
        path.addLine(to: p(0.677279, 0.771049))
        path.addLine(to: p(0.658972, 0.771049))
        path.addLine(to: p(0.658972, 0.133906))
        path.addLine(to: p(0.797708, 0.676004))
        path.addLine(to: p(0.797708, 0.228951))
        path.addLine(to: p(0.816015, 0.228951))
        path.addLine(to: p(0.816015, 0.866094))
        path.closeSubpath()

        // First slash
        path.move(to: p(0.884275, 0.860455))
        path.addLine(to: p(0.923434, 0.119263))
        path.addLine(to: p(0.937841, 0.139545))
        path.addLine(to: p(0.898682, 0.880737))
        path.closeSubpath()

        // Second slash
        path.move(to: p(0.923331, 0.860455))
        path.addLine(to: p(0.962490, 0.119263))
        path.addLine(to: p(0.976897, 0.139545))
        path.addLine(to: p(0.937738, 0.880737))
        path.closeSubpath()

        return path
    }
}

/// The standalone `//` symbol — the apparel-led mark, geometry unchanged from
/// the approved masters. Drawn to the tight ink box; clear space is the
/// caller's responsibility.
struct CMSNSymbolShape: Shape {
    func path(in rect: CGRect) -> Path {
        let p = CMSNMarkGeometry.projector(for: rect, aspect: CMSNMarkGeometry.symbolAspect)
        var path = Path()

        path.move(to: p(0.000000, 0.962580))
        path.addLine(to: p(0.340295, 0.000038))
        path.addLine(to: p(0.518038, 0.037458))
        path.addLine(to: p(0.177743, 1.000000))
        path.closeSubpath()

        path.move(to: p(0.481962, 0.962542))
        path.addLine(to: p(0.822257, 0.000000))
        path.addLine(to: p(1.000000, 0.037420))
        path.addLine(to: p(0.659705, 0.999962))
        path.closeSubpath()

        return path
    }
}

/// Drop-in lockup view. `height` is the framed height — ink plus the approved
/// clear space — exactly as on the site, so the mark needs no extra padding.
///
/// Note the aspect change from the mark this replaced: Revision 02 is an
/// extended horizontal lockup at roughly 5.16:1 framed, where the old stroked
/// approximation was 3.44:1. At the same `height` it is materially wider.
/// In tight horizontal space, prefer `CMSNSymbol`.
struct CMSNWordmark: View {
    var height: CGFloat = 18
    var color: Color = CMSNColor.offWhite

    var body: some View {
        CMSNLockupShape()
            .fill(color)
            .frame(width: height * CMSNMarkGeometry.lockupAspect, height: height)
            .accessibilityLabel("CMSN")
            .accessibilityAddTraits(.isImage)
    }
}

/// Standalone `//` symbol view. `revision-spec.json` selects 32pt as the small
/// digital symbol presentation — a screen decision only, never an embroidery or
/// print minimum.
struct CMSNSymbol: View {
    var height: CGFloat = 32
    var color: Color = CMSNColor.offWhite

    var body: some View {
        CMSNSymbolShape()
            .fill(color)
            .frame(width: height * CMSNMarkGeometry.symbolAspect, height: height)
            .accessibilityLabel("CMSN")
            .accessibilityAddTraits(.isImage)
    }
}

#Preview {
    VStack(spacing: 24) {
        CMSNWordmark(height: 20, color: .black)
        CMSNWordmark(height: 60, color: .white)
        CMSNSymbol(height: 32, color: .white)
    }
    .padding(40)
    .background(CMSNColor.offBlack)
}
