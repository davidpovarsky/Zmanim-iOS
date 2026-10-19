import XCTest
import OneBusAwayWeatherCore
import OneBusAwayWeatherUI
@testable import Zmanim

final class ZmanimOneBusAwayWeatherIntegrationTests: XCTestCase {
    func testAdapterConstructsAuthoritativeWeatherDisplay() {
        let now = Date()
        let tz = TimeZone(identifier: "Asia/Jerusalem")!
        let locale = Locale(identifier: "he_IL")

        let hours: [WeatherHour] = (0..<30).map { i in
            let date = now.addingTimeInterval(Double(i * 3600))
            return WeatherHour(
                time: date,
                temperatureCelsius: 15.0 + Double(i % 10), // 15 to 24
                windMetersPerSecond: 4.0,
                precipitationChancePercent: 10.0,
                cloudAreaFractionPercent: 50.0,
                symbolCode: "partlycloudy_day",
                iconKey: "partly-cloudy-day"
            )
        }

        let snapshot = WeatherSnapshot(
            hours: hours,
            retrievedAt: now,
            locationLatitude: 31.778,
            locationLongitude: 35.235,
            expiresAt: now.addingTimeInterval(1800)
        )

        let display = ZmanimWeatherDisplayAdapter.makeWeatherDisplay(
            from: snapshot,
            cityName: "ירושלים",
            timeZone: tz,
            locale: locale,
            now: now
        )

        XCTAssertNotNil(display)
        guard let display else { return }

        // Hourly strip should contain upcoming hours with index 0 labeled "עכשיו"
        XCTAssertGreaterThanOrEqual(display.hourly.count, 24)
        XCTAssertEqual(display.hourly.first?.timeLabel, "עכשיו")
        XCTAssertTrue(display.hourly.first?.isNow == true)
        XCTAssertFalse(display.hourly[1].isNow)

        // Three-slot layout: feelsLikeText must be literal em dash "—"
        XCTAssertEqual(display.stats.feelsLikeText, "—")
        XCTAssertEqual(display.stats.precipText, "10%")

        // Source attribution from MET Norway
        XCTAssertEqual(display.sourceAttribution, MOTLocationWeatherSnapshot.attribution)
    }

    func testAdapterResolvesSkyConditionForSwiftUISky() {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let sunrise = now.addingTimeInterval(-10 * 60) // 10 minutes past sunrise
        let sunset = now.addingTimeInterval(8 * 3600)

        // Within twilight window: should be .sunrise
        let condition = ZmanimWeatherDisplayAdapter.resolveSkyCondition(
            iconKey: "clear-day",
            isNight: false,
            sunrise: sunrise,
            sunset: sunset,
            now: now
        )
        XCTAssertEqual(condition, .sunrise)

        // Severe weather takes precedence over twilight
        let rainCondition = ZmanimWeatherDisplayAdapter.resolveSkyCondition(
            iconKey: "rain",
            isNight: false,
            sunrise: sunrise,
            sunset: sunset,
            now: now
        )
        XCTAssertEqual(rainCondition, .rain)
    }

    func testMETSymbolConversionPrioritizesSnowOverShowers() {
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "snowshowers_day"), "snow")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "snowshowers_night"), "snow")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "sleetshowers_day"), "sleet")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "rainshowers_day"), "rain")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "clearsky_day"), "clear-day")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "clearsky_night"), "clear-night")
    }

    func testPaletteCoverageForFormatterKeys() {
        for key in WeatherFormatter.knownIconKeys {
            XCTAssertNotNil(WeatherIconPalette.colors[key], "Palette missing key: \(key)")
        }
    }
}
