import XCTest
@testable import OneBusAwayWeatherCore
@testable import OneBusAwayWeatherUI

final class OneBusAwayWeatherTests: XCTestCase {
    func testIconPaletteContainsAllKnownIconKeys() {
        let known = WeatherFormatter.knownIconKeys
        XCTAssertFalse(known.isEmpty)
        for key in known {
            XCTAssertNotNil(WeatherIconPalette.colors[key], "Missing palette color for icon key: \(key)")
        }
    }

    func testMETSymbolConversionPrioritizesSnowOverShowers() {
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "snowshowers_day"), "snow")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "snowshowers_night"), "snow")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "sleetshowers_day"), "sleet")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "rainshowers_day"), "rain")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "clearsky_day"), "clear-day")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "clearsky_night"), "clear-night")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "partlycloudy_day"), "partly-cloudy-day")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "cloudy"), "cloudy")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "fog"), "fog")
        XCTAssertEqual(METLocationWeatherConverter.iconKey(from: "heavyrain"), "rain")
    }

    func testWeatherDisplayFromLocationSnapshot() {
        let now = Date()
        let tz = TimeZone(identifier: "Asia/Jerusalem")!
        let locale = Locale(identifier: "he_IL")

        let hours = (0..<30).map { i in
            MOTLocationWeatherHour(
                time: now.addingTimeInterval(Double(i * 3600)),
                temperatureCelsius: 16.0 + Double(i % 8),
                windMetersPerSecond: 3.5,
                precipitationChancePercent: 20.0,
                iconKey: "partly-cloudy-day"
            )
        }

        let snapshot = MOTLocationWeatherSnapshot(
            hours: hours,
            retrievedAt: now,
            locationLatitude: 31.778,
            locationLongitude: 35.235
        )

        let display = WeatherDisplay(
            locationForecast: snapshot,
            locationName: "ירושלים",
            locale: locale,
            timeZone: tz,
            now: now
        )

        XCTAssertNotNil(display)
        guard let display else { return }

        XCTAssertEqual(display.header.regionName, "ירושלים")
        XCTAssertEqual(display.hourly.count, 25) // Up to 25 upcoming hours as defined in original WeatherDisplay
        XCTAssertTrue(display.hourly.first?.timeLabel == "עכשיו" || display.hourly.first?.timeLabel == "Now", "Expected 'עכשיו' or 'Now', got \(String(describing: display.hourly.first?.timeLabel))")
        XCTAssertTrue(display.hourly.first?.isNow == true)
        XCTAssertFalse(display.hourly[1].isNow)

        // Three stats check:
        // windText should be formatted, precipText should be "20%", feelsLikeText must be literal em-dash "—"
        XCTAssertEqual(display.stats.precipText, "20%")
        XCTAssertEqual(display.stats.feelsLikeText, "—")
        XCTAssertNotEqual(display.stats.windText, "—")

        // Attribution:
        XCTAssertEqual(display.sourceAttribution, MOTLocationWeatherSnapshot.attribution)
    }

    func testTimeFormattingWithExplicitTimeZone() {
        let cal = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 19
        components.hour = 14
        components.minute = 0
        components.timeZone = TimeZone(identifier: "UTC")
        let date = cal.date(from: components)!

        let jerusalemTZ = TimeZone(identifier: "Asia/Jerusalem")!
        let nyTZ = TimeZone(identifier: "America/New_York")!
        let locale = Locale(identifier: "en_US")

        // 14:00 UTC = 17:00 in Jerusalem (+3 DST) and 10:00 in New York (-4 EDT)
        let jerusalemTime = WeatherFormatter.formatTime(date, locale: locale, timeZone: jerusalemTZ)
        let nyTime = WeatherFormatter.formatTime(date, locale: locale, timeZone: nyTZ)

        XCTAssertTrue(jerusalemTime.contains("5"), "Expected 5 PM for Jerusalem, got \(jerusalemTime)")
        XCTAssertTrue(nyTime.contains("10"), "Expected 10 AM for NY, got \(nyTime)")
    }

    func testHebrewLocalizationResourcesLoaded() {
        guard let hebrewPath = Bundle.module.path(forResource: "he", ofType: "lproj"),
              let heBundle = Bundle(path: hebrewPath) else {
            XCTFail("Missing he.lproj in OneBusAwayWeather bundle")
            return
        }

        let nowLabel = heBundle.localizedString(forKey: "weather.now", value: nil, table: nil)
        XCTAssertEqual(nowLabel, "עכשיו")

        let rainFormat = heBundle.localizedString(forKey: "weather.chance_of_rain_format", value: nil, table: nil)
        XCTAssertTrue(rainFormat.contains("סיכוי לגשם"))

        let feelsLike = heBundle.localizedString(forKey: "weather.stat.feels_like", value: nil, table: nil)
        XCTAssertEqual(feelsLike, "מרגיש כמו")

        let windSpeed = heBundle.localizedString(forKey: "weather.stat.wind", value: nil, table: nil)
        XCTAssertEqual(windSpeed, "מהירות רוח")
    }
}
