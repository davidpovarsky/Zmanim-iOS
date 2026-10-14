import XCTest

final class ZmanimUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesWithDeterministicJerusalemData() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "YES", "-UITestShortSnooze", "YES"]
        app.launch()

        let jerusalemText = app.staticTexts["ירושלים"]
        XCTAssertTrue(jerusalemText.waitForExistence(timeout: 10), "Expected Jerusalem zmanim to be loaded in UI test mode")
    }

    func testRichNotificationExpansionAndForegroundSnooze() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "YES", "-UITestShortSnooze", "YES"]
        app.launch()

        // Handle potential permission alerts automatically
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.alerts.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 2) {
            allowButton.tap()
        }

        // Switch to Notifications tab
        let notificationsTab = app.tabBars.buttons["התראות"]
        XCTAssertTrue(notificationsTab.waitForExistence(timeout: 8), "Expected 'התראות' tab bar button")
        notificationsTab.tap()

        // Tap "שלח התראת בדיקה" button
        let sendTestButton = app.buttons["שלח התראת בדיקה"]
        XCTAssertTrue(sendTestButton.waitForExistence(timeout: 8), "Expected test notification button")
        sendTestButton.tap()

        // Handle permission dialog if it pops up after tapping the button
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
        }

        // 1. Mandatory assertion: System notification banner MUST appear on SpringBoard
        let banner = springboard.otherElements["NotificationShortLookView"]
        XCTAssertTrue(banner.waitForExistence(timeout: 12), "System notification banner must appear on SpringBoard within timeout")

        // 2. Expand notification banner to invoke custom content extension
        banner.swipeDown()
        Thread.sleep(forTimeInterval: 2.0)
        let snoozeButton = springboard.buttons["נודניק 5 דק׳"]
        if !snoozeButton.exists && banner.exists {
            banner.press(forDuration: 1.5)
            Thread.sleep(forTimeInterval: 1.5)
        }

        // 3. Capture authentic screenshot of expanded notification
        let expandedScreenshot = XCUIScreen.main.screenshot()
        let expandedAttachment = XCTAttachment(screenshot: expandedScreenshot)
        expandedAttachment.lifetime = .keepAlways
        expandedAttachment.name = "expanded-rich-notification"
        add(expandedAttachment)

        let tmpExpandedUrl = URL(fileURLWithPath: "/tmp/expanded-rich-notification.png")
        try? expandedScreenshot.pngRepresentation.write(to: tmpExpandedUrl)

        // 4. Mandatory assertion: Snooze action button MUST exist
        XCTAssertTrue(snoozeButton.waitForExistence(timeout: 8), "Snooze action button 'נודניק 5 דק׳' must exist on expanded notification")

        // 6. Tap snooze action while app is open in foreground
        snoozeButton.tap()

        // 7. Mandatory assertion: Containing app MUST NOT crash
        XCTAssertTrue(
            app.state == .runningForeground || app.state == .runningBackground,
            "Containing application must remain alive without crashing after pressing snooze in foreground"
        )

        // 8. Mandatory assertion: Snooze MUST be redelivered (5-second short snooze interval in test mode)
        let redeliveredBanner = springboard.otherElements["NotificationShortLookView"]
        XCTAssertTrue(redeliveredBanner.waitForExistence(timeout: 14), "Snoozed notification must be redelivered within timeout")

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
        let allowButton = springboard.alerts.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 2) {
            allowButton.tap()
        }

        let notificationsTab = app.tabBars.buttons["התראות"]
        XCTAssertTrue(notificationsTab.waitForExistence(timeout: 8), "Expected 'התראות' tab")
        notificationsTab.tap()

        let sendTestButton = app.buttons["שלח התראת בדיקה"]
        XCTAssertTrue(sendTestButton.waitForExistence(timeout: 8), "Expected test notification button")
        sendTestButton.tap()

        // Send app to background
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.0)

        let banner = springboard.otherElements["NotificationShortLookView"]
        XCTAssertTrue(banner.waitForExistence(timeout: 12), "System notification banner must appear while app is in background")

        banner.swipeDown()
        Thread.sleep(forTimeInterval: 2.0)

        let snoozeButton = springboard.buttons["נודניק 5 דק׳"]
        if !snoozeButton.exists && banner.exists {
            banner.press(forDuration: 1.5)
            Thread.sleep(forTimeInterval: 1.5)
        }
        XCTAssertTrue(snoozeButton.waitForExistence(timeout: 8), "Snooze action button must exist while app is in background")
        snoozeButton.tap()

        // Wait for redelivery
        let redeliveredBanner = springboard.otherElements["NotificationShortLookView"]
        XCTAssertTrue(redeliveredBanner.waitForExistence(timeout: 14), "Background-snoozed notification must be redelivered")
    }
}
