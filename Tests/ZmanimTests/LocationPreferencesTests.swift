import XCTest
@testable import Zmanim

final class LocationPreferencesTests: XCTestCase {

    func testSavedCityValidation() {
        let validCity = SavedCity(name: "Jerusalem", latitude: 31.778, longitude: 35.235, timeZoneID: "Asia/Jerusalem")
        XCTAssertTrue(validCity.isValid)
        XCTAssertEqual(validCity.timeZone.identifier, "Asia/Jerusalem")

        let invalidLat = SavedCity(name: "Invalid", latitude: 120.0, longitude: 35.0, timeZoneID: "UTC")
        XCTAssertFalse(invalidLat.isValid)

        let emptyName = SavedCity(name: "   ", latitude: 32.0, longitude: 34.0, timeZoneID: "UTC")
        XCTAssertFalse(emptyName.isValid)
    }

    func testLocationChoiceCodableRoundTrip() throws {
        let currentChoice = LocationChoice.current
        let currentData = try JSONEncoder().encode(currentChoice)
        let decodedCurrent = try JSONDecoder().decode(LocationChoice.self, from: currentData)
        XCTAssertEqual(decodedCurrent, .current)
        XCTAssertTrue(decodedCurrent.isCurrent)
        XCTAssertNil(decodedCurrent.savedCityID)
        XCTAssertEqual(decodedCurrent.storageKey, "current")

        let cityChoice = LocationChoice.savedCity(id: "test-uuid-123")
        let cityData = try JSONEncoder().encode(cityChoice)
        let decodedCity = try JSONDecoder().decode(LocationChoice.self, from: cityData)
        XCTAssertEqual(decodedCity, .savedCity(id: "test-uuid-123"))
        XCTAssertFalse(decodedCity.isCurrent)
        XCTAssertEqual(decodedCity.savedCityID, "test-uuid-123")
        XCTAssertEqual(decodedCity.storageKey, "city_test-uuid-123")
    }

    func testLocationPreferencesCodableRoundTrip() throws {
        let city1 = SavedCity(id: "c1", name: "Jerusalem", latitude: 31.778, longitude: 35.235, timeZoneID: "Asia/Jerusalem", order: 0)
        let city2 = SavedCity(id: "c2", name: "London", latitude: 51.507, longitude: -0.127, timeZoneID: "Europe/London", order: 1)

        let prefs = LocationPreferences(
            defaultChoice: .savedCity(id: "c1"),
            savedCities: [city1, city2],
            schemaVersion: 1
        )

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(LocationPreferences.self, from: data)

        XCTAssertEqual(decoded.defaultChoice, .savedCity(id: "c1"))
        XCTAssertEqual(decoded.savedCities.count, 2)
        XCTAssertEqual(decoded.city(for: "c1")?.name, "Jerusalem")
        XCTAssertEqual(decoded.city(for: "c2")?.name, "London")
        XCTAssertEqual(decoded.city(for: .savedCity(id: "c2"))?.name, "London")
    }

    func testAddCityDeduplication() {
        let original = LocationPreferences(
            defaultChoice: .current,
            savedCities: [
                SavedCity(id: "1", name: "Jerusalem", latitude: 31.778, longitude: 35.235, timeZoneID: "Asia/Jerusalem", order: 0)
            ]
        )
        LocationPreferencesStore.savePreferences(original)

        // Adding exact or very close city returns existing city without increasing count
        let (_, existingCity) = LocationPreferencesStore.addCity(
            name: "Jerusalem",
            latitude: 31.779,
            longitude: 35.236,
            timeZoneID: "Asia/Jerusalem"
        )
        XCTAssertEqual(existingCity.id, "1")

        let loaded = LocationPreferencesStore.loadPreferences()
        XCTAssertEqual(loaded.savedCities.count, 1)

        // Adding different city increases count
        let (_, newCity) = LocationPreferencesStore.addCity(
            name: "Tel Aviv",
            latitude: 32.0853,
            longitude: 34.7818,
            timeZoneID: "Asia/Jerusalem"
        )
        XCTAssertNotEqual(newCity.id, "1")

        let loaded2 = LocationPreferencesStore.loadPreferences()
        XCTAssertEqual(loaded2.savedCities.count, 2)
    }

    func testRemoveCityRevertsDefaultIfDeletedWasDefault() {
        let city1 = SavedCity(id: "c1", name: "Jerusalem", latitude: 31.778, longitude: 35.235, timeZoneID: "Asia/Jerusalem", order: 0)
        let city2 = SavedCity(id: "c2", name: "London", latitude: 51.507, longitude: -0.127, timeZoneID: "Europe/London", order: 1)

        var prefs = LocationPreferences(
            defaultChoice: .savedCity(id: "c1"),
            savedCities: [city1, city2]
        )
        LocationPreferencesStore.savePreferences(prefs)

        // Remove city that was the default
        prefs = LocationPreferencesStore.removeCity(id: "c1")
        XCTAssertEqual(prefs.savedCities.count, 1)
        XCTAssertEqual(prefs.savedCities.first?.id, "c2")
        // Default must safely fall back to .current
        XCTAssertEqual(prefs.defaultChoice, .current)
    }

    func testPerLocationSnapshotStorageIsolation() {
        let snapGPS = ZmanSnapshot(
            cityName: "GPS Location",
            timeZoneID: "Asia/Jerusalem",
            latitude: 31.778,
            longitude: 35.235,
            updatedAt: Date(),
            items: []
        )
        LocationSnapshotStore.saveSnapshot(snapGPS, for: "current")

        let snapLondon = ZmanSnapshot(
            cityName: "London",
            timeZoneID: "Europe/London",
            latitude: 51.507,
            longitude: -0.127,
            updatedAt: Date(),
            items: []
        )
        LocationSnapshotStore.saveSnapshot(snapLondon, for: "city_london-123")

        let loadedGPS = LocationSnapshotStore.loadSnapshot(for: "current")
        XCTAssertEqual(loadedGPS?.cityName, "GPS Location")
        XCTAssertEqual(loadedGPS?.timeZoneID, "Asia/Jerusalem")

        let loadedLondon = LocationSnapshotStore.loadSnapshot(for: "city_london-123")
        XCTAssertEqual(loadedLondon?.cityName, "London")
        XCTAssertEqual(loadedLondon?.timeZoneID, "Europe/London")
    }
}
