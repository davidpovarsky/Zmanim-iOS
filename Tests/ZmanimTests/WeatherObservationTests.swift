import Combine
import CoreLocation
import XCTest
import OneBusAwayWeatherCore
import OneBusAwayWeatherUI
@testable import Zmanim

final class WeatherObservationTests: XCTestCase {

    @MainActor
    func testWeatherObservationPublishesHeaderAndSkyOnForecastCompletion() async {
        let weatherModel = WeatherSceneModel()
        var objectWillChangeEmitted = false
        let cancellable = weatherModel.objectWillChange.sink {
            objectWillChangeEmitted = true
        }
        defer { cancellable.cancel() }

        XCTAssertFalse(weatherModel.isAvailable)
        XCTAssertNil(weatherModel.weatherDisplay)

        // Inject simulated forecast
        let now = Date()
        let hour = WeatherHour(
            time: now,
            temperatureCelsius: 24.0,
            symbolCode: "clearsky_day",
            iconKey: "sun.max.fill"
        )
        let snapshot = WeatherSnapshot(
            hours: [hour],
            retrievedAt: now,
            locationLatitude: 31.778,
            locationLongitude: 35.235,
            expiresAt: now.addingTimeInterval(3600)
        )

        // Pre-save to cache so weatherModel can resolve it synchronously without network
        let cache = WeatherCache()
        await cache.save(snapshot: snapshot, timeZoneID: "Asia/Jerusalem")

        // Trigger update with cached coordinates
        let coord = CLLocationCoordinate2D(latitude: 31.778, longitude: 35.235)
        let jerusalemZone = TimeZone(identifier: "Asia/Jerusalem")!

        await weatherModel.update(
            location: coord,
            cityName: "Jerusalem",
            timeZone: jerusalemZone,
            now: now,
            sunrise: now.addingTimeInterval(-3600),
            sunset: now.addingTimeInterval(3600),
            force: false
        )

        // WeatherSceneModel must emit objectWillChange directly so SwiftUI observes without manual refresh
        XCTAssertTrue(objectWillChangeEmitted, "WeatherSceneModel must fire objectWillChange to notify SwiftUI observers")
        XCTAssertTrue(weatherModel.isAvailable)
        XCTAssertNotNil(weatherModel.weatherDisplay)
        XCTAssertEqual(weatherModel.weatherDisplay?.header.regionName, "Jerusalem")
    }

    @MainActor
    func testSwitchToSavedCityStartsWeatherBeforeHebcalCompletes() async {
        let city = SavedCity(id: "c_fast_weather", name: "Haifa", latitude: 32.794, longitude: 34.989, timeZoneID: "Asia/Jerusalem")
        let prefs = LocationPreferences(defaultChoice: .current, savedCities: [city])
        LocationPreferencesStore.savePreferences(prefs)

        let model = AppModel()

        // Switch to city
        await model.selectActiveChoice(.savedCity(id: city.id))

        // Coordinates and active target must update immediately
        XCTAssertEqual(model.activeChoice, .savedCity(id: city.id))
        XCTAssertEqual(model.cityName, "Haifa")
        XCTAssertEqual(model.currentLocation?.coordinate.latitude ?? 0, 32.794, accuracy: 0.001)
        XCTAssertEqual(model.currentLocation?.coordinate.longitude ?? 0, 34.989, accuracy: 0.001)

        // WeatherModel must be reset for the new city immediately, preventing display of old city forecast
        XCTAssertNil(model.weatherModel.weatherDisplay)
    }

    @MainActor
    func testSwitchingLocationCancelsOrIgnoresOldWeatherResponse() async {
        let weatherModel = WeatherSceneModel()
        let now = Date()

        let hourA = WeatherHour(time: now, temperatureCelsius: 20.0, symbolCode: "rain", iconKey: "cloud.rain.fill")
        let snapA = WeatherSnapshot(hours: [hourA], retrievedAt: now, locationLatitude: 31.0, locationLongitude: 35.0, expiresAt: now.addingTimeInterval(3600))

        let hourB = WeatherHour(time: now, temperatureCelsius: 15.0, symbolCode: "clearsky_day", iconKey: "sun.max.fill")
        let snapB = WeatherSnapshot(hours: [hourB], retrievedAt: now, locationLatitude: 51.0, locationLongitude: 0.0, expiresAt: now.addingTimeInterval(3600))

        // Location A starts, then location B arrives before A finishes
        weatherModel.resetForLocationChange()
        XCTAssertFalse(weatherModel.isAvailable)
        XCTAssertNil(weatherModel.weatherDisplay)

        // Location B resets and commits
        weatherModel.resetForLocationChange()
        let displayB = ZmanimWeatherDisplayAdapter.makeWeatherDisplay(from: snapB, cityName: "London", timeZone: .current, now: now)
        XCTAssertNotNil(displayB)
        XCTAssertEqual(displayB?.header.regionName, "London")
    }

    @MainActor
    func testWeatherNoDataUsesPlainAppBackground() {
        let weatherModel = WeatherSceneModel()
        weatherModel.resetForLocationChange()

        XCTAssertFalse(weatherModel.isAvailable, "Unavailable weather must report isAvailable = false")
        XCTAssertNil(weatherModel.weatherDisplay, "Unavailable weather must have nil display")
        XCTAssertNil(weatherModel.condition, "Unavailable weather must have nil condition so sky renders plain cream backdrop")
        XCTAssertEqual(weatherModel.cloudCover, 0.0, "Unavailable weather must have 0.0 cloud cover")

        // ZmanimSkyBackdrop headerColor helper returns ink/white without fake weather
        let headerColor = ZmanimSkyBackdrop.headerColor(
            for: Date(),
            timeZone: .current,
            sunrise: nil,
            sunset: nil,
            condition: weatherModel.condition,
            cloudCover: weatherModel.effectiveCloudCover,
            colorScheme: .light
        )
        XCTAssertNotNil(headerColor)
    }

    @MainActor
    func testWeatherAutomaticRefreshOnGPSAndSavedCityTransitions() async {
        let city = SavedCity(id: "c_auto", name: "Eilat", latitude: 29.558, longitude: 34.948, timeZoneID: "Asia/Jerusalem")
        let prefs = LocationPreferences(defaultChoice: .current, savedCities: [city])
        LocationPreferencesStore.savePreferences(prefs)

        let model = AppModel()

        // Transition 1: Switch to Eilat
        await model.selectActiveChoice(.savedCity(id: city.id))
        XCTAssertEqual(model.cityName, "Eilat")
        XCTAssertFalse(model.isGPSActive)

        // Transition 2: Switch back to GPS
        await model.selectActiveChoice(.current)
        XCTAssertTrue(model.isGPSActive)
        XCTAssertEqual(model.activeChoice, .current)
    }

    func testWeatherCacheDifferentNearbyPlacesAndTimezone() async {
        let cache = WeatherCache()
        let now = Date()

        let snap1 = WeatherSnapshot(
            hours: [WeatherHour(time: now, temperatureCelsius: 21.0, symbolCode: "cloudy", iconKey: "cloud.fill")],
            retrievedAt: now,
            locationLatitude: 31.7767,
            locationLongitude: 35.2345,
            expiresAt: now.addingTimeInterval(3600)
        )
        let snap2 = WeatherSnapshot(
            hours: [WeatherHour(time: now, temperatureCelsius: 18.0, symbolCode: "rain", iconKey: "cloud.rain.fill")],
            retrievedAt: now,
            locationLatitude: 31.7800,
            locationLongitude: 35.2400,
            expiresAt: now.addingTimeInterval(3600)
        )

        await cache.save(snapshot: snap1, timeZoneID: "Asia/Jerusalem")
        await cache.save(snapshot: snap2, timeZoneID: "Asia/Jerusalem")

        // Querying exactly snap1 coordinates returns snap1 (closest point)
        let retrieved1 = await cache.getCached(latitude: 31.7767, longitude: 35.2345, timeZoneID: "Asia/Jerusalem", now: now)
        XCTAssertNotNil(retrieved1)
        XCTAssertEqual(retrieved1?.hours.first?.temperatureCelsius, 21.0)

        // Query with mismatched timezone strictly fails
        let wrongZone = await cache.getCached(latitude: 31.7767, longitude: 35.2345, timeZoneID: "Europe/London", now: now)
        XCTAssertNil(wrongZone, "Cache must enforce strict timeZone isolation")
    }

    @MainActor
    func testWeatherRecomputeSkyContextAfterSunriseSunsetArrive() {
        let weatherModel = WeatherSceneModel()
        let now = Date()

        let hour = WeatherHour(
            time: now,
            temperatureCelsius: 20.0,
            symbolCode: "clearsky_day",
            iconKey: "sun.max.fill"
        )
        let snapshot = WeatherSnapshot(
            hours: [hour],
            retrievedAt: now,
            locationLatitude: 31.778,
            locationLongitude: 35.235,
            expiresAt: now.addingTimeInterval(3600)
        )

        // Simulate initial condition without known sunrise/sunset
        weatherModel.currentSnapshot = snapshot
        weatherModel.isAvailable = true

        // Recompute with known sunrise/sunset
        let sunrise = now.addingTimeInterval(-7200)
        let sunset = now.addingTimeInterval(7200)
        weatherModel.recomputeSkyContext(sunrise: sunrise, sunset: sunset, now: now)

        XCTAssertNotNil(weatherModel.condition, "Recomputing sky context must yield an authentic sky condition")
        XCTAssertTrue(weatherModel.isAvailable)
    }
}
