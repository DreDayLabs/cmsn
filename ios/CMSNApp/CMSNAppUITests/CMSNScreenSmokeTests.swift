import XCTest

/// Drives a fresh install through first-run into the five main surfaces and
/// attaches a full-screen shot of each. This is a capture harness for the
/// restyle, not a product behavior test — it does not seed data or change
/// the app. The welcome shot is taken after the splash so the looping
/// workout video is on screen.
final class CMSNScreenSmokeTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ]
        addUIInterruptionMonitor(withDescription: "System permission") { alert in
            for label in ["Don’t Allow", "Don't Allow", "Not Now", "Cancel", "OK"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }

    func testCaptureMainScreens() throws {
        app.launch()

        let getStarted = app.buttons["Get Started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 25), "Welcome CTA never appeared")
        // Splash holds for 1.7s and fades for 0.6s; the CTA finishes its
        // entrance shortly after. Waiting past that puts the looping video,
        // not the black splash, in the frame.
        Thread.sleep(forTimeInterval: 4)
        capture("welcome-video")
        XCTAssertTrue(waitUntilHittable(getStarted, timeout: 10))
        getStarted.tap()

        tap("Skip")
        tap("Begin")
        tap("Continue")
        tap("Continue")
        tap("Start Training")
        tap("Continue")
        tap("Build My Plan")
        tap("Enter the App")

        let today = app.staticTexts["Prepare · Perform · Prove"]
        XCTAssertTrue(today.waitForExistence(timeout: 20), "Today never appeared. \(app.debugDescription)")
        dismissSpringboardPrompts()
        nudgeForInterruptionMonitor()
        capture("today")

        tap("Ready — Let's Go")
        let session = app.staticTexts["Let's Work"]
        XCTAssertTrue(session.waitForExistence(timeout: 15), "Workout session never appeared")
        capture("workout-session")

        openTab("Nutrition")
        XCTAssertTrue(app.staticTexts["Protein"].waitForExistence(timeout: 10))
        capture("nutrition")

        openTab("Library")
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 10))
        capture("library")

        openTab("Settings")
        let export = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Export My Data")).firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 10) || app.staticTexts["ACCOUNT"].waitForExistence(timeout: 5))
        capture("profile-settings")
    }

    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 5), tab.isHittable {
            tab.tap()
            return
        }
        // A pushed session can cover the tab bar. Step back, then switch.
        let back = app.navigationBars.buttons["Back"]
        if back.exists {
            back.tap()
        } else if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing tab \(name)")
        tab.tap()
    }

    private func tap(_ label: String) {
        let query = app.buttons.matching(NSPredicate(format: "label == %@", label))
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            for index in 0..<query.count {
                let button = query.element(boundBy: index)
                if button.exists, button.isHittable {
                    button.tap()
                    return
                }
            }
            if query.count == 0, app.buttons[label].waitForExistence(timeout: 2), app.buttons[label].isHittable {
                app.buttons[label].tap()
                return
            }
            app.swipeUp()
        }
        XCTFail("Could not tap \(label). \(app.debugDescription)")
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element.exists && element.isHittable
    }

    private func nudgeForInterruptionMonitor() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
    }

    private func dismissSpringboardPrompts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Don’t Allow", "Don't Allow", "Not Now"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 2) {
                button.tap()
                return
            }
        }
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory = ProcessInfo.processInfo.environment["CMSN_SCREENSHOT_DIR"] ?? NSTemporaryDirectory()
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: url)
    }
}
