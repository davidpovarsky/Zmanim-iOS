import XCTest
@testable import Zmanim

final class METSymbolMapperTests: XCTestCase {
    func testSnowshowersDoesNotMapToRain() {
        // Crucial bug prevention test: snowshowers contains "showers", but MUST map to snow
        let snowshowersDay = "snowshowers_day"
        let iconKey = METSymbolMapper.iconKey(from: snowshowersDay)
        XCTAssertEqual(iconKey, "snow")
        XCTAssertNotEqual(iconKey, "rain")

        let condition = METSymbolMapper.weatherCondition(for: iconKey, isNight: false)
        XCTAssertEqual(condition, .snow)

        let sleetshowersDay = "sleetshowers_day"
        let sleetKey = METSymbolMapper.iconKey(from: sleetshowersDay)
        XCTAssertEqual(sleetKey, "sleet")
        XCTAssertNotEqual(sleetKey, "rain")
    }

    func testRainAndShowersMapToRain() {
        XCTAssertEqual(METSymbolMapper.iconKey(from: "rainshowers_day"), "rain")
        XCTAssertEqual(METSymbolMapper.iconKey(from: "heavyrain"), "rain")
        XCTAssertEqual(METSymbolMapper.iconKey(from: "lightrainshowers_night"), "rain")
    }

    func testClearAndPartlyCloudyDayAndNight() {
        XCTAssertEqual(METSymbolMapper.iconKey(from: "clearsky_day"), "clear-day")
        XCTAssertEqual(METSymbolMapper.iconKey(from: "clearsky_night"), "clear-night")
        XCTAssertEqual(METSymbolMapper.iconKey(from: "fair_day"), "partly-cloudy-day")
        XCTAssertEqual(METSymbolMapper.iconKey(from: "partlycloudy_night"), "partly-cloudy-night")
        XCTAssertEqual(METSymbolMapper.iconKey(from: "cloudy"), "cloudy")
        XCTAssertEqual(METSymbolMapper.iconKey(from: "fog"), "fog")
        XCTAssertEqual(METSymbolMapper.iconKey(from: "thunderstorm"), "thunderstorm")
    }

    func testHebrewConditionText() {
        XCTAssertEqual(METSymbolMapper.conditionText(for: "clearsky_day"), "בהיר")
        XCTAssertEqual(METSymbolMapper.conditionText(for: "clearsky_night"), "לילה בהיר")
        XCTAssertEqual(METSymbolMapper.conditionText(for: "partlycloudy_day"), "מעונן חלקית")
        XCTAssertEqual(METSymbolMapper.conditionText(for: "rainshowers_day"), "ממטרים")
        XCTAssertEqual(METSymbolMapper.conditionText(for: "snowshowers_day"), "ממטרי שלג")
        XCTAssertEqual(METSymbolMapper.conditionText(for: "heavyrain"), "גשם")
        XCTAssertEqual(METSymbolMapper.conditionText(for: "thunderstorm"), "סופת רעמים")
        XCTAssertEqual(METSymbolMapper.conditionText(for: "fog"), "ערפל")
    }

    func testSystemImageNameMapping() {
        XCTAssertEqual(METSymbolMapper.systemImageName(for: "clear-day"), "sun.max.fill")
        XCTAssertEqual(METSymbolMapper.systemImageName(for: "clear-night"), "moon.stars.fill")
        XCTAssertEqual(METSymbolMapper.systemImageName(for: "partly-cloudy-day"), "cloud.sun.fill")
        XCTAssertEqual(METSymbolMapper.systemImageName(for: "rain"), "cloud.rain.fill")
        XCTAssertEqual(METSymbolMapper.systemImageName(for: "snow"), "cloud.snow.fill")
        XCTAssertEqual(METSymbolMapper.systemImageName(for: "thunderstorm"), "cloud.bolt.rain.fill")
    }
}
