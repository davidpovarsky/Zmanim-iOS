import XCTest
@testable import Zmanim

final class LocationSwitchTests: XCTestCase {
    func testLegacyUserSettingsDecodingMigration() throws {
        // Legacy JSON without specialDaysMasterEnabled
        let legacyJSON = """
        {
            "locationMode": "fixed",
            "fixedCity": "ירושלים",
            "shabbatMasterEnabled": true,
            "holidayMasterEnabled": false,
            "rules": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(UserSettings.self, from: legacyJSON)
        XCTAssertEqual(decoded.locationMode, .fixed)
        XCTAssertEqual(decoded.fixedCity, "ירושלים")
        XCTAssertTrue(decoded.specialDaysMasterEnabled)
        XCTAssertTrue(decoded.shabbatEnabled)
        XCTAssertFalse(decoded.holidayEnabled)
    }

    func testModernUserSettingsRoundTrip() throws {
        let location = ResolvedLocation(
            displayName: "New York",
            latitude: 40.7128,
            longitude: -74.0060,
            timeZoneID: "America/New_York",
            source: .fixedSearch
        )

        let settings = UserSettings(
            locationMode: .fixed,
            fixedCity: "New York",
            resolvedFixedLocation: location,
            specialDaysMasterEnabled: true,
            shabbatEnabled: true,
            holidayEnabled: true,
            rules: []
        )

        let data = try JSONEncoder().encode(settings)
        let roundTripped = try JSONDecoder().decode(UserSettings.self, from: data)

        XCTAssertEqual(roundTripped.locationMode, .fixed)
        XCTAssertEqual(roundTripped.fixedCity, "New York")
        XCTAssertEqual(roundTripped.resolvedFixedLocation?.timeZoneID, "America/New_York")
        XCTAssertTrue(roundTripped.specialDaysMasterEnabled)
        XCTAssertTrue(roundTripped.shabbatEnabled)
        XCTAssertTrue(roundTripped.holidayEnabled)
    }

    func testDisentangledMasterToggles() {
        var settings = UserSettings()
        XCTAssertFalse(settings.specialDaysMasterEnabled)
        XCTAssertFalse(settings.shabbatEnabled)
        XCTAssertFalse(settings.holidayEnabled)

        // Turn on master and only Shabbat
        settings.specialDaysMasterEnabled = true
        settings.shabbatEnabled = true
        settings.holidayEnabled = false

        XCTAssertTrue(settings.shabbatMasterEnabled)
        XCTAssertFalse(settings.holidayMasterEnabled)

        // Turn off master
        settings.specialDaysMasterEnabled = false
        XCTAssertFalse(settings.specialDaysMasterEnabled)
    }
}
