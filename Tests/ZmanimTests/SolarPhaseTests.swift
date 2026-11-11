import XCTest
@testable import Zmanim

final class SolarPhaseTests: XCTestCase {
    private let sunrise = Date(timeIntervalSince1970: 1700000000)
    private let sunset = Date(timeIntervalSince1970: 1700043200) // 12 hours later

    func testPhaseBeforeSunrise() {
        let before = sunrise.addingTimeInterval(-1800)
        let phase = SolarPhase.resolve(now: before, sunrise: sunrise, sunset: sunset)
        XCTAssertEqual(phase, .beforeSunrise)
        XCTAssertFalse(phase.isDaylight)
        XCTAssertEqual(phase.progress, 0.0)
    }

    func testPhaseDuringDaylight() {
        let midday = sunrise.addingTimeInterval(21600) // 6 hours in
        let phase = SolarPhase.resolve(now: midday, sunrise: sunrise, sunset: sunset)
        if case let .daylight(p) = phase {
            XCTAssertEqual(p, 0.5, accuracy: 0.0001)
        } else {
            XCTFail("Expected .daylight at midday")
        }
        XCTAssertTrue(phase.isDaylight)
        XCTAssertEqual(phase.progress, 0.5, accuracy: 0.0001)
    }

    func testPhaseAfterSunset() {
        let after = sunset.addingTimeInterval(1800)
        let phase = SolarPhase.resolve(now: after, sunrise: sunrise, sunset: sunset)
        XCTAssertEqual(phase, .afterSunset)
        XCTAssertFalse(phase.isDaylight)
        XCTAssertEqual(phase.progress, 0.0)
    }

    func testPhaseUnavailable() {
        XCTAssertEqual(SolarPhase.resolve(now: sunrise, sunrise: nil, sunset: sunset), .unavailable)
        XCTAssertEqual(SolarPhase.resolve(now: sunrise, sunrise: sunrise, sunset: nil), .unavailable)
        XCTAssertEqual(SolarPhase.resolve(now: sunrise, sunrise: sunset, sunset: sunrise), .unavailable)
    }

    func testExactSunriseAndSunsetBoundaries() {
        let atRise = SolarPhase.resolve(now: sunrise, sunrise: sunrise, sunset: sunset)
        XCTAssertEqual(atRise, .daylight(progress: 0.0))

        let atSet = SolarPhase.resolve(now: sunset, sunrise: sunrise, sunset: sunset)
        XCTAssertEqual(atSet, .daylight(progress: 1.0))
    }
}
