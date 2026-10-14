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

        let request = ZmanimSnoozeRequest.make(from: original, originalIdentifier: "zmanim.daily.0.1800000000")
        let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
        let content = request.content

        XCTAssertEqual(request.identifier, "zmanim.snooze.daily.0.1800000000")
        XCTAssertEqual(trigger.timeInterval, ZmanimSnoozeRequest.productionInterval, accuracy: 0.001)
        XCTAssertEqual(content.categoryIdentifier, "ZMANIM_ALERT")
        XCTAssertEqual(content.title, original.title)
        XCTAssertEqual(content.body, "נודניק · בעוד 15 דקות")
        XCTAssertEqual(content.userInfo["zmanTitle"] as? String, "שקיעה")
        XCTAssertEqual(content.userInfo["zmanTime"] as? Double, 1_800_000_000.0)
        XCTAssertEqual(content.userInfo["zmanIcon"] as? String, "sunset.fill")
    }

    func testSnoozeRequestIsIdempotent() {
        let original = UNMutableNotificationContent()
        original.title = "שקיעה"
        original.body = "בעוד 15 דקות"

        let first = ZmanimSnoozeRequest.make(from: original, originalIdentifier: "zmanim.daily.5.1700000")
        let second = ZmanimSnoozeRequest.make(from: original, originalIdentifier: "zmanim.daily.5.1700000")

        // Deriving snooze from the same original notification produces the identical identifier
        XCTAssertEqual(first.identifier, second.identifier)
        XCTAssertEqual(first.identifier, "zmanim.snooze.daily.5.1700000")
    }

    func testSnoozeBodyDoesNotStackPrefixRepeatedly() {
        let original = UNMutableNotificationContent()
        original.title = "מנחה"
        original.body = "נודניק · זמן מנחה הגיע"

        let request = ZmanimSnoozeRequest.make(from: original, originalIdentifier: "zmanim.snooze.daily.1")
        XCTAssertEqual(request.content.body, "נודניק · זמן מנחה הגיע")
        XCTAssertEqual(request.identifier, "zmanim.snooze.daily.1")
    }

    func testStableSnoozeIdentifierDerivation() {
        XCTAssertEqual(
            ZmanimSnoozeRequest.stableSnoozeIdentifier(from: "zmanim.daily.1.123"),
            "zmanim.snooze.daily.1.123"
        )
        XCTAssertEqual(
            ZmanimSnoozeRequest.stableSnoozeIdentifier(from: "zmanim.test.456"),
            "zmanim.snooze.test.456"
        )
        XCTAssertEqual(
            ZmanimSnoozeRequest.stableSnoozeIdentifier(from: "zmanim.snooze.test.456"),
            "zmanim.snooze.test.456"
        )
        XCTAssertEqual(
            ZmanimSnoozeRequest.stableSnoozeIdentifier(from: "custom.notification.id"),
            "zmanim.snooze.custom.notification.id"
        )
    }
}
