import XCTest
@testable import Zmanim

final class LocalizationTests: XCTestCase {
    func testZmanItemLocalizedTitle() {
        let now = Date()
        let item = ZmanItem(
            key: "sunrise",
            hebrewTitle: "הנץ החמה",
            englishTitle: "Sunrise",
            icon: "sunrise.fill",
            date: now
        )

        XCTAssertEqual(item.localizedTitle(locale: Locale(identifier: "he_IL")), "הנץ החמה")
        XCTAssertEqual(item.localizedTitle(locale: Locale(identifier: "en_US")), "Sunrise")
    }

    func testLocationModeTitles() {
        XCTAssertEqual(LocationMode.current.localizedTitle(locale: Locale(identifier: "he_IL")), "המיקום הנוכחי")
        XCTAssertEqual(LocationMode.current.localizedTitle(locale: Locale(identifier: "en_US")), "Current Location")
        XCTAssertEqual(LocationMode.fixed.localizedTitle(locale: Locale(identifier: "he_IL")), "עיר קבועה")
        XCTAssertEqual(LocationMode.fixed.localizedTitle(locale: Locale(identifier: "en_US")), "Fixed City")
    }

    func testWeatherSnapshotAttribution() {
        let snapshot = WeatherSnapshot(
            hours: [],
            retrievedAt: Date(),
            locationLatitude: 31.778,
            locationLongitude: 35.235,
            expiresAt: nil
        )

        XCTAssertEqual(snapshot.attribution(language: "he"), "נתוני מזג אוויר: MET Norway (CC BY 4.0)")
        XCTAssertEqual(snapshot.attribution(language: "en"), "Weather data: MET Norway (CC BY 4.0)")
    }
}
