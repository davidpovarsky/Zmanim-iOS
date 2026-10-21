import CoreLocation
import XCTest
@testable import Zmanim

final class WeatherSceneModelTests: XCTestCase {
    @MainActor
    func testMissingCloudAreaFractionDoesNotFabricateEstimatedNumbers() async {
        let model = WeatherSceneModel()
        let now = Date()

        // Hourly forecast with NO cloud fraction provided
        let hour = WeatherHour(
            time: now,
            temperatureCelsius: 18.0,
            windMetersPerSecond: 2.0,
            precipitationChancePercent: 0,
            cloudAreaFractionPercent: nil,
            symbolCode: "overcast",
            iconKey: "cloud.fill"
        )

        let snapshot = WeatherSnapshot(
            hours: [hour],
            retrievedAt: now,
            locationLatitude: 31.76,
            locationLongitude: 35.21,
            expiresAt: now.addingTimeInterval(3600)
        )

        // Reset and check initial
        model.resetForLocationChange()
        XCTAssertFalse(model.isAvailable)
        XCTAssertNil(model.weatherDisplay)
        XCTAssertEqual(model.cloudCover, 0.0)
    }

    @MainActor
    func testResetForLocationChangeClearsDisplayAndAvailability() {
        let model = WeatherSceneModel()
        model.resetForLocationChange()

        XCTAssertFalse(model.isAvailable)
        XCTAssertNil(model.weatherDisplay)
        XCTAssertNil(model.condition)
        XCTAssertEqual(model.cloudCover, 0.0)
    }
}
