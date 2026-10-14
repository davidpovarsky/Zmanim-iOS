import XCTest

final class ZmanimUITests: XCTestCase {
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

    private func expandBanner(_ banner: XCUIElement, springboard: XCUIApplication) {
        banner.swipeDown()
        Thread.sleep(forTimeInterval: 1.5)

        let snoozeButton = springboard.buttons["נודניק 5 דק׳"]
        if !snoozeButton.exists && banner.exists {
            banner.press(forDuration: 1.2)
            Thread.sleep(forTimeInterval: 1.5)
        }

        if !snoozeButton.exists && banner.exists {
            let startCoord = banner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let finishCoord = banner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            startCoord.press(forDuration: 0.1, thenDragTo: finishCoord)
            Thread.sleep(forTimeInterval: 1.5)
        }
    }

    func testAppLaunchesWithDeterministicJerusalemData() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "YES", "-UITestShortSnooze", "YES"]
        app.launch()

        let jerusalemText = app.staticTexts["ירושלים"]
        XCTAssertTrue(jerusalemText.waitForExistence(timeout: 15), "Expected Jerusalem zmanim to be loaded in UI test mode")
    }

    func testRichNotificationExpansionAndForegroundSnooze() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "YES", "-UITestShortSnooze", "YES"]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        dismissPermissionAlertIfPresent(springboard: springboard)

        // Switch to Notifications tab
        let notificationsTab = app.tabBars.buttons["התראות"]
        XCTAssertTrue(notificationsTab.waitForExistence(timeout: 10), "Expected 'התראות' tab bar button")
        notificationsTab.tap()

        // Tap "שלח התראת בדיקה" button
        let sendTestButton = app.buttons["שלח התראת בדיקה"]
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
        let snoozeButton = springboard.buttons["נודניק 5 דק׳"]
        XCTAssertTrue(snoozeButton.waitForExistence(timeout: 10), "Snooze action button 'נודניק 5 דק׳' must exist on expanded notification")

        // 5. Tap snooze action while app is open in foreground
        snoozeButton.tap()

        // 6. Mandatory assertion: Containing app MUST NOT crash
        XCTAssertTrue(
            app.state == .runningForeground || app.state == .runningBackground,
            "Containing application must remain alive without crashing after pressing snooze in foreground"
        )

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
        app.launchArguments = ["-UITestMode", "YES", "-UITestShortSnooze", "YES"]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        dismissPermissionAlertIfPresent(springboard: springboard)

        let notificationsTab = app.tabBars.buttons["התראות"]
        XCTAssertTrue(notificationsTab.waitForExistence(timeout: 10), "Expected 'התראות' tab")
        notificationsTab.tap()

        let sendTestButton = app.buttons["שלח התראת בדיקה"]
        XCTAssertTrue(sendTestButton.waitForExistence(timeout: 10), "Expected test notification button")
        sendTestButton.tap()

        dismissPermissionAlertIfPresent(springboard: springboard)

        // Send app to background
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.0)

        let banner = springboard.descendants(matching: .any).matching(identifier: "NotificationShortLookView").firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15), "System notification banner must appear while app is in background")

        expandBanner(banner, springboard: springboard)

        let snoozeButton = springboard.buttons["נודניק 5 דק׳"]
        XCTAssertTrue(snoozeButton.waitForExistence(timeout: 10), "Snooze action button must exist while app is in background")
        snoozeButton.tap()

        // Wait for redelivery
        let redeliveredBanner = springboard.descendants(matching: .any).matching(identifier: "NotificationShortLookView").firstMatch
        XCTAssertTrue(redeliveredBanner.waitForExistence(timeout: 15), "Background-snoozed notification must be redelivered")
    }
}
