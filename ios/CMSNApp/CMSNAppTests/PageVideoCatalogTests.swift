import XCTest
import UIKit
@testable import CMSNApp

final class PageVideoCatalogTests: XCTestCase {
    func testEachMainSurfaceHasADistinctBundledLoopAndStill() {
        let bundle = Bundle(for: PlayerLayerView.self)
        var movies: [String] = []
        var stills: [String] = []
        var sources: [String] = []

        for clip in CMSNPageClip.allCases {
            guard let url = bundle.url(forResource: clip.resourceName, withExtension: clip.resourceExtension) else {
                XCTFail("Missing \(clip.resourceName).mp4")
                continue
            }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            XCTAssertGreaterThan(size, 100_000, "\(clip.resourceName) is too small to be a film")
            XCTAssertNotNil(
                UIImage(named: clip.posterAssetName, in: bundle, compatibleWith: nil),
                "Missing still \(clip.posterAssetName)"
            )
            movies.append(clip.resourceName)
            stills.append(clip.posterAssetName)
            sources.append(clip.sourceFileName)
            XCTAssertTrue(clip.sourceFileName.hasPrefix("hf_20260827_"))
        }

        XCTAssertEqual(CMSNPageClip.allCases.count, 7)
        XCTAssertEqual(Set(movies).count, movies.count)
        XCTAssertEqual(Set(stills).count, stills.count)
        XCTAssertEqual(Set(sources).count, sources.count)
    }

    func testWelcomeEntranceUsesTheBeigeHoodieMaster() {
        let bundle = Bundle(for: PlayerLayerView.self)
        guard let url = bundle.url(forResource: CMSNVideo.welcomeName, withExtension: CMSNVideo.welcomeExtension) else {
            XCTFail("Missing welcome-loop.mp4")
            return
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        XCTAssertGreaterThan(size, 1_000_000)
        XCTAssertNotNil(UIImage(named: CMSNVideo.welcomePoster, in: bundle, compatibleWith: nil))
        XCTAssertEqual(
            CMSNVideo.welcomeSourceFileName,
            "hf_20260824_012218_31083458-b706-4164-b252-fa991253c09a.mp4"
        )
    }
}
