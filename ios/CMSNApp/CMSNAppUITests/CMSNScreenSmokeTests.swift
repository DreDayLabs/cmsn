import XCTest

/// Drives a fresh install through first-run into the five main surfaces and
/// attaches a full-screen shot of each. This is a capture harness for the
/// restyle, not a product behavior test — it does not seed data or change
/// the app. The welcome shot is taken after the splash so the looping
/// workout video is on screen.
///
/// The CMSNScreenshots scheme launches without a debugger. On the hosted
/// macOS runner, attaching LLDB intermittently reports "no debugger version"
/// and `launch()` then dies with "Timed out while launching application via
/// Xcode". The workflow also reboots the simulator and retries the harness
/// once when that still happens.
final class CMSNScreenSmokeTests: XCTestCase {
    private let app = XCUIApplication()
    private let promptLabels = [
        "Don’t Allow",
        "Don't Allow",
        "Not Now",
        "Cancel",
        "OK",
        "Close",
        "Allow Full Access",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ]
        addUIInterruptionMonitor(withDescription: "System permission") { alert in
            for label in self.promptLabels {
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
        launchApp()

        let getStarted = app.buttons["Get Started"]
        XCTAssertTrue(
            getStarted.waitForExistence(timeout: 30),
            "Welcome CTA never appeared. \(app.debugDescription)"
        )
        // Splash holds for 1.7s and fades for 0.6s; the CTA finishes its
        // entrance shortly after. Waiting past that puts the looping video,
        // not the black splash, in the frame.
        Thread.sleep(forTimeInterval: 4)
        capture("welcome-video")
        XCTAssertTrue(waitUntilHittable(getStarted, timeout: 15), "Get Started was not hittable")
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
        XCTAssertTrue(today.waitForExistence(timeout: 30), "Today never appeared. \(app.debugDescription)")
        // Calendar access is requested from Today's task, and the readiness
        // button is inserted only after that request returns. Dismiss the
        // system sheet before looking for the button.
        dismissSystemPrompts(for: 8)
        nudgeForInterruptionMonitor()
        capture("today")

        // Today keeps the readiness card and puts the next step on one
        // primary button. A fresh profile's action is Start Workout.
        tap("Start Workout")
        let session = app.staticTexts["Let's Work"]
        XCTAssertTrue(session.waitForExistence(timeout: 20), "Workout session never appeared")
        capture("workout-session")

        openTab("Nutrition")
        XCTAssertTrue(app.staticTexts["Protein"].waitForExistence(timeout: 15))
        capture("nutrition")

        openTab("Library")
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 15))
        capture("library")

        openTab("Settings")
        let export = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Export My Data")).firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 15) || app.staticTexts["ACCOUNT"].waitForExistence(timeout: 8))
        capture("profile-settings")
    }

    /// `launch()` returns once Xcode believes the process exists. On a cold
    /// simulator that is not the same as the app being in front and idle,
    /// so wait for the foreground state before querying the first screen.
    private func launchApp() {
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 45),
            "CMSN did not reach the foreground after launch. \(app.debugDescription)"
        )
    }

    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 8), tab.isHittable {
            tab.tap()
            return
        }
        // A pushed session can cover the tab bar. Step back, then switch.
        let back = app.navigationBars.buttons["Back"]
        if back.waitForExistence(timeout: 3), back.isHittable {
            back.tap()
        } else if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        XCTAssertTrue(tab.waitForExistence(timeout: 12), "Missing tab \(name)")
        tab.tap()
    }

    /// Waits until a button with this exact label exists and is hittable.
    /// Today's primary action sits under the session and fuel cards, and
    /// the calendar sheet can cover the screen, so the wait dismisses
    /// permission prompts and scrolls.
    private func tap(_ label: String) {
        let query = app.buttons.matching(NSPredicate(format: "label == %@", label))
        let deadline = Date().addingTimeInterval(40)
        nudgeForInterruptionMonitor()
        while Date() < deadline {
            dismissSystemPrompts(for: 0)
            for index in 0..<query.count {
                let button = query.element(boundBy: index)
                if button.exists, button.isHittable {
                    button.tap()
                    return
                }
            }
            let named = app.buttons[label]
            if named.waitForExistence(timeout: 3), named.isHittable {
                named.tap()
                return
            }
            app.swipeUp()
        }
        XCTFail("Could not tap \(label). \(app.debugDescription)")
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            dismissSystemPrompts(for: 0)
            if element.exists, element.isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return element.exists && element.isHittable
    }

    private func nudgeForInterruptionMonitor() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
    }

    /// `timeout` of 0 checks once. A positive value polls, because the
    /// calendar sheet can appear a moment after Today is on screen.
    /// Only SpringBoard and alert buttons are tapped, so an in-app control
    /// that happens to share a label is left alone.
    private func dismissSystemPrompts(for timeout: TimeInterval) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for label in promptLabels {
                let springboardButton = springboard.buttons[label]
                if springboardButton.exists, springboardButton.isHittable {
                    springboardButton.tap()
                    return
                }
                let alertButton = app.alerts.buttons[label]
                if alertButton.exists, alertButton.isHittable {
                    alertButton.tap()
                    return
                }
            }
            if timeout == 0 { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        } while Date() < deadline
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
