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
        var events: [String] = []
        defer { attachCalendarEvents(events) }

        guard let toggle = revealedInnerCalendarSwitch(events: &events) else { return }
        let row = calendarSwitch()
        let preValue = switchValue(toggle)
        record(&events, "pre-value", "inner=\(preValue) row=\(switchValue(row)) \(frameNote("inner", toggle)) hittable=\(toggle.isHittable)")
        record(&events, "pre-tree", row.debugDescription)
        XCTAssertEqual(preValue, "0", "Today's calendar control was not off. value=\(preValue)")
        XCTAssertTrue(toggle.exists, "Inner calendar switch is not in the accessibility tree.")
        XCTAssertTrue(
            toggle.isHittable,
            "Inner calendar switch is not hittable. \(frameNote("inner", toggle)) \(bandNote())"
        )
        XCTAssertTrue(
            frameIsUnobstructed(toggle.frame),
            "Inner calendar switch is not fully in the viewport. \(frameNote("inner", toggle)) \(bandNote())"
        )
        guard toggle.exists, toggle.isHittable, frameIsUnobstructed(toggle.frame) else { return }

        record(&events, "tap-element", "inner switch element, not the row title")
        toggle.tap()
        record(&events, "alert-wait-start", "system calendar alert")
        let alert = waitForCalendarAlert()
        let postValue = switchValue(toggle)
        record(&events, "post-value", "inner=\(postValue) row=\(switchValue(row)) alert=\(alert.exists) \(frameNote("inner", toggle))")
        record(&events, "post-tree", row.debugDescription)
        if !alert.exists, postValue != "1" {
            XCTFail(
                """
                Inner calendar switch stayed \(postValue) and no system calendar alert appeared. \
                Activation was not observed. This does not establish a request defect. \
                \(row.debugDescription)
                """
            )
        }
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

        if switchValue(calendarSwitch()) == "1" {
            guard let stillOn = revealedInnerCalendarSwitch(events: &events) else { return }
            record(&events, "tap-element-off", "inner switch element")
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
        for label in ["Skip", "Begin", "Continue", "Continue", "Start Training", "Continue", "Build My Plan", "Enter the App", "Start my week"] {
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

    /// The identified switch is the whole row, including the title. The control
    /// is the descendant switch. Scroll until that row sits between the
    /// navigation bar and the tab bar, then return the control.
    private func revealedInnerCalendarSwitch(events: inout [String]) -> XCUIElement? {
        let row = app.switches["settings.calendarOptIn"]
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline, !row.exists {
            nudgeSettingsContent()
        }
        let inner = row.switches.firstMatch
        var nudges = 0
        while nudges < 8 {
            if row.exists, controlIsUnobstructed(inner, in: row), rowIsUnobstructed(row) {
                record(
                    &events,
                    "target-resolved",
                    "\(frameNote("row", row)) \(frameNote("inner", inner)) hittable=\(inner.isHittable) \(bandNote())"
                )
                return inner
            }
            nudgeSettingsContent()
            nudges += 1
        }
        let detail = "rowExists=\(row.exists) \(frameNote("row", row)) innerExists=\(inner.exists) \(frameNote("inner", inner)) hittable=\(inner.exists && inner.isHittable) \(bandNote())"
        record(&events, "target-unresolvable", detail)
        XCTFail("Calendar switch target is unresolvable. The inner switch was not fully visible and hittable above the tab bar. \(detail)")
        return nil
    }

    private func rowIsUnobstructed(_ row: XCUIElement) -> Bool {
        guard row.exists, frameIsUnobstructed(row.frame) else { return false }
        return true
    }

    private func controlIsUnobstructed(_ inner: XCUIElement, in row: XCUIElement) -> Bool {
        guard inner.exists, inner.isHittable, frameIsUnobstructed(inner.frame) else { return false }
        guard row.exists, frameIsOnScreen(row.frame) else { return false }
        return inner.frame.width + 1 < row.frame.width
    }

    private func frameIsUnobstructed(_ frame: CGRect) -> Bool {
        guard frameIsOnScreen(frame), let band = visibleBand() else { return false }
        return frame.minY >= band.top && frame.maxY <= band.bottom
    }

    private func frameIsOnScreen(_ frame: CGRect) -> Bool {
        frame.width > 1
            && frame.height > 1
            && frame.minX.isFinite
            && frame.minY.isFinite
            && !frame.isNull
            && !frame.isInfinite
    }

    private func visibleBand() -> (top: CGFloat, bottom: CGFloat)? {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.exists, frameIsOnScreen(tabBar.frame) else { return nil }
        let navigationBar = app.navigationBars.firstMatch
        let top = navigationBar.exists ? navigationBar.frame.maxY : 0
        return (top, tabBar.frame.minY)
    }

    /// Moves the settings list a short distance. This is not the switch tap.
    private func nudgeSettingsContent() {
        let scroll = app.scrollViews.firstMatch
        let host = scroll.exists ? scroll : app
        let start = host.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.70))
        let end = host.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func switchValue(_ element: XCUIElement) -> String {
        guard element.exists else { return "missing" }
        if let text = element.value as? String { return text }
        return String(describing: element.value ?? "nil")
    }

    private func frameNote(_ name: String, _ element: XCUIElement) -> String {
        guard element.exists else { return "\(name)=missing" }
        return "\(name)=\(element.frame)"
    }

    private func bandNote() -> String {
        guard let band = visibleBand() else { return "band=missing" }
        return "band=\(band.top)...\(band.bottom)"
    }

    private func record(_ events: inout [String], _ name: String, _ detail: String) {
        let line = "CMSN-CAL \(events.count + 1) \(name) \(detail)"
        events.append(line)
        print(line)
    }

    private func attachCalendarEvents(_ events: [String]) {
        let attachment = XCTAttachment(string: events.joined(separator: "\n"))
        attachment.name = "CMSN-CAL event order"
        attachment.lifetime = .keepAlways
        add(attachment)
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
