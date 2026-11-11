import BackgroundTasks
import CoreLocation
import Foundation
import UserNotifications
import WidgetKit
import OneBusAwayWeatherCore

/// Opportunistic iOS-managed refresh, not a guaranteed periodic scheduler.
enum ZmanimBackgroundRefresh {
    static let identifier = "com.davidpovarsky.Zmanim.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            schedule()
            let operation = Task {
                let success = await performRefresh()
                refresh.setTaskCompleted(success: success && !Task.isCancelled)
            }
            refresh.expirationHandler = { operation.cancel() }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(45 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // iOS may deny refresh because of user settings, budgets, or system policy.
        }
    }

    static func removeExpiredDeliveredNotifications(now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        let expired = delivered.filter { notification in
            let id = notification.request.identifier
            guard id.hasPrefix("zmanim.") else { return false }
            if let seconds = notification.request.content.userInfo["zmanTime"] as? NSNumber {
                return Date(timeIntervalSince1970: seconds.doubleValue).addingTimeInterval(120) < now
            }
            return notification.date.addingTimeInterval(120) < now
        }.map { $0.request.identifier }
        if !expired.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: expired)
        }
    }

    static func performRefresh() async -> Bool {
        await removeExpiredDeliveredNotifications()
        let prefs = LocationPreferencesStore.loadPreferences()
        let identity = prefs.defaultChoice.identity
        guard var snapshot = LocationSnapshotStore.loadSnapshot(for: identity),
              let zone = snapshot.validTimeZone else { return false }
        let location = CLLocation(latitude: snapshot.latitude, longitude: snapshot.longitude)
        do {
            async let zmanim = HebcalService.fetchDays(location: location, timeZone: zone, count: 8)
            let israel = (29.0...34.0).contains(snapshot.latitude)
                && (34.0...36.0).contains(snapshot.longitude)
            async let events = JewishCalendarService.fetch(location: location, timeZone: zone, israel: israel)
            async let weather = METNorwayWeatherClient.shared.fetchForecast(
                latitude: snapshot.latitude, longitude: snapshot.longitude, timeZone: zone)
            let items = try await zmanim
            let calendarEvents = try await events
            snapshot.items = items
            snapshot.calendarEvents = calendarEvents
            snapshot.updatedAt = Date()
            guard LocationSnapshotStore.saveSnapshot(snapshot, for: identity) else { return false }
            _ = AppGroupStore.saveSnapshot(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            await NotificationScheduler.rescheduleIfAuthorized(
                settings: AppGroupStore.loadSettings(), items: items, timeZone: zone)
            if let forecast = try? await weather,
               let hour = forecast.hours.min(by: {
                   abs($0.time.timeIntervalSinceNow) < abs($1.time.timeIntervalSinceNow)
               }) {
                let rise = ZmanDayResolver.sunrise(from: items, date: Date(), timeZone: zone)
                let set = ZmanDayResolver.sunset(from: items, date: Date(), timeZone: zone)
                let night = rise.map { Date() < $0 } == true || set.map { Date() > $0 } == true
                let key = METLocationWeatherConverter.iconKey(from: hour.symbolCode)
                if let condition = ZmanimWeatherDisplayAdapter.resolveSkyCondition(
                    iconKey: key, isNight: night, sunrise: rise, sunset: set, now: Date()) {
                    NotificationSkyState(
                        condition: String(describing: condition.skyCondition),
                        cloudCover: (hour.cloudAreaFractionPercent ?? 0) / 100,
                        latitude: snapshot.latitude,
                        longitude: snapshot.longitude,
                        updatedAt: Date()
                    ).save()
                }
            }
            return true
        } catch {
            return false
        }
    }
}