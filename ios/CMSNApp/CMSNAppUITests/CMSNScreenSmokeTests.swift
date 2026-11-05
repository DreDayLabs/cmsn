import XCTest

/// Drives a fresh install through first-run into the main surfaces and
/// attaches a full-screen shot of each: Today, the workout session, the
/// session summary, Nutrition, Score, Workouts/Library, Settings, the
/// CMSN+ paywall, Run, and Build-a-Meal. This is a capture harness, not a
/// product behavior test — it does not seed data.
/// The welcome shot is taken after the splash so the looping workout
/// video is on screen.
///
/// Launch passes `-CMSNResetFirstRun` (see `CMSNModelContainerFactory`).
/// A simulator that already finished onboarding would open on Today, and
/// the welcome CTA would never exist. The splash also covers that CTA
/// for 3.8s, so the shot of the film is taken before the button is required.
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
            "-CMSNResetFirstRun",
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

        // The film covers the narrative for 3.8s. The CTA is not in the
        // accessibility tree until that cover lifts, so shoot the splash
        // first, then require the button.
        _ = waitForAny(timeout: 8) {
            self.app.staticTexts["Earn Your CMSN"].exists || self.app.images["CMSN"].exists
        }
        capture("welcome-splash")

        XCTAssertTrue(
            waitForAny(timeout: 30) {
                self.app.buttons["welcome.getStarted"].exists || self.app.buttons["Get Started"].exists
            },
            "Welcome CTA never appeared. \(app.debugDescription)"
        )
        let getStarted = welcomeCTA()
        XCTAssertTrue(waitUntilHittable(getStarted, timeout: 15), "Get Started was not hittable")
        capture("welcome-video")
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
        assertPlaceholderAbsent("Background video")

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
        assertPlaceholderAbsent("Form video")
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
        assertPlaceholderAbsent("Video")

        openTab("Settings")
        XCTAssertTrue(
            waitForAny(timeout: 15) {
                self.app.staticTexts["ACCOUNT"].exists
                    || self.app.staticTexts["CMSNer"].exists
                    || self.app.staticTexts["Delete Everything"].exists
            },
            "Settings never appeared. \(app.debugDescription)"
        )
        capture("settings")

        // Same fresh-install launch (`-CMSNResetFirstRun` is unchanged).
        // Settings → CMSN+ is the existing paywall path. The shot has to
        // show the locked display prices: Monthly $9.99 and Annual $59.99.
        openCMSNPlus()
        capturePaywall()
        tap("Close")

        openTab("Run")
        XCTAssertTrue(
            waitForAny(timeout: 15) {
                self.app.buttons["Quick Start"].exists
            },
            "Run never appeared. \(app.debugDescription)"
        )
        capture("run")

        openTab("Nutrition")
        tapFirst(of: ["Log Food", "Log food"])
        XCTAssertTrue(
            waitForAny(timeout: 15) {
                self.app.staticTexts["WHAT'S IN IT?"].exists
                    || self.app.staticTexts["Build A Meal"].exists
            },
            "Build-a-Meal never appeared. \(app.debugDescription)"
        )
        capture("meal-builder")
    }

    /// Settings → CMSN+. The row's visible title stays "CMSN+".
    private func openCMSNPlus() {
        let identified = app.buttons["settings.cmsnPlus"]
        let deadline = Date().addingTimeInterval(20)
        nudgeForInterruptionMonitor()
        while Date() < deadline {
            dismissSystemPrompts(for: 0)
            if identified.exists, identified.isHittable {
                identified.tap()
                return
            }
            let query = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "CMSN+"))
            for index in 0..<query.count {
                let button = query.element(boundBy: index)
                if button.exists, button.isHittable {
                    button.tap()
                    return
                }
            }
            app.swipeUp()
        }
        XCTFail("Could not open CMSN+. \(app.debugDescription)")
    }

    /// Waits for both plan rows, scrolls until the locked prices and the
    /// subscription disclosure share the frame, then records `paywall.png`.
    /// Prices are the button labels (`Monthly, $9.99` / `Annual, $59.99`),
    /// which use the same string the row draws.
    private func capturePaywall() {
        let monthly = app.buttons["paywall.monthly"]
        let annual = app.buttons["paywall.annual"]
        let disclosure = app.staticTexts["paywall.disclosure"]
        let trial = app.staticTexts["paywall.trial"]
        XCTAssertTrue(
            waitForAny(timeout: 15) {
                monthly.exists && annual.exists && disclosure.exists && trial.exists
                    && (self.paywallLink("paywall.terms").exists && self.paywallLink("paywall.privacy").exists)
            },
            "CMSN+ paywall never appeared. \(app.debugDescription)"
        )
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            let terms = paywallLink("paywall.terms")
            let privacy = paywallLink("paywall.privacy")
            if isFullyOnScreen(monthly)
                && paywallLegalIsOnScreen(annual: annual, trial: trial, disclosure: disclosure, terms: terms, privacy: privacy) {
                break
            }
            // Another drag would push the $9.99 row off the top of paywall.png.
            if monthly.frame.height > 1, monthly.frame.minY < 24 {
                break
            }
            nudgePaywallUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        let terms = paywallLink("paywall.terms")
        let privacy = paywallLink("paywall.privacy")
        capture("paywall")
        XCTAssertTrue(
            monthly.label.contains("$9.99"),
            "Monthly price label was \"\(monthly.label)\". The locked display price is $9.99."
        )
        XCTAssertTrue(
            annual.label.contains("$59.99"),
            "Annual price label was \"\(annual.label)\". The locked display price is $59.99."
        )
        XCTAssertTrue(
            isFullyOnScreen(monthly) && isFullyOnScreen(annual),
            "Prices were not both on screen for paywall.png. monthly=\(monthly.frame) annual=\(annual.frame)"
        )
        XCTAssertTrue(
            trial.label.contains("7-day free trial"),
            "Trial line was \"\(trial.label)\"."
        )
        XCTAssertTrue(
            disclosure.label.contains("auto-renewing subscription"),
            "Subscription disclosure was \"\(disclosure.label)\"."
        )
        XCTAssertTrue(
            disclosure.label.contains("Subscriptions"),
            "Cancel path missing from \"\(disclosure.label)\"."
        )
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Nothing is billed")).firstMatch.exists,
            "Pre-launch billing disclaimer is still on the paywall. \(app.debugDescription)"
        )
        XCTAssertTrue(terms.exists, "Terms of Use link missing. \(app.debugDescription)")
        XCTAssertTrue(privacy.exists, "Privacy Policy link missing. \(app.debugDescription)")
        XCTAssertEqual(
            terms.value as? String,
            "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/",
            "Terms link was \"\(terms.value ?? "nil")\"."
        )
        XCTAssertEqual(
            privacy.value as? String,
            "https://earnyourcmsn.com/privacy",
            "Privacy link was \"\(privacy.value ?? "nil")\"."
        )
        XCTAssertTrue(
            isFullyOnScreen(disclosure) && isFullyOnScreen(terms) && isFullyOnScreen(privacy),
            "Subscription terms were not fully on screen for paywall.png. disclosure=\(disclosure.frame) terms=\(terms.frame) privacy=\(privacy.frame)"
        )
    }

    private func paywallLegalIsOnScreen(
        annual: XCUIElement,
        trial: XCUIElement,
        disclosure: XCUIElement,
        terms: XCUIElement,
        privacy: XCUIElement
    ) -> Bool {
        isFullyOnScreen(annual)
            && isFullyOnScreen(trial)
            && isFullyOnScreen(disclosure)
            && isFullyOnScreen(terms)
            && isFullyOnScreen(privacy)
    }

    /// A short drag. A full swipe can push the $9.99 row off before the
    /// terms line is in frame.
    private func nudgePaywallUp() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// SwiftUI `Link` is a link on current iOS and a button on some earlier
    /// accessibility trees. Either identifier is the paywall footer link.
    /// Re-query each time; resolving before the sheet exists sticks the
    /// lookup on an empty button query.
    private func paywallLink(_ identifier: String) -> XCUIElement {
        let link = app.links[identifier]
        if link.exists { return link }
        let button = app.buttons[identifier]
        if button.exists { return button }
        return link
    }

    private func isFullyOnScreen(_ element: XCUIElement) -> Bool {
        guard element.exists, element.frame.width > 1, element.frame.height > 1 else { return false }
        return element.frame.minY >= 0 && element.frame.maxY <= app.frame.maxY + 1
    }

    /// These strings were visible slot labels on the media, not product copy.
    private func assertPlaceholderAbsent(_ label: String) {
        XCTAssertFalse(
            app.staticTexts[label].exists,
            "Placeholder \"\(label)\" is still on screen. \(app.debugDescription)"
        )
    }

    /// Identifier first. The visible label stays "Get Started" so an older
    /// build of the same screen still matches.
    private func welcomeCTA() -> XCUIElement {
        let identified = app.buttons["welcome.getStarted"]
        if identified.exists { return identified }
        return app.buttons["Get Started"]
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
