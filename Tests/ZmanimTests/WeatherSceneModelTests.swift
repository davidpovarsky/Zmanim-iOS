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
            symbolCode: "overcast",
            precipitationAmountMm: 0,
            windSpeedMps: 2.0,
            relativeHumidityPercent: 60.0,
            cloudAreaFractionPercent: nil
        )

        let snapshot = WeatherSnapshot(
            coordinate: CLLocationCoordinate2D(latitude: 31.76, longitude: 35.21),
            retrievedAt: now,
            expiresAt: now.addingTimeInterval(3600),
            hours: [hour]
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
