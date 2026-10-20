import XCTest
@testable import Zmanim

final class WidgetConfigurationEntityTests: XCTestCase {

    func testSuggestedEntitiesContainsDefaultGPSAndSavedCities() async throws {
        let city = SavedCity(id: "c-test-1", name: "Jerusalem", latitude: 31.778, longitude: 35.235, timeZoneID: "Asia/Jerusalem")
        let prefs = LocationPreferences(defaultChoice: .current, savedCities: [city])
        LocationPreferencesStore.savePreferences(prefs)

        let query = WidgetLocationQuery()
        let suggested = try await query.suggestedEntities()

        XCTAssertTrue(suggested.count >= 3)
        XCTAssertEqual(suggested[0].id, "app-default")
        XCTAssertEqual(suggested[1].id, "current-gps")
        XCTAssertEqual(suggested[2].id, "city:c-test-1")
        XCTAssertEqual(suggested[2].name, "Jerusalem")
    }

    func testResolvesDefaultAndGPSIdentities() async throws {
        let query = WidgetLocationQuery()
        let resolved = try await query.entities(for: ["app-default", "current-gps"])

        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(resolved[0].id, "app-default")
        XCTAssertEqual(resolved[1].id, "current-gps")
    }

    func testDeletedCityResolvesToTombstone() async throws {
        // Save preferences where city was explicitly removed
        LocationPreferencesStore.savePreferences(LocationPreferences(defaultChoice: .current, savedCities: [], schemaVersion: 1, removedCityIDs: ["nonexistent-city-id"]))

        let query = WidgetLocationQuery()
        let resolved = try await query.entities(for: ["city:nonexistent-city-id"])

        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved[0].id, "city:nonexistent-city-id")
        XCTAssertTrue(resolved[0].name.contains("הוסרה") || resolved[0].name.contains("removed"))
    }

    func testDefaultResultReturnsAppDefault() async {
        let query = WidgetLocationQuery()
        let def = await query.defaultResult()
        XCTAssertEqual(def?.id, "app-default")
    }
}
