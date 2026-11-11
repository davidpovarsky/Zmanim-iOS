import XCTest
@testable import Zmanim

final class WidgetTargetResolutionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WidgetPageStateStore.resetState(for: "city_london")
        WidgetPageStateStore.resetState(for: "city_paris")
        LocationSnapshotStore.removeSnapshot(for: "city_london")
        LocationSnapshotStore.removeSnapshot(for: "city_paris")
    }

    // S12: Multiple widgets configured with different locations remain isolated across refreshes and paging
    func testS12_MultipleWidgetsWithDifferentLocationsRemainIsolated() {
        let londonCity = SavedCity(id: "london", name: "London", latitude: 51.5074, longitude: -0.1278, timeZoneID: "Europe/London")
        let parisCity = SavedCity(id: "paris", name: "Paris", latitude: 48.8566, longitude: 2.3522, timeZoneID: "Europe/Paris")

        LocationPreferencesStore.savePreferences(LocationPreferences(
            defaultChoice: .savedCity(id: "london"),
            savedCities: [londonCity, parisCity]
        ))

        // Save page state for London (page 1)
        let now = Date()
        let londonState = WidgetPageState(pageIndex: 1, lastInteractionAt: now, expiresAt: now.addingTimeInterval(60), dayKey: "2026-10-20", locationFingerprint: "city_london")
        WidgetPageStateStore.saveState(londonState, for: "city_london")

        // Paris should have no page state (starts at 0) and not load London's page state
        let loadedParis = WidgetPageStateStore.loadState(for: "city_paris")
        XCTAssertNil(loadedParis, "Paris must not inherit London's page state via cross-location fallback")

        let effParis = WidgetPageStateStore.effectivePageIndex(
            state: loadedParis,
            currentDate: now,
            currentDayKey: "2026-10-20",
            currentLocationFingerprint: "city_paris",
            pageCount: 3
        )
        XCTAssertEqual(effParis, 0, "Paris widget must stay at page 0")

        let loadedLondon = WidgetPageStateStore.loadState(for: "city_london")
        XCTAssertEqual(loadedLondon?.pageIndex, 1, "London widget page state must be preserved")
    }

    // W11: Missing or unreadable city in WidgetLocationEntity returns open app prompt, never false "City was removed"
    func testW11_MissingUnverifiedCityDoesNotShowCityRemoved() async throws {
        // City is NOT in removedCityIDs
        LocationPreferencesStore.savePreferences(LocationPreferences(defaultChoice: .current, savedCities: [], schemaVersion: 1, removedCityIDs: []))

        let query = WidgetLocationQuery()
        let entities = try await query.entities(for: ["city:unknown-syncing-city"])

        XCTAssertEqual(entities.count, 1)
        let name = entities[0].name
        XCTAssertFalse(name.contains("הוסרה") || name.contains("was removed"), "Must never falsely declare a city removed unless confirmed in removedCityIDs")
    }
}
