import Combine
import CoreLocation
import Foundation
import UIKit
import WidgetKit

@MainActor
public final class AppModel: ObservableObject {
    @Published public var cityName: String = ""
    @Published public var timeZone = TimeZone.current
    @Published public var todayItems: [ZmanItem] = []
    @Published public var allItems: [ZmanItem] = []
    @Published public var settings = AppGroupStore.loadSettings()
    @Published public var locationPreferences = LocationPreferencesStore.loadPreferences()
    @Published public var activeChoice: LocationChoice = .current
    @Published public var isGPSActive: Bool = true
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var weatherModel = WeatherSceneModel()

    let locationService = LocationService()
    private var currentLocation: CLLocation?
    private var loadGeneration: Int = 0
    private var activeLoadTask: Task<Void, Never>?

    public init() {
        let prefs = LocationPreferencesStore.loadPreferences()
        locationPreferences = prefs
        activeChoice = prefs.defaultChoice
        isGPSActive = prefs.defaultChoice.isCurrent

        // Populate initial display strictly from validated stored snapshot for the default choice
        let initialTarget = prefs.defaultChoice.identity
        if let snapshot = LocationSnapshotStore.loadSnapshot(for: initialTarget),
           !snapshot.items.isEmpty,
           let validZone = snapshot.validTimeZone {
            cityName = snapshot.cityName
            timeZone = validZone
            allItems = snapshot.items
            todayItems = ZmanDayResolver.itemsForDay(from: snapshot.items, date: Date(), timeZone: validZone)
        } else {
            cityName = ""
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
                    guard let self, self.activeChoice.isCurrent else { return }
                    await self.load(location: location, isGPS: true)
                }
            }
        }
        #else
        locationService.onLocation = { [weak self] location in
            Task { @MainActor in
                guard let self, self.activeChoice.isCurrent else { return }
                await self.load(location: location, isGPS: true)
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
                    force: true,
                    isGPS: true
                )
            }
            return
        }
        #endif

        switch activeChoice {
        case .current:
            isGPSActive = true
            locationService.start()
        case .savedCity(let id):
            isGPSActive = false
            if let city = locationPreferences.city(for: id) {
                activeLoadTask?.cancel()
                loadGeneration += 1
                let gen = loadGeneration
                activeLoadTask = Task { await loadSavedCity(city, force: false, gen: gen) }
            } else {
                activeChoice = .current
                isGPSActive = true
                locationService.start()
            }
        }

        // Reschedule notifications strictly for the persistent default choice
        Task {
            await rescheduleNotificationsForDefaultLocation()
        }
    }

    public func refresh() {
        switch activeChoice {
        case .current:
            locationService.refresh()
            Task {
                await refreshWeather(force: true)
            }
        case .savedCity(let id):
            if let city = locationPreferences.city(for: id) {
                activeLoadTask?.cancel()
                loadGeneration += 1
                let gen = loadGeneration
                activeLoadTask = Task { await loadSavedCity(city, force: true, gen: gen) }
            }
        }
    }

    // MARK: - Switching Locations

    /// Temporarily selects a location choice for viewing on the Home screen.
    /// Immediately cancels pending tasks, updates generation, and decouples default choice.
    public func selectActiveChoice(_ choice: LocationChoice) async {
        guard choice != activeChoice else { return }
        loadGeneration += 1
        let gen = loadGeneration
        activeLoadTask?.cancel()

        activeChoice = choice
        errorMessage = nil

        switch choice {
        case .current:
            isGPSActive = true
            weatherModel.resetForLocationChange()
            currentLocation = nil
            cityName = ""
            todayItems = []
            allItems = []

            // Check if valid cached GPS snapshot exists
            if let cached = LocationSnapshotStore.loadSnapshot(for: .gps),
               SnapshotValidator.isFresh(snapshot: cached, for: .gps, now: Date()) {
                cityName = cached.cityName
                timeZone = cached.timeZone
                allItems = cached.items
                todayItems = ZmanDayResolver.itemsForDay(from: cached.items, date: Date(), timeZone: cached.timeZone)
                currentLocation = CLLocation(latitude: cached.latitude, longitude: cached.longitude)
                Task { await refreshWeather(force: false) }
            }

            locationService.start()

        case .savedCity(let id):
            isGPSActive = false
            guard let city = locationPreferences.city(for: id) else { return }
            cityName = city.name
            timeZone = city.timeZone
            weatherModel.resetForLocationChange()
            currentLocation = CLLocation(latitude: city.latitude, longitude: city.longitude)

            let identity = LocationIdentity.savedCity(id: city.id)
            if let cached = LocationSnapshotStore.loadSnapshot(for: identity),
               SnapshotValidator.isFresh(snapshot: cached, for: identity, now: Date()) {
                allItems = cached.items
                todayItems = ZmanDayResolver.itemsForDay(from: cached.items, date: Date(), timeZone: city.timeZone)
                Task { await refreshWeather(force: false) }
            } else {
                todayItems = []
                allItems = []
            }

            activeLoadTask = Task {
                await loadSavedCity(city, force: false, gen: gen)
            }
        }
    }

    /// Sets the persistent default location choice in Settings.
    /// Updates preferences immediately, reschedules notifications, and reloads widgets.
    public func setDefaultLocationChoice(_ choice: LocationChoice) async {
        locationPreferences = LocationPreferencesStore.setDefaultChoice(choice)
        WidgetCenter.shared.reloadAllTimelines()
        await rescheduleNotificationsForDefaultLocation()
    }

    public func addSavedCity(name: String, latitude: Double, longitude: Double, timeZoneID: String) async -> SavedCity {
        let (updatedPrefs, newCity) = LocationPreferencesStore.addCity(
            name: name,
            latitude: latitude,
            longitude: longitude,
            timeZoneID: timeZoneID
        )
        locationPreferences = updatedPrefs
        WidgetCenter.shared.reloadAllTimelines()

        // Fetch snapshot for the new city in background
        let cityLoc = CLLocation(latitude: latitude, longitude: longitude)
        let zone = TimeZone(identifier: timeZoneID) ?? .current
        let identity = LocationIdentity.savedCity(id: newCity.id)
        if let items = try? await HebcalService.fetchDays(location: cityLoc, timeZone: zone, count: 8) {
            let snap = ZmanSnapshot(
                cityName: newCity.name,
                timeZoneID: timeZoneID,
                latitude: latitude,
                longitude: longitude,
                updatedAt: Date(),
                items: items,
                locationSignature: "\(newCity.name)-\(timeZoneID)",
                sourceIdentity: identity
            )
            LocationSnapshotStore.saveSnapshot(snap, for: identity)
        }

        return newCity
    }

    public func removeSavedCity(id: String) async {
        locationPreferences = LocationPreferencesStore.removeCity(id: id)
        LocationSnapshotStore.removeSnapshot(for: .savedCity(id: id))

        // If the removed city was active, revert active choice to current default
        if case .savedCity(let activeId) = activeChoice, activeId == id {
            await selectActiveChoice(locationPreferences.defaultChoice)
        }

        WidgetCenter.shared.reloadAllTimelines()
        await rescheduleNotificationsForDefaultLocation()
    }

    private func loadSavedCity(_ city: SavedCity, force: Bool, gen: Int) async {
        let identity = LocationIdentity.savedCity(id: city.id)
        if !force, let cached = LocationSnapshotStore.loadSnapshot(for: identity),
           SnapshotValidator.isFresh(snapshot: cached, for: identity, now: Date()) {
            guard gen == loadGeneration else { return }
            cityName = city.name
            timeZone = city.timeZone
            allItems = cached.items
            todayItems = ZmanDayResolver.itemsForDay(from: cached.items, date: Date(), timeZone: city.timeZone)
            currentLocation = CLLocation(latitude: city.latitude, longitude: city.longitude)
            await refreshWeather(force: force)
            return
        }

        isLoading = true
        defer {
            if gen == loadGeneration {
                isLoading = false
            }
        }

        let loc = CLLocation(latitude: city.latitude, longitude: city.longitude)
        do {
            let items = try await HebcalService.fetchDays(location: loc, timeZone: city.timeZone, count: 8)
            guard gen == loadGeneration else { return }

            cityName = city.name
            timeZone = city.timeZone
            allItems = items
            todayItems = ZmanDayResolver.itemsForDay(from: items, date: Date(), timeZone: city.timeZone)
            currentLocation = loc
            errorMessage = nil

            let snapshot = ZmanSnapshot(
                cityName: city.name,
                timeZoneID: city.timeZone.identifier,
                latitude: city.latitude,
                longitude: city.longitude,
                updatedAt: Date(),
                items: items,
                locationSignature: "\(city.name)-\(city.timeZone.identifier)",
                sourceIdentity: identity
            )
            LocationSnapshotStore.saveSnapshot(snapshot, for: identity)
            WidgetCenter.shared.reloadAllTimelines()

            // If this is default location, reschedule notifications
            if case .savedCity(let defaultId) = locationPreferences.defaultChoice, defaultId == city.id {
                await NotificationScheduler.rescheduleIfAuthorized(settings: settings, items: allItems, timeZone: city.timeZone)
            }

            await refreshWeather(force: force)
        } catch {
            guard gen == loadGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    public func refreshWeather(force: Bool = false) async {
        guard let location = currentLocation else { return }
        let rise = ZmanDayResolver.sunrise(from: todayItems, date: Date(), timeZone: timeZone)
        let set = ZmanDayResolver.sunset(from: todayItems, date: Date(), timeZone: timeZone)
        let coord = location.coordinate
        let city = cityName
        let zone = timeZone
        await weatherModel.update(
            location: coord,
            cityName: city,
            timeZone: zone,
            now: Date(),
            sunrise: rise,
            sunset: set,
            force: force
        )
    }

    /// Selects a location from search. Only sets activeChoice, does NOT alter defaultChoice.
    public func selectFixedLocation(_ resolved: ResolvedLocation) async {
        let city = await addSavedCity(
            name: resolved.displayName,
            latitude: resolved.latitude,
            longitude: resolved.longitude,
            timeZoneID: resolved.timeZoneID
        )
        await selectActiveChoice(.savedCity(id: city.id))
    }

    public func load(
        location: CLLocation,
        preferredCity: String? = nil,
        preferredTimeZone: TimeZone? = nil,
        force: Bool = false,
        isGPS: Bool = true,
        sourceKey: String? = nil
    ) async {
        loadGeneration += 1
        let gen = loadGeneration

        if !force, let currentLocation, currentLocation.distance(from: location) < 100 {
            var cal = Calendar(identifier: .gregorian)
            let checkZone = preferredTimeZone ?? timeZone
            cal.timeZone = checkZone
            let isCurrentDay = todayItems.first.map { cal.isDate($0.date, inSameDayAs: Date()) } ?? false
            if isCurrentDay && !todayItems.isEmpty {
                await refreshWeather(force: force)
                return
            }
        }

        isLoading = true
        defer {
            if gen == loadGeneration {
                isLoading = false
            }
        }

        var resolvedLocality: String? = preferredCity
        var resolvedZone: TimeZone? = preferredTimeZone

        if isGPS {
            let description = await locationService.describe(location)
            guard gen == loadGeneration else { return }
            if let city = description.city, !city.isEmpty {
                resolvedLocality = city
                let localityInfo = VerifiedLocality(
                    name: city,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    timeZoneID: (description.timeZone ?? timeZone).identifier,
                    localeIdentifier: Locale.autoupdatingCurrent.identifier
                )
                VerifiedLocalityStore.save(localityInfo)
            } else {
                resolvedLocality = VerifiedLocalityStore.load(for: location.coordinate)?.name
            }
            resolvedZone = description.timeZone ?? preferredTimeZone ?? timeZone
        }

        let city = resolvedLocality ?? ""
        let zone = resolvedZone ?? timeZone

        do {
            let items = try await HebcalService.fetchDays(location: location, timeZone: zone, count: 8)
            guard gen == loadGeneration else { return }

            cityName = city
            timeZone = zone
            allItems = items
            currentLocation = location
            isGPSActive = isGPS
            errorMessage = nil

            todayItems = ZmanDayResolver.itemsForDay(from: items, date: Date(), timeZone: zone)

            let identity: LocationIdentity = isGPS ? .gps : (sourceKey.flatMap { $0.hasPrefix("city_") ? .savedCity(id: String($0.dropFirst("city_".count))) : nil } ?? .gps)
            let snapshot = ZmanSnapshot(
                cityName: city,
                timeZoneID: zone.identifier,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                updatedAt: Date(),
                items: items,
                locationSignature: isGPS ? "current" : "\(city)-\(zone.identifier)",
                sourceIdentity: identity
            )
            LocationSnapshotStore.saveSnapshot(snapshot, for: identity)
            WidgetCenter.shared.reloadAllTimelines()

            // If the loaded location is the persistent default location, reschedule notifications
            let isDefaultLocation: Bool
            switch locationPreferences.defaultChoice {
            case .current:
                isDefaultLocation = isGPS
            case .savedCity(let id):
                isDefaultLocation = (identity == .savedCity(id: id))
            }
            if isDefaultLocation {
                await NotificationScheduler.rescheduleIfAuthorized(settings: settings, items: allItems, timeZone: zone)
            }

            // Update weather asynchronously with genuine MET Norway data
            await refreshWeather(force: force)
        } catch {
            guard gen == loadGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    public func checkDayRollover(now: Date = Date()) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let currentDayItems = ZmanDayResolver.itemsForDay(from: allItems, date: now, timeZone: timeZone)

        let isTodayCurrent: Bool
        if let firstToday = todayItems.first {
            isTodayCurrent = cal.isDate(firstToday.date, inSameDayAs: now)
        } else {
            isTodayCurrent = false
        }

        if !isTodayCurrent || todayItems.count != currentDayItems.count {
            todayItems = currentDayItems

            let futureCount = allItems.filter { $0.date > now }.count
            if futureCount < 15, let currentLocation {
                Task {
                    await load(
                        location: currentLocation,
                        preferredCity: cityName.isEmpty ? nil : cityName,
                        preferredTimeZone: timeZone,
                        force: true,
                        isGPS: isGPSActive,
                        sourceKey: activeChoice.storageKey
                    )
                }
            } else {
                WidgetCenter.shared.reloadAllTimelines()
                let rise = ZmanDayResolver.sunrise(from: todayItems, date: now, timeZone: timeZone)
                let set = ZmanDayResolver.sunset(from: todayItems, date: now, timeZone: timeZone)
                if let loc = currentLocation?.coordinate {
                    Task {
                        await weatherModel.update(
                            location: loc,
                            cityName: cityName,
                            timeZone: timeZone,
                            now: now,
                            sunrise: rise,
                            sunset: set,
                            force: false
                        )
                    }
                }
            }
        }
    }

    public func rescheduleNotificationsForDefaultLocation() async {
        guard settings.rules.contains(where: \.isEnabled) || settings.specialDaysMasterEnabled else { return }
        guard (try? await NotificationScheduler.requestAuthorization()) == true else { return }

        let defaultIdentity = locationPreferences.defaultChoice.identity
        if let defaultSnapshot = LocationSnapshotStore.loadSnapshot(for: defaultIdentity),
           !defaultSnapshot.items.isEmpty,
           let defaultZone = defaultSnapshot.validTimeZone {
            await NotificationScheduler.schedule(
                settings: settings,
                items: defaultSnapshot.items,
                timeZone: defaultZone
            )
        } else if case .current = locationPreferences.defaultChoice, isGPSActive, !allItems.isEmpty {
            await NotificationScheduler.schedule(
                settings: settings,
                items: allItems,
                timeZone: timeZone
            )
        }
    }

    public func saveSettings() async {
        AppGroupStore.saveSettings(settings)
        await rescheduleNotificationsForDefaultLocation()
    }

    public func sendTestNotification() async {
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "sendTestNotification") {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        defer {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        if (try? await NotificationScheduler.requestAuthorization()) == true {
            await NotificationScheduler.sendTestNotification()
        }
    }
}
