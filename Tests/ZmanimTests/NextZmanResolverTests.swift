import XCTest
@testable import Zmanim

final class NextZmanResolverTests: XCTestCase {
    func testReturnsNextZmanForTodayWhenUpcomingExists() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let now = Date(timeIntervalSince1970: 1760868000) // 10:00:00
        let item1 = ZmanItem(key: "sunrise", hebrewTitle: "הנץ", englishTitle: "Sunrise", icon: "sunrise.fill", date: now.addingTimeInterval(-3600))
        let item2 = ZmanItem(key: "chatzot", hebrewTitle: "חצות", englishTitle: "Chatzot", icon: "sun.max.fill", date: now.addingTimeInterval(3600))
        let item3 = ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill", date: now.addingTimeInterval(7200))

        let result = NextZmanResolver.resolve(allItems: [item1, item2, item3], now: now, timeZone: timeZone)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.item.key, "chatzot")
        XCTAssertFalse(result?.isTomorrow ?? true)
        XCTAssertNil(result?.dayLabel)
    }

    func testResolvesTomorrowZmanWhenAllTodayZmanimHavePassedHebrew() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        // Base date: 2026-10-19 21:00:00
        let components = DateComponents(year: 2026, month: 10, day: 19, hour: 21, minute: 0, second: 0)
        let now = calendar.date(from: components)!

        let todaySunset = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 18, minute: 2, second: 0))!
        let todayTzeit = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 18, minute: 40, second: 0))!

        let tomorrowAlot = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 5, minute: 32, second: 0))!
        let tomorrowSunrise = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 6, minute: 45, second: 0))!

        let items = [
            ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill", date: todaySunset),
            ZmanItem(key: "tzeit", hebrewTitle: "צאת הכוכבים", englishTitle: "Tzeit", icon: "moon.stars.fill", date: todayTzeit),
            ZmanItem(key: "alotHaShachar", hebrewTitle: "עלות השחר", englishTitle: "Alot HaShachar", icon: "moon.stars.fill", date: tomorrowAlot),
            ZmanItem(key: "sunrise", hebrewTitle: "הנץ החמה", englishTitle: "Sunrise", icon: "sunrise.fill", date: tomorrowSunrise)
        ]

        let result = NextZmanResolver.resolve(allItems: items, now: now, timeZone: timeZone, locale: Locale(identifier: "he_IL"))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.item.key, "alotHaShachar")
        XCTAssertTrue(result?.isTomorrow ?? false)
        XCTAssertEqual(result?.dayLabel, "מחר")
    }

    func testResolvesTomorrowZmanWhenAllTodayZmanimHavePassedEnglish() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = DateComponents(year: 2026, month: 10, day: 19, hour: 21, minute: 0, second: 0)
        let now = calendar.date(from: components)!

        let tomorrowAlot = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 5, minute: 32, second: 0))!
        let items = [
            ZmanItem(key: "alotHaShachar", hebrewTitle: "עלות השחר", englishTitle: "Alot HaShachar", icon: "moon.stars.fill", date: tomorrowAlot)
        ]

        let result = NextZmanResolver.resolve(allItems: items, now: now, timeZone: timeZone, locale: Locale(identifier: "en_US"))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.item.key, "alotHaShachar")
        XCTAssertTrue(result?.isTomorrow ?? false)
        XCTAssertEqual(result?.dayLabel, "Tomorrow")
    }

    func testReturnsNilWhenNoFutureItemsRemain() {
        let timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        let pastItem = ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill", date: now.addingTimeInterval(-3600))
        let result = NextZmanResolver.resolve(allItems: [pastItem], now: now, timeZone: timeZone)
        XCTAssertNil(result)
    }
}
