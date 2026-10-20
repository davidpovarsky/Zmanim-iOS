import XCTest
@testable import Zmanim

final class DefaultNotificationSchedulingTests: XCTestCase {

    @MainActor
    func testTemporaryActiveChoiceDoesNotChangeDefaultChoice() async {
        let city1 = SavedCity(id: "c1", name: "Jerusalem", latitude: 31.778, longitude: 35.235, timeZoneID: "Asia/Jerusalem", order: 0)
        let city2 = SavedCity(id: "c2", name: "London", latitude: 51.507, longitude: -0.127, timeZoneID: "Europe/London", order: 1)

        let initialPrefs = LocationPreferences(
            defaultChoice: .savedCity(id: "c1"),
            savedCities: [city1, city2]
        )
        LocationPreferencesStore.savePreferences(initialPrefs)

        let model = AppModel()
        XCTAssertEqual(model.locationPreferences.defaultChoice, .savedCity(id: "c1"))
        XCTAssertEqual(model.activeChoice, .savedCity(id: "c1"))

        // User temporarily views London
        await model.selectActiveChoice(.savedCity(id: "c2"))

        // Active choice is London, but default choice MUST remain Jerusalem!
        XCTAssertEqual(model.activeChoice, .savedCity(id: "c2"))
        XCTAssertEqual(model.locationPreferences.defaultChoice, .savedCity(id: "c1"))

        // Also persistent store must still have Jerusalem as default
        let reloaded = LocationPreferencesStore.loadPreferences()
        XCTAssertEqual(reloaded.defaultChoice, .savedCity(id: "c1"))
    }

    @MainActor
    func testSettingDefaultChoicePersistsImmediately() async {
        let city = SavedCity(id: "c1", name: "Jerusalem", latitude: 31.778, longitude: 35.235, timeZoneID: "Asia/Jerusalem", order: 0)
        LocationPreferencesStore.savePreferences(LocationPreferences(defaultChoice: .current, savedCities: [city]))

        let model = AppModel()
        XCTAssertEqual(model.locationPreferences.defaultChoice, .current)

        await model.setDefaultLocationChoice(.savedCity(id: "c1"))
        XCTAssertEqual(model.locationPreferences.defaultChoice, .savedCity(id: "c1"))

        let reloaded = LocationPreferencesStore.loadPreferences()
        XCTAssertEqual(reloaded.defaultChoice, .savedCity(id: "c1"))
    }
}
