import XCTest

final class ZmanimUITests: XCTestCase {
    private let defaultLaunchArguments = [
        "-UITestMode", "YES",
        "-UITestShortSnooze", "YES",
        "-AppleLanguages", "(he)",
        "-AppleLocale", "he_IL"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "System Dialog") { alert in
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            if alert.buttons["Allow While Using App"].exists {
                alert.buttons["Allow While Using App"].tap()
                return true
            }
            if alert.buttons["אישור"].exists {
                alert.buttons["אישור"].tap()
                return true
            }
            if alert.buttons.count > 1 {
                alert.buttons.element(boundBy: 1).tap()
                return true
            }
            return false
        }
    }

    private func dismissPermissionAlertIfPresent(springboard: XCUIApplication) {
        let candidates = [
            springboard.buttons["Allow"],
            springboard.buttons["Allow While Using App"],
            springboard.alerts.buttons["Allow"],
            springboard.buttons["אישור"],
            springboard.alerts.buttons["אישור"]
        ]
        for btn in candidates {
            if btn.exists {
                btn.tap()
                break
            }
        }
    }

    private func notificationsTab(in app: XCUIApplication) -> XCUIElement {
        let btnHe = app.tabBars.buttons["התראות"]
        if btnHe.waitForExistence(timeout: 2) { return btnHe }
        let btnEn = app.tabBars.buttons["Notifications"]
        if btnEn.waitForExistence(timeout: 2) { return btnEn }
        return btnHe
    }

    private func sendTestNotificationButton(in app: XCUIApplication) -> XCUIElement {
        let btnHe = app.buttons["שלח התראת בדיקה"]
        if btnHe.waitForExistence(timeout: 2) { return btnHe }
        let btnEn = app.buttons["Send Test Alert"]
        if btnEn.waitForExistence(timeout: 2) { return btnEn }
        return btnHe
    }

    private func findSnoozeButton(in springboard: XCUIApplication) -> XCUIElement? {
        let btnHe = springboard.buttons["נודניק 5 דק׳"]
        if btnHe.waitForExistence(timeout: 1) { return btnHe }
        let btnEn = springboard.buttons["Snooze 5 min"]
        if btnEn.waitForExistence(timeout: 1) { return btnEn }
        return nil
    }

    private func expandBanner(_ banner: XCUIElement, springboard: XCUIApplication) {
        Thread.sleep(forTimeInterval: 1.0)

        // Use coordinate-based drag first to prevent AXScrollToVisible failure while banner animates on screen
        if banner.exists {
            let startCoord = banner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let finishCoord = banner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 3.0))
            startCoord.press(forDuration: 0.2, thenDragTo: finishCoord)
            Thread.sleep(forTimeInterval: 1.5)
        }

        if findSnoozeButton(in: springboard) == nil && banner.exists {
            banner.press(forDuration: 1.5)
            Thread.sleep(forTimeInterval: 1.5)
        }

        if findSnoozeButton(in: springboard) == nil && banner.exists {
            banner.swipeDown()
            Thread.sleep(forTimeInterval: 1.5)
        }
    }

    func testAppLaunchesWithDeterministicJerusalemData() throws {
        let app = XCUIApplication()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        dismissPermissionAlertIfPresent(springboard: springboard)

        let jerusalemText = app.staticTexts["ירושלים"]
        XCTAssertTrue(jerusalemText.waitForExistence(timeout: 15), "Expected Jerusalem zmanim to be loaded in UI test mode")
    }

    func testRichNotificationExpansionAndForegroundSnooze() throws {
        let app = XCUIApplication()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        dismissPermissionAlertIfPresent(springboard: springboard)

        // Switch to Notifications tab
        let tab = notificationsTab(in: app)
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Expected Notifications tab bar button")
        tab.tap()

        // Tap send test alert button
        let sendTestButton = sendTestNotificationButton(in: app)
        XCTAssertTrue(sendTestButton.waitForExistence(timeout: 10), "Expected test notification button")
        sendTestButton.tap()

        // Handle permission dialog if it pops up after tapping the button
        dismissPermissionAlertIfPresent(springboard: springboard)

        // 1. Mandatory assertion: System notification banner MUST appear on SpringBoard
        let banner = springboard.descendants(matching: .any).matching(identifier: "NotificationShortLookView").firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15), "System notification banner must appear on SpringBoard within timeout")

        // 2. Expand notification banner to invoke custom content extension
        expandBanner(banner, springboard: springboard)

        // 3. Capture authentic screenshot of expanded notification
        let expandedScreenshot = XCUIScreen.main.screenshot()
        let expandedAttachment = XCTAttachment(screenshot: expandedScreenshot)
        expandedAttachment.lifetime = .keepAlways
        expandedAttachment.name = "expanded-rich-notification"
        add(expandedAttachment)

        let tmpExpandedUrl = URL(fileURLWithPath: "/tmp/expanded-rich-notification.png")
        try? expandedScreenshot.pngRepresentation.write(to: tmpExpandedUrl)

        // 4. Mandatory assertion: Snooze action button MUST exist
        let snoozeButton = findSnoozeButton(in: springboard) ?? (springboard.buttons["נודניק 5 דק׳"].waitForExistence(timeout: 5) ? springboard.buttons["נודניק 5 דק׳"] : springboard.buttons["Snooze 5 min"])
        XCTAssertTrue(snoozeButton.waitForExistence(timeout: 10), "Snooze action button ('נודניק 5 דק׳' or 'Snooze 5 min') must exist on expanded notification")

        // 5. Tap snooze action while app is open in foreground
        snoozeButton.tap()

        // 6. Mandatory assertion: Containing app MUST NOT crash
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5) || (app.state != .notRunning && app.state != .unknown),
            "Containing application must remain alive without crashing after pressing snooze in foreground (current state: \(app.state.rawValue))"
        )
        XCTAssertNotEqual(app.state, .notRunning, "Containing app must not terminate or crash after pressing snooze in foreground")

        // Wait for previous notification overlay to fully disappear before expecting redelivery
        let oldBanner = springboard.descendants(matching: .any).matching(identifier: "NotificationShortLookView").firstMatch
        _ = oldBanner.waitForNonExistence(timeout: 3)

        // 7. Mandatory assertion: Snooze MUST be redelivered (5-second short snooze interval in test mode)
        let redeliveredBanner = springboard.descendants(matching: .any).matching(identifier: "NotificationShortLookView").firstMatch
        XCTAssertTrue(redeliveredBanner.waitForExistence(timeout: 15), "Snoozed notification must be redelivered within timeout")

        let redeliveredScreenshot = XCUIScreen.main.screenshot()
        let redeliveredAttachment = XCTAttachment(screenshot: redeliveredScreenshot)
        redeliveredAttachment.lifetime = .keepAlways
        redeliveredAttachment.name = "snooze-redelivered"
        add(redeliveredAttachment)

        let tmpRedeliveredUrl = URL(fileURLWithPath: "/tmp/snooze-redelivered.png")
        try? redeliveredScreenshot.pngRepresentation.write(to: tmpRedeliveredUrl)
    }

    func testBackgroundSnoozeInteraction() throws {
        let app = XCUIApplication()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        dismissPermissionAlertIfPresent(springboard: springboard)

        let tab = notificationsTab(in: app)
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Expected Notifications tab")
        tab.tap()

        let sendTestButton = sendTestNotificationButton(in: app)
        XCTAssertTrue(sendTestButton.waitForExistence(timeout: 10), "Expected test notification button")
        sendTestButton.tap()

        dismissPermissionAlertIfPresent(springboard: springboard)

        // Ensure async scheduling task in app has completed adding request to UNUserNotificationCenter before backgrounding
        Thread.sleep(forTimeInterval: 2.0)

        // Send app to background
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.0)

        let banner = springboard.descendants(matching: .any).matching(identifier: "NotificationShortLookView").firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15), "System notification banner must appear while app is in background")

        expandBanner(banner, springboard: springboard)

        let snoozeButton = findSnoozeButton(in: springboard) ?? (springboard.buttons["נודניק 5 דק׳"].waitForExistence(timeout: 5) ? springboard.buttons["נודניק 5 דק׳"] : springboard.buttons["Snooze 5 min"])
        XCTAssertTrue(snoozeButton.waitForExistence(timeout: 10), "Snooze action button must exist while app is in background")
        snoozeButton.tap()

        // Mandatory assertion: Containing app must remain alive without crashing after pressing snooze while in background
        XCTAssertNotEqual(app.state, .notRunning, "Containing app must not crash when snooze is tapped in background")

        // Wait for previous notification overlay to dismiss before expecting redelivery
        let oldBanner = springboard.descendants(matching: .any).matching(identifier: "NotificationShortLookView").firstMatch
        _ = oldBanner.waitForNonExistence(timeout: 3)

        // Wait for redelivery
        let redeliveredBanner = springboard.descendants(matching: .any).matching(identifier: "NotificationShortLookView").firstMatch
        XCTAssertTrue(redeliveredBanner.waitForExistence(timeout: 15), "Background-snoozed notification must be redelivered")
    }
}
