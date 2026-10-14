import Combine
import CoreLocation
import Foundation
import WidgetKit

@MainActor
public final class AppModel: ObservableObject {
    @Published public var cityName = "מאתר מיקום…"
    @Published public var timeZone = TimeZone.current
    @Published public var todayItems: [ZmanItem] = []
    @Published public var allItems: [ZmanItem] = []
    @Published public var settings = AppGroupStore.loadSettings()
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var weatherModel = WeatherSceneModel()

    public let locationService = LocationService()
    private var currentLocation: CLLocation?

    public init() {
        NotificationCoordinator.shared.install()
        locationService.onLocation = { [weak self] location in
            Task { @MainActor in
                await self?.load(location: location)
            }
        }
    }

    public func start() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestMode") {
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
        if (try? await NotificationScheduler.requestAuthorization()) == true {
            await NotificationScheduler.sendTestNotification()
        }
    }
}
