import XCTest
@testable import CMSNApp

/// Locks the monochrome tokens to WCAG AA (4.5:1) for the pairs body copy,
/// captions, and buttons actually use. Dark pairs are what the app ships.
/// Light pairs are the specified alternate in `CMSNPalette` — measured so a
/// later light theme cannot ship a failing gray.
final class CMSNContrastTests: XCTestCase {
    func testBlackOnWhiteIsTheReferenceRatio() {
        let black = CMSNRGB(red: 0, green: 0, blue: 0)
        let white = CMSNRGB(red: 255, green: 255, blue: 255)
        XCTAssertEqual(CMSNContrast.ratio(foreground: black, on: white), 21, accuracy: 0.05)
        XCTAssertEqual(CMSNContrast.ratio(foreground: white, on: black), 21, accuracy: 0.05)
    }

    func testDarkTextPairsMeetAA() {
        let background = CMSNPalette.background
        let surface = CMSNPalette.surface
        let pressed = CMSNPalette.surfacePressed
        let primary = CMSNPalette.textPrimary
        let secondary = CMSNPalette.textSecondary
        assertPairs([
            (primary, background, "primary on background"),
            (primary, surface, "primary on surface"),
            (primary, pressed, "primary on pressed surface"),
            (secondary, background, "secondary on background"),
            (secondary, surface, "secondary on surface"),
            (secondary, pressed, "secondary on pressed surface"),
            (CMSNPalette.background, CMSNPalette.white, "button label on white"),
        ])
    }

    func testLightTextPairsMeetAA() {
        assertPairs([
            (CMSNPalette.lightTextPrimary, CMSNPalette.lightBackground, "light primary on background"),
            (CMSNPalette.lightTextPrimary, CMSNPalette.lightSurface, "light primary on surface"),
            (CMSNPalette.lightTextSecondary, CMSNPalette.lightBackground, "light secondary on background"),
            (CMSNPalette.lightTextSecondary, CMSNPalette.lightSurface, "light secondary on surface"),
            (CMSNPalette.lightButtonLabel, CMSNPalette.lightButtonFill, "light button label"),
        ])
    }

    func testPrimaryInkIsWhiteOnTrueBlack() {
        XCTAssertEqual(CMSNPalette.background, CMSNRGB(red: 0x00, green: 0x00, blue: 0x00))
        XCTAssertEqual(CMSNPalette.textPrimary, CMSNRGB(red: 0xFF, green: 0xFF, blue: 0xFF))
        XCTAssertEqual(CMSNPalette.white, CMSNRGB(red: 0xFF, green: 0xFF, blue: 0xFF))
        XCTAssertEqual(
            CMSNContrast.ratio(foreground: CMSNPalette.textPrimary, on: CMSNPalette.background),
            21,
            accuracy: 0.05
        )
    }

    func testSecondaryInkIsSolidGray() {
        XCTAssertEqual(
            CMSNPalette.textSecondary,
            CMSNRGB(red: 0xC8, green: 0xC8, blue: 0xC8),
            "Secondary type must stay a solid lighter gray, not a translucent wash."
        )
    }

    func testUnselectedEmphasisStillMeetsAA() {
        let blended = blend(CMSNPalette.textPrimary, alpha: CMSNEmphasis.unselected, on: CMSNPalette.background)
        let ratio = CMSNContrast.ratio(foreground: blended, on: CMSNPalette.background)
        XCTAssertGreaterThanOrEqual(ratio, CMSNContrast.normalTextAA, "Unselected emphasis was \(ratio)")
    }

    private func assertPairs(_ pairs: [(CMSNRGB, CMSNRGB, String)]) {
        for (foreground, background, name) in pairs {
            let ratio = CMSNContrast.ratio(foreground: foreground, on: background)
            XCTAssertGreaterThanOrEqual(
                ratio,
                CMSNContrast.normalTextAA,
                "\(name) was \(String(format: "%.2f", ratio)):1"
            )
        }
    }

    private func blend(_ foreground: CMSNRGB, alpha: Double, on background: CMSNRGB) -> CMSNRGB {
        func channel(_ ink: UInt8, _ paper: UInt8) -> UInt8 {
            UInt8((alpha * Double(ink) + (1 - alpha) * Double(paper)).rounded())
        }
        return CMSNRGB(
            red: channel(foreground.red, background.red),
            green: channel(foreground.green, background.green),
            blue: channel(foreground.blue, background.blue)
        )
    }
}
