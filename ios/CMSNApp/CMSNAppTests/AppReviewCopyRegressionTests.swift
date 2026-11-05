import XCTest

/// Fails if pre-launch or clothing copy returns in strings the iOS app,
/// watch app, or shared sources can show. Comments are ignored. String
/// literals are the scanning surface, including permission-prompt strings
/// in each target's Info.plist.
///
/// The lists below are the contract. Add a phrase here when a draft label
/// is removed, instead of relying on someone to remember it.
final class AppReviewCopyRegressionTests: XCTestCase {
    /// Case-insensitive substrings. Longer than a single common word so
    /// "Coming Back" and "the next session is soon" stay legal.
    static let bannedPhrases = [
        "background video",
        "form video",
        "nothing is billed",
        "coming soon",
        "lorem",
        "placeholder",
        "cmsn compression",
        "not in this release",
        "future update",
        "your gear",
        "the gear",
        "how'd the gear",
        "how the gear",
        "instructional video library",
        "cloud backup",
        "cross-device sync",
    ]

    /// Case-insensitive whole words. Short tokens are bounded so "swipe"
    /// is not "wip" and a stored property name is not a label.
    static let bannedWords = [
        "todo",
        "wip",
        "inventory",
        "gear",
        "merch",
        "apparel",
        "clothing",
        "moris",
        "morris",
        "storefront",
    ]

    /// A string whose entire trimmed contents are this label.
    static let bannedExactLabels = [
        "video",
    ]

    func testShippedCopyDoesNotContainBannedPhrases() throws {
        let files = try Self.shippedSourceFiles()
        XCTAssertGreaterThanOrEqual(files.count, 80, "Source root was not found. Refusing to pass an empty scan.")

        var hits: [String] = []
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            let literals = url.lastPathComponent == "Info.plist"
                ? Self.plistStrings(in: text)
                : Self.stringLiterals(in: text)
            for literal in Self.violations(in: literals) {
                let preview = literal.replacingOccurrences(of: "\n", with: " ")
                let clipped = preview.count > 140 ? String(preview.prefix(140)) + "…" : preview
                hits.append("\(url.path): \(clipped)")
            }
        }

        XCTAssertTrue(
            hits.isEmpty,
            "Banned copy is back in user-facing sources:\n" + hits.joined(separator: "\n")
        )
    }

    func testScannerIgnoresCommentsAndCatchesLiterals() {
        let sample = #"""
        // "coming soon" in a comment
        /* "lorem ipsum" in a block comment */
        let title = "Background video"
        let minutes = "\(count) min"
        let exact = "Video"
        let kept = "Coming Back"
        """#
        let literals = Self.stringLiterals(in: sample)
        XCTAssertTrue(literals.contains("Background video"))
        XCTAssertTrue(literals.contains("Video"))
        XCTAssertTrue(literals.contains("Coming Back"))
        XCTAssertTrue(literals.contains(" min"))
        XCTAssertFalse(literals.contains { $0.localizedCaseInsensitiveContains("coming soon") })
        XCTAssertFalse(literals.contains { $0.localizedCaseInsensitiveContains("lorem") })

        let violations = Self.violations(in: literals)
        XCTAssertTrue(violations.contains("Background video"))
        XCTAssertTrue(violations.contains("Video"))
        XCTAssertFalse(violations.contains("Coming Back"))
        XCTAssertFalse(violations.contains(" min"))
    }

    /// Required-reason audit for this sweep. UserDefaults CA92.1 is the
    /// existing app-only reason. File timestamp, boot time, disk space,
    /// and active keyboards are not declared because the app does not use them.
    func testPrivacyManifestsDeclareOnlyTheAuditedReason() throws {
        let projectRoot = try Self.projectRoot()
        let manifests = [
            projectRoot.appendingPathComponent("CMSNApp/PrivacyInfo.xcprivacy"),
            projectRoot.appendingPathComponent("CMSNWatchApp/PrivacyInfo.xcprivacy"),
        ]
        let absent = [
            "NSPrivacyAccessedAPICategoryFileTimestamp",
            "NSPrivacyAccessedAPICategorySystemBootTime",
            "NSPrivacyAccessedAPICategoryDiskSpace",
            "NSPrivacyAccessedAPICategoryActiveKeyboards",
        ]
        for url in manifests {
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertTrue(text.contains("NSPrivacyAccessedAPICategoryUserDefaults"), url.path)
            XCTAssertTrue(text.contains("CA92.1"), url.path)
            for category in absent {
                XCTAssertFalse(text.contains(category), "\(url.lastPathComponent) declares \(category)")
            }
        }
    }

    // MARK: - Scanning

    static func violations(in literals: [String]) -> [String] {
        literals.filter { literal in
            let folded = literal.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            if bannedExactLabels.contains(where: { folded.trimmingCharacters(in: .whitespacesAndNewlines) == $0 }) {
                return true
            }
            if bannedPhrases.contains(where: { folded.contains($0) }) {
                return true
            }
            return bannedWords.contains { containsWord($0, in: folded) }
        }
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func shippedSourceFiles() throws -> [URL] {
        let projectRoot = try projectRoot()
        let roots = ["CMSNApp", "CMSNWatchApp", "Shared"].map { projectRoot.appendingPathComponent($0) }
        let fileManager = FileManager.default
        var files: [URL] = []
        for root in roots {
            guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) else {
                XCTFail("Missing source root \(root.path)")
                continue
            }
            for case let url as URL in enumerator {
                if url.pathExtension == "swift" || url.lastPathComponent == "Info.plist" {
                    files.append(url)
                }
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func projectRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        // CMSNAppTests/this file -> ios/CMSNApp
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        let app = url.appendingPathComponent("CMSNApp")
        guard FileManager.default.fileExists(atPath: app.path) else {
            throw ScanError.missingRoot(url.path)
        }
        return url
    }

    private static func plistStrings(in text: String) -> [String] {
        var values: [String] = []
        var rest = text[...]
        while let open = rest.range(of: "<string>") {
            rest = rest[open.upperBound...]
            guard let close = rest.range(of: "</string>") else { break }
            values.append(String(rest[..<close.lowerBound]))
            rest = rest[close.upperBound...]
        }
        return values
    }

    /// Swift string literals, with comments removed and interpolations
    /// scanned only for nested literals. The interpolation expression
    /// itself is code, not copy.
    static func stringLiterals(in source: String) -> [String] {
        let characters = Array(source)
        var index = 0
        var literals: [String] = []

        func peek(_ offset: Int) -> Character? {
            let next = index + offset
            return next < characters.count ? characters[next] : nil
        }

        while index < characters.count {
            let character = characters[index]
            if character == "/", peek(1) == "/" {
                index += 2
                while index < characters.count, characters[index] != "\n" { index += 1 }
                continue
            }
            if character == "/", peek(1) == "*" {
                index += 2
                while index + 1 < characters.count, !(characters[index] == "*" && characters[index + 1] == "/") {
                    index += 1
                }
                index = min(index + 2, characters.count)
                continue
            }
            if character == "\"", peek(1) == "\"", peek(2) == "\"" {
                index += 3
                var literal = ""
                while index + 2 < characters.count, !(characters[index] == "\"" && characters[index + 1] == "\"" && characters[index + 2] == "\"") {
                    literal.append(characters[index])
                    index += 1
                }
                index = min(index + 3, characters.count)
                literals.append(literal)
                continue
            }
            if character == "\"" {
                index += 1
                var literal = ""
                while index < characters.count {
                    if characters[index] == "\\" {
                        if peek(1) == "(" {
                            index += 2
                            var depth = 1
                            var nested = ""
                            while index < characters.count, depth > 0 {
                                if characters[index] == "\"" {
                                    index += 1
                                    nested.append("\"")
                                    while index < characters.count {
                                        if characters[index] == "\\" {
                                            nested.append(characters[index])
                                            index += 1
                                            if index < characters.count {
                                                nested.append(characters[index])
                                                index += 1
                                            }
                                            continue
                                        }
                                        if characters[index] == "\"" {
                                            nested.append(characters[index])
                                            index += 1
                                            break
                                        }
                                        nested.append(characters[index])
                                        index += 1
                                    }
                                    continue
                                }
                                if characters[index] == "(" { depth += 1 }
                                if characters[index] == ")" {
                                    depth -= 1
                                    if depth == 0 { break }
                                }
                                nested.append(characters[index])
                                index += 1
                            }
                            if index < characters.count, characters[index] == ")" { index += 1 }
                            literals.append(contentsOf: stringLiterals(in: nested))
                            continue
                        }
                        if index + 1 < characters.count {
                            let escaped = characters[index + 1]
                            switch escaped {
                            case "n": literal.append("\n")
                            case "t": literal.append("\t")
                            case "\"": literal.append("\"")
                            case "\\": literal.append("\\")
                            default: literal.append(escaped)
                            }
                            index += 2
                            continue
                        }
                    }
                    if characters[index] == "\"" {
                        index += 1
                        break
                    }
                    literal.append(characters[index])
                    index += 1
                }
                literals.append(literal)
                continue
            }
            index += 1
        }
        return literals
    }

    private enum ScanError: Error {
        case missingRoot(String)
    }
}
