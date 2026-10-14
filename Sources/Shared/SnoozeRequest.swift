import Foundation
import UserNotifications

public enum ZmanimSnoozeRequest {
    public static let productionInterval: TimeInterval = 5 * 60

    #if DEBUG
    public static var interval: TimeInterval {
        ProcessInfo.processInfo.arguments.contains("-UITestShortSnooze") ? 5 : productionInterval
    }
    #else
    public static var interval: TimeInterval { productionInterval }
    #endif

    public static func stableSnoozeIdentifier(from originalIdentifier: String) -> String {
        let stripped: String
        if originalIdentifier.hasPrefix("zmanim.snooze.") {
            stripped = String(originalIdentifier.dropFirst("zmanim.snooze.".count))
        } else if originalIdentifier.hasPrefix("zmanim.daily.") {
            stripped = "daily." + String(originalIdentifier.dropFirst("zmanim.daily.".count))
        } else if originalIdentifier.hasPrefix("zmanim.test.") {
            stripped = "test." + String(originalIdentifier.dropFirst("zmanim.test.".count))
        } else if originalIdentifier.hasPrefix("zmanim.") {
            stripped = String(originalIdentifier.dropFirst("zmanim.".count))
        } else {
            stripped = originalIdentifier
        }
        return "zmanim.snooze.\(stripped)"
    }

    public static func make(
        from original: UNNotificationContent,
        originalIdentifier: String = UUID().uuidString
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = original.title

        let cleanBody: String
        let prefix = "נודניק · "
        if original.body.hasPrefix(prefix) {
            cleanBody = String(original.body.dropFirst(prefix.count))
        } else {
            cleanBody = original.body
        }
        content.body = prefix + cleanBody
        content.sound = .default
        content.categoryIdentifier = NotificationSchedulerConstants.categoryID
        content.userInfo = original.userInfo

        let identifier = stableSnoozeIdentifier(from: originalIdentifier)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)

        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }
}

public enum NotificationSchedulerConstants {
    public static let categoryID = "ZMANIM_ALERT"
    public static let snoozeActionID = "ZMANIM_SNOOZE_5"
    public static let openActionID = "ZMANIM_OPEN"
}
