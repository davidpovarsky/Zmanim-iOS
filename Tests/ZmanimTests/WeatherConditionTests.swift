import XCTest
@testable import Zmanim

final class WeatherConditionTests: XCTestCase {
    func testSevereAndPrecipitationConditionsTakePrecedence() {
        let now = Date()
        let sunrise = now
        let sunset = now.addingTimeInterval(43200)

        // Thunderstorm code 95
        let storm = WeatherCondition.resolve(
            wmoCode: 95,
            isDay: true,
            cloudCoverPercent: 90,
            now: now,
            sunrise: sunrise,
            sunset: sunset
        )
        XCTAssertEqual(storm, .thunderstorm)

        // Rain code 61
        let rain = WeatherCondition.resolve(
            wmoCode: 61,
            isDay: true,
            cloudCoverPercent: 85,
            now: now,
            sunrise: sunrise,
            sunset: sunset
        )
        XCTAssertEqual(rain, .rain)

        // Snow code 71
        let snow = WeatherCondition.resolve(
            wmoCode: 71,
            isDay: false,
            cloudCoverPercent: 80,
            now: now,
            sunrise: sunrise,
            sunset: sunset
        )
        XCTAssertEqual(snow, .snow)

        // Fog code 45
        let fog = WeatherCondition.resolve(
            wmoCode: 45,
            isDay: true,
            cloudCoverPercent: 50,
            now: now,
            sunrise: sunrise,
            sunset: sunset
        )
        XCTAssertEqual(fog, .fog)
    }

    func testTwilightTransitionsNearSunriseAndSunset() {
        let baseDate = Date()
        let sunrise = baseDate.addingTimeInterval(3600 * 6)
        let sunset = baseDate.addingTimeInterval(3600 * 18)

        // 10 minutes before sunrise
        let nearSunrise = sunrise.addingTimeInterval(-600)
        let sunriseCond = WeatherCondition.resolve(
            wmoCode: 0,
            isDay: false,
            cloudCoverPercent: 10,
            now: nearSunrise,
            sunrise: sunrise,
            sunset: sunset
        )
        XCTAssertEqual(sunriseCond, .sunrise)

        // 15 minutes after sunset
        let nearSunset = sunset.addingTimeInterval(900)
        let sunsetCond = WeatherCondition.resolve(
            wmoCode: 1,
            isDay: false,
            cloudCoverPercent: 15,
            now: nearSunset,
            sunrise: sunrise,
            sunset: sunset
        )
        XCTAssertEqual(sunsetCond, .sunset)
    }

    func testDayAndNightClearVsCloudy() {
        let baseDate = Date()
        let sunrise = baseDate.addingTimeInterval(-3600 * 5)
        let sunset = baseDate.addingTimeInterval(3600 * 5)
        let midday = baseDate // between sunrise and sunset, not in twilight

        // Clear day
        let clear = WeatherCondition.resolve(
            wmoCode: 0,
            isDay: true,
            cloudCoverPercent: 10,
            now: midday,
            sunrise: sunrise,
            sunset: sunset
        )
        XCTAssertEqual(clear, .clearDay)

        // Overcast day
        let overcast = WeatherCondition.resolve(
            wmoCode: 3,
            isDay: true,
            cloudCoverPercent: 90,
            now: midday,
            sunrise: sunrise,
            sunset: sunset
        )
        XCTAssertEqual(overcast, .overcastDay)

        // Clear night
        let midnight = baseDate.addingTimeInterval(3600 * 10)
        let clearNight = WeatherCondition.resolve(
            wmoCode: 0,
            isDay: false,
            cloudCoverPercent: 10,
            now: midnight,
            sunrise: sunrise,
            sunset: sunset
        )
        XCTAssertEqual(clearNight, .clearNight)

        // Cloudy night
        let cloudyNight = WeatherCondition.resolve(
            wmoCode: 2,
            isDay: false,
            cloudCoverPercent: 65,
            now: midnight,
            sunrise: sunrise,
            sunset: sunset
        )
        XCTAssertEqual(cloudyNight, .cloudyNight)
    }
}
