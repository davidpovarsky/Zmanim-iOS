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

    private func makeSampleSnapshot(now: Date) -> MOTLocationWeatherSnapshot {
        let hours = (0..<30).map { i in
            MOTLocationWeatherHour(
                time: now.addingTimeInterval(Double(i * 3600)),
                temperatureCelsius: 16.0 + Double(i % 8),
                windMetersPerSecond: 3.5,
                precipitationChancePercent: 20.0,
                iconKey: "partly-cloudy-day"
            )
        }

        return MOTLocationWeatherSnapshot(
            hours: hours,
            retrievedAt: now,
            locationLatitude: 31.778,
            locationLongitude: 35.235
        )
    }

    func testWeatherDisplayHebrewLocalizationStrict() {
        let now = Date()
        let tz = TimeZone(identifier: "Asia/Jerusalem")!
        let locale = Locale(identifier: "he_IL")
        let snapshot = makeSampleSnapshot(now: now)

        let display = WeatherDisplay(
            locationForecast: snapshot,
            locationName: "ירושלים",
            locale: locale,
            timeZone: tz,
            now: now,
            language: "he"
        )

        XCTAssertNotNil(display)
        guard let display else { return }

        XCTAssertEqual(display.header.regionName, "ירושלים")
        XCTAssertEqual(display.hourly.count, 25)
        XCTAssertEqual(display.hourly.first?.timeLabel, "עכשיו", "Strict Hebrew check: must be 'עכשיו', never 'Now'")
        XCTAssertTrue(display.hourly.first?.isNow == true)
        XCTAssertEqual(display.header.conditionSummary, "מעונן חלקית")
        XCTAssertTrue(display.header.chanceOfRainText.contains("סיכוי לגשם"), "Expected Hebrew chance of rain text")
        XCTAssertTrue(display.header.highLowText?.contains("גבוה:") == true, "Expected Hebrew high/low label")
        XCTAssertEqual(display.sourceAttribution, "נתוני מזג אוויר: MET Norway (CC BY 4.0)")
        XCTAssertEqual(display.stats.precipText, "20%")
        XCTAssertEqual(display.stats.feelsLikeText, "—")
        XCTAssertNotEqual(display.stats.windText, "—")
    }

    func testWeatherDisplayEnglishLocalizationStrict() {
        let now = Date()
        let tz = TimeZone(identifier: "America/New_York")!
        let locale = Locale(identifier: "en_US")
        let snapshot = makeSampleSnapshot(now: now)

        let display = WeatherDisplay(
            locationForecast: snapshot,
            locationName: "New York",
            locale: locale,
            timeZone: tz,
            now: now,
            language: "en"
        )

        XCTAssertNotNil(display)
        guard let display else { return }

        XCTAssertEqual(display.header.regionName, "New York")
        XCTAssertEqual(display.hourly.count, 25)
        XCTAssertEqual(display.hourly.first?.timeLabel, "Now", "Strict English check: must be 'Now', never 'עכשיו'")
        XCTAssertTrue(display.hourly.first?.isNow == true)
        XCTAssertEqual(display.header.conditionSummary, "Partly Cloudy")
        XCTAssertTrue(display.header.chanceOfRainText.contains("Chance of Rain"), "Expected English chance of rain text")
        XCTAssertTrue(display.header.highLowText?.contains("H:") == true, "Expected English high/low label")
        XCTAssertEqual(display.sourceAttribution, "Weather data: MET Norway (CC BY 4.0)")
    }

    func testConditionsLocalizationInBothLanguages() {
        // Hebrew
        XCTAssertEqual(WeatherFormatter.conditionText(for: "clear-day", language: "he"), "בהיר")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "clear-night", language: "he"), "בהיר")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "partly-cloudy-day", language: "he"), "מעונן חלקית")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "cloudy", language: "he"), "מעונן")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "rain", language: "he"), "גשם")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "snow", language: "he"), "שלג")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "fog", language: "he"), "ערפל")

        // English
        XCTAssertEqual(WeatherFormatter.conditionText(for: "clear-day", language: "en"), "Clear")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "clear-night", language: "en"), "Clear")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "partly-cloudy-day", language: "en"), "Partly Cloudy")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "cloudy", language: "en"), "Cloudy")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "rain", language: "en"), "Rain")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "snow", language: "en"), "Snow")
        XCTAssertEqual(WeatherFormatter.conditionText(for: "fog", language: "en"), "Fog")
    }

    func testAttributionLocalizationStrict() {
        XCTAssertEqual(MOTLocationWeatherSnapshot.attribution(language: "he"), "נתוני מזג אוויר: MET Norway (CC BY 4.0)")
        XCTAssertEqual(MOTLocationWeatherSnapshot.attribution(language: "en"), "Weather data: MET Norway (CC BY 4.0)")
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

        let jerusalemTime = WeatherFormatter.formatTime(date, locale: locale, timeZone: jerusalemTZ)
        let nyTime = WeatherFormatter.formatTime(date, locale: locale, timeZone: nyTZ)

        XCTAssertTrue(jerusalemTime.contains("5"), "Expected 5 PM for Jerusalem, got \(jerusalemTime)")
        XCTAssertTrue(nyTime.contains("10"), "Expected 10 AM for NY, got \(nyTime)")
    }

    func testHebrewAndEnglishLocalizationResourcesLoaded() {
        guard let heCorePath = Bundle.module.path(forResource: "he", ofType: "lproj"),
              let heBundle = Bundle(path: heCorePath),
              let enCorePath = Bundle.module.path(forResource: "en", ofType: "lproj"),
              let enBundle = Bundle(path: enCorePath) else {
            XCTFail("Missing he.lproj or en.lproj in OneBusAwayWeatherCore bundle")
            return
        }

        XCTAssertEqual(heBundle.localizedString(forKey: "weather.condition.clear", value: nil, table: nil), "בהיר")
        XCTAssertEqual(enBundle.localizedString(forKey: "weather.condition.clear", value: nil, table: nil), "Clear")

        XCTAssertEqual(heBundle.localizedString(forKey: "common.close", value: nil, table: nil), "סגור")
        XCTAssertEqual(enBundle.localizedString(forKey: "common.close", value: nil, table: nil), "Close")
    }
}
