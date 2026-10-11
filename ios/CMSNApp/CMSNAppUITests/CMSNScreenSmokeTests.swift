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

        XCTAssertTrue(
            waitForAny(timeout: 30) {
                self.app.staticTexts["Prepare · Perform · Prove"].exists
                    || self.app.buttons["today.primaryAction"].exists
                    || self.app.staticTexts["Today"].exists
            },
            "Today never appeared. \(app.debugDescription)"
        )
        // Calendar access is requested from Today's task, and the readiness
        // button is inserted only after that request returns. Dismiss the
        // system sheet before looking for the button.
        dismissSystemPrompts(for: 8)
        nudgeForInterruptionMonitor()
        capture("today")

        // A fresh profile's action is Start Workout. The revamp keeps that
        // accessibility label and may show "Resume session" once work exists.
        tapFirst(of: ["Start Workout", "Start workout", "Resume session"])
        XCTAssertTrue(
            waitForAny(timeout: 20) {
                self.app.staticTexts["Let's Work"].exists
                    || self.app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Let's work")).firstMatch.exists
            },
            "Workout session never appeared. \(app.debugDescription)"
        )
        capture("workout-session")

        tapFirst(of: ["Finish Session", "Finish session"])
        XCTAssertTrue(
            waitForAny(timeout: 20) {
                self.app.staticTexts["IT COUNTS."].exists
                    || self.app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "planned sets")).firstMatch.exists
                    || self.app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Session logged")).firstMatch.exists
            },
            "Session summary never appeared. \(app.debugDescription)"
        )
        capture("session-summary")

        openTab("Nutrition")
        XCTAssertTrue(
            waitForAny(timeout: 15) {
                self.app.staticTexts["Protein"].exists || self.app.staticTexts["Nutrition"].exists
            },
            "Nutrition never appeared. \(app.debugDescription)"
        )
        capture("nutrition")

        openTab("Score")
        XCTAssertTrue(
            waitForAny(timeout: 15) {
                self.app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Recent")).firstMatch.exists
                    || self.app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "CMSN score")).firstMatch.exists
            },
            "Score never appeared. \(app.debugDescription)"
        )
        capture("score")

        openTab("Library")
        XCTAssertTrue(
            waitForAny(timeout: 15) {
                self.app.staticTexts["Library"].exists || self.app.staticTexts["Workouts"].exists
            },
            "Workouts library never appeared. \(app.debugDescription)"
        )
        capture("workouts-library")
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
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if tab.exists, tab.isHittable {
                tab.tap()
                return
            }
            // Summary sits on top of the workout, which sits on Today.
            // Pop until the tab bar is on screen again.
            let back = app.navigationBars.buttons["Back"]
            if back.exists, back.isHittable {
                back.tap()
            } else if app.navigationBars.buttons.count > 0 {
                let leading = app.navigationBars.buttons.element(boundBy: 0)
                if leading.exists, leading.isHittable {
                    leading.tap()
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing tab \(name). \(app.debugDescription)")
        tab.tap()
    }

    /// Polls until `condition` is true. Used so one harness can shoot the
    /// current build and the revamp, which do not share every label.
    private func waitForAny(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            dismissSystemPrompts(for: 0)
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return condition()
    }

    private func tapFirst(of labels: [String]) {
        let deadline = Date().addingTimeInterval(40)
        nudgeForInterruptionMonitor()
        while Date() < deadline {
            dismissSystemPrompts(for: 0)
            for label in labels {
                let query = app.buttons.matching(NSPredicate(format: "label == %@", label))
                for index in 0..<query.count {
                    let button = query.element(boundBy: index)
                    if button.exists, button.isHittable {
                        button.tap()
                        return
                    }
                }
                let named = app.buttons[label]
                if named.exists, named.isHittable {
                    named.tap()
                    return
                }
            }
            app.swipeUp()
        }
        XCTFail("Could not tap any of \(labels.joined(separator: ", ")). \(app.debugDescription)")
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
