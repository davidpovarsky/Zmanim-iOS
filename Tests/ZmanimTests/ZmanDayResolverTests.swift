import XCTest
@testable import Zmanim

final class ZmanDayResolverTests: XCTestCase {
    func testFiltersAndSortsItemsForTargetDay() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let day1Comps = DateComponents(year: 2026, month: 10, day: 19, hour: 12, minute: 0)
        let day1Date = calendar.date(from: day1Comps)!

        let day2Comps = DateComponents(year: 2026, month: 10, day: 20, hour: 12, minute: 0)
        let day2Date = calendar.date(from: day2Comps)!

        let item1 = ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill", date: calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 18, minute: 0))!)
        let item2 = ZmanItem(key: "sunrise", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise.fill", date: calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 6, minute: 45))!)
        let item3 = ZmanItem(key: "sunrise", hebrewTitle: "זריחה מחר", englishTitle: "Sunrise", icon: "sunrise.fill", date: calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 6, minute: 46))!)

        let day1Items = ZmanDayResolver.itemsForDay(from: [item1, item2, item3], date: day1Date, timeZone: timeZone)
        XCTAssertEqual(day1Items.count, 2)
        XCTAssertEqual(day1Items.first?.key, "sunrise")
        XCTAssertEqual(day1Items.last?.key, "sunset")

        let day2Items = ZmanDayResolver.itemsForDay(from: [item1, item2, item3], date: day2Date, timeZone: timeZone)
        XCTAssertEqual(day2Items.count, 1)
        XCTAssertEqual(day2Items.first?.key, "sunrise")
    }

    func testExtractsSunriseAndSunsetForSpecifiedDay() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let targetDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 12))!
        let sunriseDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 6, minute: 45))!
        let sunsetDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 18, minute: 2))!

        let items = [
            ZmanItem(key: "sunrise", hebrewTitle: "הנץ", englishTitle: "Sunrise", icon: "sunrise.fill", date: sunriseDate),
            ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill", date: sunsetDate)
        ]

        let extractedRise = ZmanDayResolver.sunrise(from: items, date: targetDate, timeZone: timeZone)
        let extractedSet = ZmanDayResolver.sunset(from: items, date: targetDate, timeZone: timeZone)

        XCTAssertEqual(extractedRise, sunriseDate)
        XCTAssertEqual(extractedSet, sunsetDate)
    }
}
