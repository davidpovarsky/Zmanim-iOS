import XCTest
import UserNotifications
@testable import Zmanim

final class SnoozeRequestTests: XCTestCase {
    func testSnoozeRequestPreservesPayloadAndCategory() throws {
        let original = UNMutableNotificationContent()
        original.title = "שקיעה"
        original.body = "בעוד 15 דקות"
        original.categoryIdentifier = NotificationSchedulerConstants.categoryID
        original.userInfo = [
            "zmanTitle": "שקיעה",
            "zmanTime": 1_800_000_000.0,
            "zmanIcon": "sunset.fill"
        ]

        let request = ZmanimSnoozeRequest.make(from: original, identifier: "test")
        let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
        let content = request.content

        XCTAssertEqual(request.identifier, "zmanim.snooze.test")
        XCTAssertEqual(trigger.timeInterval, ZmanimSnoozeRequest.productionInterval, accuracy: 0.001)
        XCTAssertEqual(content.categoryIdentifier, "ZMANIM_ALERT")
        XCTAssertEqual(content.title, original.title)
        XCTAssertEqual(content.userInfo["zmanTitle"] as? String, "שקיעה")
        XCTAssertEqual(content.userInfo["zmanTime"] as? Double, 1_800_000_000.0)
        XCTAssertEqual(content.userInfo["zmanIcon"] as? String, "sunset.fill")
    }

    func testEachSnoozeRequestGetsAnIndependentIdentifier() {
        let original = UNMutableNotificationContent()
        original.title = "שקיעה"
        original.body = "בעוד 15 דקות"

        let first = ZmanimSnoozeRequest.make(from: original, identifier: "one")
        let second = ZmanimSnoozeRequest.make(from: original, identifier: "two")

        XCTAssertNotEqual(first.identifier, second.identifier)
        XCTAssertTrue(first.identifier.hasPrefix("zmanim.snooze."))
        XCTAssertTrue(second.identifier.hasPrefix("zmanim.snooze."))
    }
}
