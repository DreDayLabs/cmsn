import XCTest

/// Drives a fresh install through first-run into the six revamp surfaces
/// and attaches a full-screen shot of each: Today, the workout session,
/// the session summary, Nutrition, Score, and Workouts/Library. This is a
/// capture harness, not a product behavior test — it does not seed data.
/// The welcome shot is taken after the splash so the looping workout
/// video is on screen.
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
        assertWorkoutSessionIsLegible()

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
        if tapTab(name) { return }
        if openOverflow(name) { return }
        // Summary sits on top of the workout, which sits on Today.
        // Pop until the tab bar — or the overflow list — is on screen again.
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if tapTab(name) { return }
            if openOverflow(name) { return }
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
        XCTFail("Missing tab \(name). \(app.debugDescription)")
    }

    private func tapTab(_ name: String) -> Bool {
        let tab = app.tabBars.buttons[name]
        guard tab.waitForExistence(timeout: 4), tab.isHittable else { return false }
        tab.tap()
        return true
    }

    /// Six tabs put Library and Settings behind the overflow control.
    /// iOS labels that control "More" and lists the rest as cells or buttons.
    private func openOverflow(_ name: String) -> Bool {
        let bar = app.tabBars.buttons
        let more = bar["More"].exists ? bar["More"] : bar.allElementsBoundByIndex.last(where: { button in
            !["Today", "Run", "Nutrition", "Score", "Library", "Settings"].contains(button.label)
        })
        guard let more, more.waitForExistence(timeout: 2), more.isHittable else { return false }
        more.tap()
        let exact = NSPredicate(format: "label == %@", name)
        let queries = [
            app.cells.matching(exact).firstMatch,
            app.buttons.matching(exact).firstMatch,
            app.staticTexts.matching(exact).firstMatch,
            app.collectionViews.cells.containing(.staticText, identifier: name).firstMatch,
        ]
        for candidate in queries {
            if candidate.waitForExistence(timeout: 2) {
                if candidate.isHittable {
                    candidate.tap()
                } else {
                    candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                return true
            }
        }
        return false
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

    /// The pushed session used to draw under the leading safe area, and the
    /// rep target used to wrap one character per line. Both are visible in
    /// element frames, so this locks them without comparing bitmaps.
    private func assertWorkoutSessionIsLegible() {
        let headline = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Let's work")
        ).firstMatch
        XCTAssertTrue(headline.waitForExistence(timeout: 5), "Workout headline never appeared")
        XCTAssertGreaterThan(
            headline.frame.minX,
            8,
            "Workout headline is clipped at the leading edge: \(headline.frame)"
        )
        let focus = app.staticTexts["PUSH"]
        if focus.exists {
            XCTAssertGreaterThan(
                focus.frame.minX,
                8,
                "Focus label is clipped at the leading edge: \(focus.frame)"
            )
        }

        let targets = app.staticTexts.matching(identifier: "workout.repTarget")
        XCTAssertGreaterThan(targets.count, 0, "Rep target never appeared. \(app.debugDescription)")
        for index in 0..<targets.count {
            let target = targets.element(boundBy: index)
            guard target.exists, target.frame.width > 1 else { continue }
            XCTAssertLessThan(
                target.frame.height,
                44,
                "Rep target wrapped vertically: \(target.label) \(target.frame)"
            )
            XCTAssertGreaterThan(
                target.frame.width,
                target.frame.height,
                "Rep target is a vertical column: \(target.label) \(target.frame)"
            )
        }

        XCTAssertTrue(app.staticTexts["Reps"].waitForExistence(timeout: 5), "Reps label missing")
        XCTAssertTrue(app.staticTexts["Weight"].exists, "Weight label missing")
        XCTAssertTrue(app.staticTexts["lb"].exists, "Weight unit missing")
        XCTAssertTrue(app.buttons["Log"].exists, "Log button missing")

        let setLabel = app.staticTexts["Set 1"].firstMatch
        let discomfort = app.buttons["Felt discomfort on this set"].firstMatch
        XCTAssertTrue(setLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(discomfort.waitForExistence(timeout: 5))
        XCTAssertEqual(
            discomfort.frame.minX,
            setLabel.frame.minX,
            accuracy: 4,
            "Discomfort checkbox should align under its set"
        )
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
