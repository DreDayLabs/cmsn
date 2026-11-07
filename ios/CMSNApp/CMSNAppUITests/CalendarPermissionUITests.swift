import XCTest

/// Real calendar permission UI. This is not `CMSNScreenSmokeTests`.
/// That harness taps system buttons, including Don't Allow, and never
/// turns Today's calendar on. Those screenshots do not prove opt-in,
/// denial, or that the switch stays off.
///
/// The clean state is `XCUIApplication.resetAuthorizationStatus(for: .calendar)`,
/// called before launch (Xcode 11.4 / iOS 13.4; WWDC20 session 10220).
/// Calendar is one of the protected resources that API resets. Resetting
/// can terminate the app, so it happens before `launch()`.
///
/// A fresh simulator is already not-determined. A simulator that has run
/// the screenshot harness may already be denied. Before this test, Gene
/// can also run the Simulator command printed by `xcrun simctl privacy`:
/// `privacy <udid> reset calendar com.earnyourcmsn.app`.
/// `grant` and `revoke` skip the prompt, so they are not this precondition.
/// `tccutil reset Calendar` is the macOS command in Apple's protected-resource
/// article, not the iOS simulator command.
///
/// The test does not tap Allow. It does not prove EventKit skipped a read.
/// The unit tests in `PrivacyReliabilityTests` cover that policy.
final class CalendarPermissionUITests: XCTestCase {
    private let app = XCUIApplication()
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private let offLine = "Off. CMSN does not ask until you turn this on."
    private let blockedLine = "Blocked. iOS is not allowing calendar access."

    func testTodayDoesNotPromptAndSettingsDenyLeavesAVisibleBlock() {
        app.resetAuthorizationStatus(for: .calendar)
        app.launchArguments += [
            "-CMSNResetFirstRun",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        launch()
        finishOnboardingWithoutTouchingSystemAlerts()

        XCTAssertTrue(todayIsVisible(), "Today never appeared. \(app.debugDescription)")
        XCTAssertFalse(
            calendarAlertExists(),
            "Today opened a calendar permission alert. \(springboard.debugDescription) \(app.debugDescription)"
        )

        openSettings()
        XCTAssertTrue(waitForStatus(offLine), "Settings did not show the off line. \(app.debugDescription)")
        let toggle = calendarSwitch()
        XCTAssertEqual(toggle.value as? String, "0", "Today's calendar was not off. value=\(toggle.value ?? "nil")")

        toggle.tap()
        let alert = waitForCalendarAlert()
        XCTAssertTrue(alert.exists, "Settings opt-in did not present a system calendar alert. \(springboard.debugDescription) \(app.debugDescription)")
        let deny = dontAllowButton(in: alert)
        XCTAssertTrue(deny.exists, "The system calendar alert had no Don't Allow button. \(alert.debugDescription)")
        let offersAccess = alert.buttons["Allow Full Access"].exists || alert.buttons["Allow"].exists
        XCTAssertTrue(
            offersAccess,
            "The system alert mentioned Calendar but did not offer Allow Full Access or Allow. \(alert.debugDescription)"
        )
        deny.tap()

        XCTAssertTrue(
            waitForStatus(blockedLine),
            "After Don't Allow, Settings did not show the blocked line. \(app.debugDescription)"
        )

        let stillOn = calendarSwitch()
        if (stillOn.value as? String) == "1" {
            stillOn.tap()
        }
        XCTAssertTrue(waitForStatus(offLine), "Turning the switch off did not show the off line. \(app.debugDescription)")
        XCTAssertEqual(calendarSwitch().value as? String, "0")

        app.terminate()
        app.launchArguments.removeAll { $0 == "-CMSNResetFirstRun" }
        launch()
        openSettings()
        XCTAssertTrue(waitForStatus(offLine), "After relaunch the switch was not off. \(app.debugDescription)")
        XCTAssertEqual(calendarSwitch().value as? String, "0")
        XCTAssertFalse(
            calendarAlertExists(),
            "Relaunch with the switch off presented a calendar alert. \(springboard.debugDescription)"
        )
    }

    private func launch() {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 45), app.debugDescription)
    }

    private func finishOnboardingWithoutTouchingSystemAlerts() {
        let started = Date()
        while Date().timeIntervalSince(started) < 20 {
            if calendarAlertExists() {
                XCTFail("A calendar alert appeared during onboarding. \(springboard.debugDescription)")
                return
            }
            if app.buttons["welcome.getStarted"].exists || app.buttons["Get Started"].exists || todayIsVisible() {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        if todayIsVisible() { return }
        tapInApp("welcome.getStarted", or: "Get Started")
        for label in ["Skip", "Begin", "Continue", "Continue", "Start Training", "Continue", "Build My Plan", "Enter the App"] {
            if todayIsVisible() { return }
            tapInApp(label, or: label)
        }
    }

    private func tapInApp(_ identifier: String, or label: String) {
        XCTAssertFalse(calendarAlertExists(), "Calendar alert appeared before \(label). \(springboard.debugDescription)")
        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline {
            XCTAssertFalse(calendarAlertExists(), "Calendar alert appeared while looking for \(label).")
            let identified = app.buttons[identifier]
            if identified.exists, identified.isHittable {
                identified.tap()
                return
            }
            let named = app.buttons[label]
            if named.exists, named.isHittable {
                named.tap()
                return
            }
            app.swipeUp()
        }
        XCTFail("Could not tap \(label) without touching a system alert. \(app.debugDescription)")
    }

    private func todayIsVisible() -> Bool {
        app.buttons["today.primaryAction"].exists
            || app.staticTexts["Prepare · Perform · Prove"].exists
            || app.buttons["Start Workout"].exists
    }

    private func openSettings() {
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            let tab = app.tabBars.buttons["Settings"]
            if tab.exists, tab.isHittable {
                tab.tap()
                return
            }
            let overflow = app.tabBars.buttons["More"]
            let settingsText = app.tables.staticTexts["Settings"]
            let settingsCell = app.tables.cells.containing(NSPredicate(format: "label == %@", "Settings")).firstMatch
            if settingsCell.exists, settingsCell.isHittable {
                settingsCell.tap()
                return
            }
            if settingsText.exists, settingsText.isHittable {
                settingsText.tap()
                return
            }
            if overflow.exists, overflow.isHittable {
                overflow.tap()
                if settingsCell.waitForExistence(timeout: 2), settingsCell.isHittable {
                    settingsCell.tap()
                    return
                }
                if settingsText.waitForExistence(timeout: 2), settingsText.isHittable {
                    settingsText.tap()
                    return
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTFail("Settings tab was not available. \(app.debugDescription)")
    }

    private func calendarSwitch() -> XCUIElement {
        let toggle = app.switches["settings.calendarOptIn"]
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if toggle.exists { return toggle }
            app.swipeUp()
        }
        XCTFail("Today's calendar switch was not on screen. \(app.debugDescription)")
        return toggle
    }

    private func waitForStatus(_ line: String) -> Bool {
        let status = app.staticTexts["settings.calendarStatus"]
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if status.exists, status.label == line { return true }
            if app.staticTexts[line].exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return (status.exists && status.label == line) || app.staticTexts[line].exists
    }

    private func calendarAlertExists() -> Bool {
        waitForCalendarAlert(timeout: 0).exists
    }

    private func waitForCalendarAlert(timeout: TimeInterval = 8) -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for host in [springboard, app] {
                let alert = host.alerts.containing(
                    NSPredicate(format: "label CONTAINS[c] %@", "calendar")
                ).firstMatch
                if alert.exists { return alert }
            }
            if timeout == 0 { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline
        return springboard.alerts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "calendar")
        ).firstMatch
    }

    private func dontAllowButton(in alert: XCUIElement) -> XCUIElement {
        for label in ["Don’t Allow", "Don't Allow"] {
            let button = alert.buttons[label]
            if button.exists { return button }
        }
        return alert.buttons["Don’t Allow"]
    }
}
