import Foundation
import UserNotifications

#if DEBUG
import os
#endif

enum NotificationScheduler {
    static let categoryID = NotificationSchedulerConstants.categoryID
    static let snoozeActionID = NotificationSchedulerConstants.snoozeActionID
    static let openActionID = NotificationSchedulerConstants.openActionID

    static func configureCategories() {
        let snooze = UNNotificationAction(
            identifier: snoozeActionID,
            title: "נודניק 5 דק׳",
            options: []
        )
        let open = UNNotificationAction(
            identifier: openActionID,
            title: "פתח זמני היום",
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
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("zmanim.") })

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
                identifier: "zmanim.\(index).\(Int(fire.timeIntervalSince1970))",
                content: content,
                trigger: trigger
            ))
        }
    }

    static func sendTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "שקיעה בעוד 15 דקות"
        content.body = "שקיעה היום בשעה 18:21"
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            "zmanTitle": "שקיעה",
            "zmanTime": Date().addingTimeInterval(900).timeIntervalSince1970,
            "zmanIcon": "sunset.fill"
        ]
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "zmanim.test.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        ))
    }

    private static func body(rule: NotificationRule, item: ZmanItem, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        if rule.offsetMinutes == 0 { return "הזמן הגיע · \(formatter.string(from: item.date))" }
        return "\(abs(rule.offsetMinutes)) דקות \(rule.offsetMinutes < 0 ? "לפני" : "אחרי") · \(formatter.string(from: item.date))"
    }
}

final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCoordinator()
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "NotificationCoordinator")

    func install() {
        UNUserNotificationCenter.current().delegate = self
        NotificationScheduler.configureCategories()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        #if DEBUG
        Self.logger.notice("NotificationCoordinator didReceive response action: \(response.actionIdentifier, privacy: .public)")
        #endif
        // Primary action owner is NotificationViewController (which calls completion(.dismiss)).
        // This fallback only runs if the rich extension is not loaded or user performs action from default UI.
        if response.actionIdentifier == NotificationSchedulerConstants.snoozeActionID {
            let request = ZmanimSnoozeRequest.make(from: response.notification.request.content)
            do {
                try await center.add(request)
                #if DEBUG
                Self.logger.notice("NotificationCoordinator fallback scheduled snooze: \(request.identifier, privacy: .public)")
                #endif
            } catch {
                #if DEBUG
                Self.logger.error("NotificationCoordinator fallback failed to schedule snooze: \(error.localizedDescription, privacy: .public)")
                #endif
            }
        }
    }
}
