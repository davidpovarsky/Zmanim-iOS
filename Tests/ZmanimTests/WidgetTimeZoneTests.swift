import XCTest
@testable import Zmanim

final class WidgetTimeZoneTests: XCTestCase {
    func testSnapshotRetainsForeignCityTimeZone() {
        let snapshot = ZmanSnapshot(
            cityName: "New York",
            timeZoneID: "America/New_York",
            latitude: 40.7128,
            longitude: -74.0060,
            updatedAt: Date(),
            items: [],
            locationSignature: "New York-America/New_York"
        )

        XCTAssertEqual(snapshot.cityName, "New York")
        XCTAssertEqual(snapshot.timeZone.identifier, "America/New_York")
        XCTAssertEqual(snapshot.locationSignature, "New York-America/New_York")
    }

    func testWidgetDaySelectorRespectsSnapshotTimeZone() {
        let nyTimeZone = TimeZone(identifier: "America/New_York")!
        var nyCalendar = Calendar(identifier: .gregorian)
        nyCalendar.timeZone = nyTimeZone

        // 10:00 AM NY time
        let now = Date()
        let startOfDay = nyCalendar.startOfDay(for: now)

        let items = [
            ZmanItem(key: "sunrise", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise.fill", date: startOfDay.addingTimeInterval(6 * 3600)),
            ZmanItem(key: "chatzot", hebrewTitle: "חצות", englishTitle: "Chatzot", icon: "sun.max.fill", date: startOfDay.addingTimeInterval(12 * 3600)),
            ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill", date: startOfDay.addingTimeInterval(18 * 3600))
        ]

        let selector = WidgetDaySelector(
            allItems: items,
            referenceDate: startOfDay.addingTimeInterval(8 * 3600),
            timeZone: nyTimeZone
        )

        let page0 = selector.items(for: 0)
        XCTAssertEqual(page0.count, 3)
    }
}
