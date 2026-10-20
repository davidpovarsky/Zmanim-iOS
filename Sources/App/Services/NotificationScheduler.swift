import Foundation
import UIKit
import UserNotifications
import os

enum NotificationScheduler {
    static let categoryID = NotificationSchedulerConstants.categoryID
    static let snoozeActionID = NotificationSchedulerConstants.snoozeActionID
    static let openActionID = NotificationSchedulerConstants.openActionID

    static func configureCategories() {
        let snooze = UNNotificationAction(
            identifier: snoozeActionID,
            title: NSLocalizedString("notification.snooze_5_min", value: "נודניק 5 דק׳", comment: ""),
            options: []
        )
        let open = UNNotificationAction(
            identifier: openActionID,
            title: NSLocalizedString("notification.open_zmanim", value: "פתח זמני היום", comment: ""),
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [snooze, open],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func rescheduleIfAuthorized(settings: UserSettings, items: [ZmanItem], timeZone: TimeZone) async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        await schedule(settings: settings, items: items, timeZone: timeZone)
    }

    static func schedule(settings: UserSettings, items: [ZmanItem], timeZone: TimeZone) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        // Only remove ordinary daily scheduled notifications. Do NOT remove active snoozes or tests.
        let toRemove = pending.map(\.identifier).filter { $0.hasPrefix("zmanim.daily.") }
        center.removePendingNotificationRequests(withIdentifiers: toRemove)

        var candidates: [(Date, NotificationRule, ZmanItem)] = []
        for rule in settings.rules where rule.isEnabled {
            for item in items where item.key == rule.zmanKey {
                let fire = item.date.addingTimeInterval(TimeInterval(rule.offsetMinutes * 60))
                if fire > Date().addingTimeInterval(2) {
                    candidates.append((fire, rule, item))
                }
            }
        }

        candidates.sort { $0.0 < $1.0 }
        for (index, candidate) in candidates.prefix(60).enumerated() {
            let (fire, rule, item) = candidate
            let content = UNMutableNotificationContent()
            content.title = rule.displayTitle
            content.body = body(rule: rule, item: item, timeZone: timeZone)
            content.sound = .default
            content.categoryIdentifier = categoryID
            content.userInfo = [
                "zmanTitle": rule.displayTitle,
                "zmanTime": item.date.timeIntervalSince1970,
                "zmanIcon": item.icon
            ]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire.timeIntervalSinceNow), repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: "zmanim.daily.\(index).\(Int(fire.timeIntervalSince1970))",
                content: content,
                trigger: trigger
            ))
        }
    }

    static func sendTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.test_title", value: "שקיעה בעוד 15 דקות", comment: "")
        content.body = NSLocalizedString("notification.test_body", value: "שקיעה היום בשעה 18:21", comment: "")
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            "zmanTitle": NSLocalizedString("sunset", value: "שקיעה", comment: ""),
            "zmanTime": Date().addingTimeInterval(900).timeIntervalSince1970,
            "zmanIcon": "sunset.fill"
        ]
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "zmanim.test.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        ))
    }

    private static func body(rule: NotificationRule, item: ZmanItem, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        if rule.offsetMinutes == 0 {
            return String(format: NSLocalizedString("notification.time_arrived_time", value: "הזמן הגיע · %@", comment: ""), formatter.string(from: item.date))
        } else if rule.offsetMinutes < 0 {
            return String(format: NSLocalizedString("notification.minutes_before_format", value: "%1$d דקות לפני · %2$@", comment: ""), abs(rule.offsetMinutes), formatter.string(from: item.date))
        } else {
            return String(format: NSLocalizedString("notification.minutes_after_format", value: "%1$d דקות אחרי · %2$@", comment: ""), abs(rule.offsetMinutes), formatter.string(from: item.date))
        }
    }
}

final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCoordinator()
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "NotificationCoordinator")

    func install() {
        UNUserNotificationCenter.current().delegate = self
        NotificationScheduler.configureCategories()
        #if DEBUG
        Self.logger.notice("NotificationCoordinator installed delegate and configured categories")
        #endif
    }

    @objc func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        #if DEBUG
        Self.logger.notice("NotificationCoordinator willPresent notification: \(notification.request.identifier, privacy: .public)")
        #endif
        completionHandler([.banner, .list, .sound, .badge])
    }

    @objc func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        let originalID = response.notification.request.identifier
        #if DEBUG
        Self.logger.notice("NotificationCoordinator didReceive action=\(actionID, privacy: .public) originalID=\(originalID, privacy: .public)")
        #endif

        switch actionID {
        case NotificationSchedulerConstants.snoozeActionID:
            let bgTask = UIApplication.shared.beginBackgroundTask(withName: "scheduleSnooze") { }
            let request = ZmanimSnoozeRequest.make(
                from: response.notification.request.content,
                originalIdentifier: originalID
            )
            center.add(request) { error in
                #if DEBUG
                if let error {
                    Self.logger.error("NotificationCoordinator failed to schedule snooze: \(error.localizedDescription, privacy: .public)")
                } else {
                    Self.logger.notice("NotificationCoordinator scheduled snooze: \(request.identifier, privacy: .public)")
                }
                #endif
                completionHandler()
                if bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTask)
                }
            }
        case NotificationSchedulerConstants.openActionID:
            #if DEBUG
            Self.logger.notice("NotificationCoordinator openAction selected")
            #endif
            completionHandler()
        default:
            completionHandler()
        }
    }
}
