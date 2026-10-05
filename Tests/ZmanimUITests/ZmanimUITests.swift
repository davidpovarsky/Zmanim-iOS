import XCTest

final class ZmanimUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesWithDeterministicJerusalemData() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "YES", "-UITestShortSnooze", "YES"]
        app.launch()

        // Verify city name is displayed
        let jerusalemText = app.staticTexts["ירושלים"]
        XCTAssertTrue(jerusalemText.waitForExistence(timeout: 10), "Expected Jerusalem zmanim to be loaded in UI test mode")
    }

    func testNotificationSchedulingAndSpringBoardInteraction() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "YES", "-UITestShortSnooze", "YES"]
        app.launch()

        // Switch to Notifications tab
        let notificationsTab = app.tabBars.buttons["התראות"]
        if notificationsTab.waitForExistence(timeout: 5) {
            notificationsTab.tap()
        }

        // Tap "שלח התראת בדיקה" button
        let sendTestButton = app.buttons["שלח התראת בדיקה"]
        XCTAssertTrue(sendTestButton.waitForExistence(timeout: 5), "Expected test notification button")
        sendTestButton.tap()

        // Wait for system notification via SpringBoard
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let banner = springboard.otherElements["NotificationShortLookView"]

        if banner.waitForExistence(timeout: 8) {
            // Expand notification banner to invoke content extension
            banner.swipeDown()
            Thread.sleep(forTimeInterval: 1.5)

            // Save screenshot of expanded notification
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.lifetime = .keepAlways
            attachment.name = "expanded-rich-notification"
            add(attachment)

            let tmpUrl = URL(fileURLWithPath: "/tmp/expanded-rich-notification.png")
            try? screenshot.pngRepresentation.write(to: tmpUrl)

            // Look for snooze button
            let snoozeButton = springboard.buttons["נודניק 5 דק׳"]
            if snoozeButton.waitForExistence(timeout: 4) {
                snoozeButton.tap()
            }
        }
    }
}
