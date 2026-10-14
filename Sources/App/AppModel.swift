import Combine
import CoreLocation
import Foundation
import UIKit
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published var cityName = "מאתר מיקום…"
    @Published var timeZone = TimeZone.current
    @Published var todayItems: [ZmanItem] = []
    @Published var allItems: [ZmanItem] = []
    @Published var settings = AppGroupStore.loadSettings()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var weatherModel = WeatherSceneModel()

    let locationService = LocationService()
    private var currentLocation: CLLocation?

    init() {
        if let snapshot = AppGroupStore.loadSnapshot(), !snapshot.items.isEmpty {
            cityName = snapshot.cityName
            timeZone = TimeZone(identifier: snapshot.timeZoneID) ?? .current
            allItems = snapshot.items
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = timeZone
            todayItems = snapshot.items.filter { cal.isDate($0.date, inSameDayAs: Date()) }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestMode") {
            cityName = "ירושלים"
            timeZone = TimeZone(identifier: "Asia/Jerusalem") ?? .current
            if todayItems.isEmpty {
                let now = Date()
                let cal = Calendar(identifier: .gregorian)
                let startOfDay = cal.startOfDay(for: now)
                let mockItems = [
                    ZmanItem(key: "sunrise", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise.fill", date: startOfDay.addingTimeInterval(6 * 3600)),
                    ZmanItem(key: "sofZmanShma", hebrewTitle: "סוף זמן ק״ש", englishTitle: "Sof Zman Shma", icon: "sun.max", date: startOfDay.addingTimeInterval(9 * 3600)),
                    ZmanItem(key: "chatzot", hebrewTitle: "חצות היום", englishTitle: "Midday", icon: "sun.max.fill", date: startOfDay.addingTimeInterval(12.5 * 3600)),
                    ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill", date: startOfDay.addingTimeInterval(18.5 * 3600)),
                    ZmanItem(key: "tzeit7083deg", hebrewTitle: "צאת הכוכבים", englishTitle: "Nightfall", icon: "moon.stars.fill", date: startOfDay.addingTimeInterval(19.2 * 3600))
                ]
                todayItems = mockItems
                allItems = mockItems
            }
        }
        #endif

        NotificationCoordinator.shared.install()
        #if DEBUG
        if !ProcessInfo.processInfo.arguments.contains("-UITestMode") {
            locationService.onLocation = { [weak self] location in
                Task { @MainActor in
                    await self?.load(location: location)
                }
            }
        }
        #else
        locationService.onLocation = { [weak self] location in
            Task { @MainActor in
                await self?.load(location: location)
            }
        }
        #endif
    }

    public func start() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestMode") {
            Task {
                _ = try? await NotificationScheduler.requestAuthorization()
            }
            if !todayItems.isEmpty {
                cityName = "ירושלים"
                timeZone = TimeZone(identifier: "Asia/Jerusalem") ?? .current
                return
            }
            let jerusalem = CLLocation(latitude: 31.778, longitude: 35.235)
            Task {
                await load(
                    location: jerusalem,
                    preferredCity: "ירושלים",
                    preferredTimeZone: TimeZone(identifier: "Asia/Jerusalem"),
                    force: true
                )
            }
            return
        }
        #endif

        if settings.locationMode == .fixed && !settings.fixedCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task { await refreshFixedCity() }
        } else {
            locationService.start()
        }
    }

    public func refresh() {
        if settings.locationMode == .fixed {
            Task { await refreshFixedCity() }
        } else {
            locationService.refresh()
        }
    }

    public func refreshFixedCity() async {
        let query = settings.fixedCity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            errorMessage = "הקלד עיר קבועה או בחר במיקום הנוכחי."
            return
        }

        do {
            let resolved = try await locationService.resolve(city: query)
            await load(
                location: resolved.location,
                preferredCity: resolved.city,
                preferredTimeZone: resolved.timeZone,
                force: true
            )
        } catch {
            errorMessage = "לא הצלחנו למצוא את העיר שבחרת."
        }
    }

    public func load(
        location: CLLocation,
        preferredCity: String? = nil,
        preferredTimeZone: TimeZone? = nil,
        force: Bool = false
    ) async {
        if !force, let currentLocation, currentLocation.distance(from: location) < 100, !todayItems.isEmpty {
            return
        }

        isLoading = true
        defer { isLoading = false }

        let description = await locationService.describe(location)
        let city = preferredCity ?? description.city
        let zone = preferredTimeZone ?? description.timeZone

        do {
            let items = try await HebcalService.fetchDays(location: location, timeZone: zone, count: 8)
            cityName = city
            timeZone = zone
            allItems = items
            currentLocation = location

            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = zone
            todayItems = items.filter { cal.isDate($0.date, inSameDayAs: Date()) }

            AppGroupStore.saveSnapshot(.init(
                cityName: city,
                timeZoneID: zone.identifier,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                updatedAt: Date(),
                items: items
            ))
            WidgetCenter.shared.reloadAllTimelines()
            await NotificationScheduler.rescheduleIfAuthorized(settings: settings, items: allItems, timeZone: zone)

            // Update weather asynchronously without blocking zmanim
            let rise = todayItems.first { $0.key == "sunrise" }?.date
            let set = todayItems.first { $0.key == "sunset" }?.date
            let coord = location.coordinate
            Task {
                await weatherModel.update(
                    location: coord,
                    now: Date(),
                    sunrise: rise,
                    sunset: set,
                    force: force
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveSettings() async {
        AppGroupStore.saveSettings(settings)
        if settings.locationMode == .fixed {
            await refreshFixedCity()
        } else if let currentLocation {
            await load(location: currentLocation, force: true)
        } else {
            locationService.start()
        }

        if settings.rules.contains(where: \.isEnabled) {
            if (try? await NotificationScheduler.requestAuthorization()) == true {
                await NotificationScheduler.schedule(settings: settings, items: allItems, timeZone: timeZone)
            }
        }
    }

    public func sendTestNotification() async {
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "sendTestNotification") { }
        defer {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }
        if (try? await NotificationScheduler.requestAuthorization()) == true {
            await NotificationScheduler.sendTestNotification()
        }
    }
}
