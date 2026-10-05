import Foundation
import UserNotifications

enum ZmanimSnoozeRequest {
    static let productionInterval: TimeInterval = 5 * 60

    #if DEBUG
    static var interval: TimeInterval {
        ProcessInfo.processInfo.arguments.contains("-UITestShortSnooze") ? 5 : productionInterval
    }
    #else
    static var interval: TimeInterval { productionInterval }
    #endif

    static func make(from original: UNNotificationContent, now: Date = Date(), identifier: String = UUID().uuidString) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = original.title
        content.body = "נודניק · " + original.body
        content.sound = .default
        content.categoryIdentifier = NotificationSchedulerConstants.categoryID
        content.userInfo = original.userInfo

        return UNNotificationRequest(
            identifier: "zmanim.snooze.\(identifier)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        )
    }
}

enum NotificationSchedulerConstants {
    static let categoryID = "ZMANIM_ALERT"
    static let snoozeActionID = "ZMANIM_SNOOZE_5"
    static let openActionID = "ZMANIM_OPEN"
}
