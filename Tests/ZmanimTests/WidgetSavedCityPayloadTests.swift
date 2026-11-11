import Foundation
import XCTest
@testable import Zmanim

final class WidgetSavedCityPayloadTests: XCTestCase {
    private let jerusalem = SavedCity(
        id: "test-jerusalem-42",
        name: "Jerusalem",
        latitude: 31.778,
        longitude: 35.235,
        timeZoneID: "Asia/Jerusalem"
    )

    func testPortableCityRoundTripsWithoutSharedPreferences() {
        let id = WidgetSavedCityPayload.identifier(for: jerusalem)
        XCTAssertTrue(id.hasPrefix(WidgetSavedCityPayload.prefix))
        XCTAssertEqual(WidgetSavedCityPayload.city(from: id), jerusalem)
        XCTAssertEqual(id, WidgetSavedCityPayload.identifier(for: jerusalem))

        // Parsing is pure and does not require App Group access.
        XCTAssertEqual(WidgetSavedCityPayload.city(from: id), jerusalem)
        XCTAssertEqual(
            WidgetTargetResolver.resolve(identifier: id, preferencesResult: .storeUnavailable),
            .savedCity(jerusalem)
        )
        XCTAssertEqual(
            WidgetTargetResolver.resolve(identifier: id, preferencesResult: .corruptData("bad")),
            .savedCity(jerusalem)
        )
    }

    func testEntityQueryResolvesPortableChoiceWithoutCityList() async throws {
        let id = WidgetSavedCityPayload.identifier(for: jerusalem)
        let query = WidgetLocationQuery()
        let result = try await query.entities(for: [id])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, id)
        XCTAssertEqual(result[0].name, jerusalem.name)
    }

    func testInvalidPayloadNeverBecomesArbitraryLocation() {
        XCTAssertNil(WidgetSavedCityPayload.city(from: "city-v2:???"))
        XCTAssertNil(WidgetSavedCityPayload.city(from: "city-v2:"))
        XCTAssertNil(WidgetSavedCityPayload.city(from: "city-v2:" + String(repeating: "A", count: 5000)))
        XCTAssertNil(WidgetSavedCityPayload.city(from: "city:test-jerusalem-42"))
        let noTimezone = SavedCity(id: "bad", name: "Test", latitude: 31.778, longitude: 35.235, timeZoneID: "Invalid/Timezone")
        let noCoordinates = SavedCity(id: "bad-coord", name: "Test", latitude: 200.0, longitude: 35.235, timeZoneID: "Asia/Jerusalem")
        XCTAssertNil(WidgetSavedCityPayload.city(from: WidgetSavedCityPayload.identifier(for: noTimezone)))
        XCTAssertNil(WidgetSavedCityPayload.city(from: WidgetSavedCityPayload.identifier(for: noCoordinates)))
    }

    func testLegacyChoicesRemainRecognizable() {
        XCTAssertEqual(WidgetSavedCityPayload.legacyCityID(from: "city:old-uuid"), "old-uuid")
        XCTAssertEqual(WidgetSavedCityPayload.legacyCityID(from: "city_old-uuid"), "old-uuid")
        XCTAssertNil(WidgetSavedCityPayload.legacyCityID(from: "app-default"))
        XCTAssertNil(WidgetSavedCityPayload.legacyCityID(from: WidgetSavedCityPayload.identifier(for: jerusalem)))
    }
}

final class WidgetTargetResolverTests: XCTestCase {
    private let city = SavedCity(
        id: "saved-city-1",
        name: "Haifa",
        latitude: 32.794,
        longitude: 34.989,
        timeZoneID: "Asia/Jerusalem"
    )

    func testPortableConfiguredCitySurvivesUnavailableAppGroup() {
        let id = WidgetSavedCityPayload.identifier(for: city)
        XCTAssertEqual(
            WidgetTargetResolver.resolve(identifier: id, preferencesResult: .storeUnavailable),
            .savedCity(city)
        )
        XCTAssertEqual(
            WidgetTargetResolver.resolve(identifier: id, preferencesResult: .noPreferencesYet),
            .savedCity(city)
        )
    }

    func testStoredUpdateWinsAndExplicitDeletionIsHonored() {
        let selected = WidgetSavedCityPayload.identifier(for: city)
        var updated = city
        updated.name = "Haifa updated"
        var prefs = LocationPreferences(defaultChoice: .current, savedCities: [updated])
        XCTAssertEqual(
            WidgetTargetResolver.resolve(identifier: selected, preferencesResult: .loaded(prefs)),
            .savedCity(updated)
        )
        prefs.savedCities = []
        prefs.removedCityIDs = [city.id]
        XCTAssertEqual(
            WidgetTargetResolver.resolve(identifier: selected, preferencesResult: .loaded(prefs)),
            .cityRemoved(cityID: city.id)
        )
    }

    func testLegacyCityStillWorksWhenSharedDataExists() {
        let prefs = LocationPreferences(defaultChoice: .current, savedCities: [city])
        XCTAssertEqual(
            WidgetTargetResolver.resolve(identifier: "city:\(city.id)", preferencesResult: .loaded(prefs)),
            .savedCity(city)
        )
        XCTAssertEqual(
            WidgetTargetResolver.resolve(identifier: "city:\(city.id)", preferencesResult: .storeUnavailable),
            .sharedStoreUnavailable
        )
    }

    func testMalformedPayloadNeverSelectsGPSOrWrongCity() {
        XCTAssertEqual(
            WidgetTargetResolver.resolve(identifier: "city-v2:bad", preferencesResult: .storeUnavailable),
            .invalidConfiguration
        )
        XCTAssertEqual(
            WidgetTargetResolver.resolve(identifier: "city_unknown", preferencesResult: .noPreferencesYet),
            .savedCityMissing(cityID: "unknown")
        )
    }
}
