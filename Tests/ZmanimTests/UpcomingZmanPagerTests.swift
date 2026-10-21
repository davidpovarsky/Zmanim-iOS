import XCTest
@testable import Zmanim

final class UpcomingZmanPagerTests: XCTestCase {

    // 1. At 15:00: Page 0 starts at the nearest upcoming time, NOT Alot HaShachar
    func testPage0StartsAtUpcomingZmanAt1500() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 15, minute: 0, second: 0))!

        let alot = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 5, minute: 15))!
        let sunrise = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 6, minute: 40))!
        let chatzot = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 12, minute: 30))!
        let minchaKetana = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 16, minute: 0))!
        let plag = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 17, minute: 0))!
        let sunset = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 18, minute: 5))!
        let tzeit = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 18, minute: 45))!
        let tzeitRT = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 19, minute: 20))!

        // Tomorrow times
        let tomAlot = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 5, minute: 16))!
        let tomSunrise = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 6, minute: 41))!

        let allItems = [
            ZmanItem(key: "alotHaShachar", hebrewTitle: "עלות השחר", englishTitle: "Alot", icon: "moon", date: alot),
            ZmanItem(key: "sunrise", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise", date: sunrise),
            ZmanItem(key: "chatzot", hebrewTitle: "חצות", englishTitle: "Chatzot", icon: "sun", date: chatzot),
            ZmanItem(key: "minchaKetana", hebrewTitle: "מנחה קטנה", englishTitle: "Mincha Ketana", icon: "sun.min", date: minchaKetana),
            ZmanItem(key: "plagHaMincha", hebrewTitle: "פלג המנחה", englishTitle: "Plag", icon: "sun.haze", date: plag),
            ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset", date: sunset),
            ZmanItem(key: "tzeit", hebrewTitle: "צאת הכוכבים", englishTitle: "Tzeit", icon: "moon.stars", date: tzeit),
            ZmanItem(key: "tzeitRT", hebrewTitle: "רבנו תם", englishTitle: "RT", icon: "moon.fill", date: tzeitRT),
            ZmanItem(key: "alotTom", hebrewTitle: "עלות השחר", englishTitle: "Alot", icon: "moon", date: tomAlot),
            ZmanItem(key: "sunriseTom", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise", date: tomSunrise)
        ]

        let pager = UpcomingZmanPager(
            allItems: allItems,
            referenceDate: now,
            timeZone: timeZone,
            pageSize: 5,
            locale: Locale(identifier: "he_IL")
        )

        let page0 = pager.items(for: 0)
        XCTAssertEqual(page0.count, 5)

        // Verifying page 0 contains strictly upcoming items (starting from minchaKetana at 16:00)
        XCTAssertEqual(page0[0].item.key, "minchaKetana")
        XCTAssertEqual(page0[1].item.key, "plagHaMincha")
        XCTAssertEqual(page0[2].item.key, "sunset")
        XCTAssertEqual(page0[3].item.key, "tzeit")
        XCTAssertEqual(page0[4].item.key, "tzeitRT")

        // Past items must not appear on Page 0
        XCTAssertFalse(page0.contains(where: { $0.item.key == "alotHaShachar" }))
        XCTAssertFalse(page0.contains(where: { $0.item.key == "sunrise" }))
        XCTAssertFalse(page0.contains(where: { $0.item.key == "chatzot" }))

        // All today items should not have tomorrow tag
        for item in page0 {
            XCTAssertFalse(item.isTomorrow)
            XCTAssertNil(item.dayLabel)
        }

        // Page 1 should contain tomorrow's items
        let page1 = pager.items(for: 1)
        XCTAssertEqual(page1.count, 2)
        XCTAssertEqual(page1[0].item.key, "alotTom")
        XCTAssertTrue(page1[0].isTomorrow)
        XCTAssertEqual(page1[0].dayLabel, "מחר")
        XCTAssertEqual(page1[1].item.key, "sunriseTom")
        XCTAssertTrue(page1[1].isTomorrow)
    }

    // 2. When only 1 or 3 zmanim remain today: tomorrow completes the page of 5 with "מחר" tags
    func testTomorrowCompletesPageWhenFewZmanimRemainToday() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 18, minute: 30))!
        let tzeit = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 18, minute: 45))!
        let tzeitRT = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 19, minute: 20))!

        // Tomorrow items
        let tomAlot = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 5, minute: 16))!
        let tomSunrise = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 6, minute: 41))!
        let tomShma = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 9, minute: 15))!
        let tomChatzot = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12, minute: 30))!

        let allItems = [
            ZmanItem(key: "tzeit", hebrewTitle: "צאת הכוכבים", englishTitle: "Tzeit", icon: "moon.stars", date: tzeit),
            ZmanItem(key: "tzeitRT", hebrewTitle: "רבנו תם", englishTitle: "RT", icon: "moon.fill", date: tzeitRT),
            ZmanItem(key: "tomAlot", hebrewTitle: "עלות השחר", englishTitle: "Alot", icon: "moon", date: tomAlot),
            ZmanItem(key: "tomSunrise", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise", date: tomSunrise),
            ZmanItem(key: "tomShma", hebrewTitle: "סוף זמן שמע", englishTitle: "Shma", icon: "sun", date: tomShma),
            ZmanItem(key: "tomChatzot", hebrewTitle: "חצות", englishTitle: "Chatzot", icon: "sun.max", date: tomChatzot)
        ]

        let pager = UpcomingZmanPager(
            allItems: allItems,
            referenceDate: now,
            timeZone: timeZone,
            pageSize: 5,
            locale: Locale(identifier: "he_IL")
        )

        let page0 = pager.items(for: 0)
        XCTAssertEqual(page0.count, 5)

        // First 2 are today
        XCTAssertEqual(page0[0].item.key, "tzeit")
        XCTAssertFalse(page0[0].isTomorrow)
        XCTAssertNil(page0[0].dayLabel)

        XCTAssertEqual(page0[1].item.key, "tzeitRT")
        XCTAssertFalse(page0[1].isTomorrow)
        XCTAssertNil(page0[1].dayLabel)

        // Next 3 are tomorrow
        XCTAssertEqual(page0[2].item.key, "tomAlot")
        XCTAssertTrue(page0[2].isTomorrow)
        XCTAssertEqual(page0[2].dayLabel, "מחר")

        XCTAssertEqual(page0[3].item.key, "tomSunrise")
        XCTAssertTrue(page0[3].isTomorrow)
        XCTAssertEqual(page0[3].dayLabel, "מחר")

        XCTAssertEqual(page0[4].item.key, "tomShma")
        XCTAssertTrue(page0[4].isTomorrow)
        XCTAssertEqual(page0[4].dayLabel, "מחר")

        // Page 1 has the remaining tomorrow item
        let page1 = pager.items(for: 1)
        XCTAssertEqual(page1.count, 1)
        XCTAssertEqual(page1[0].item.key, "tomChatzot")
        XCTAssertTrue(page1[0].isTomorrow)
    }

    // 3. When 0 zmanim remain today (night at 23:00): Page 0 consists completely of tomorrow's items
    func testWhenAllTodayPassedPage0IsTomorrow() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 23, minute: 0))!
        let pastSunset = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 18, minute: 5))!

        let tomAlot = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 5, minute: 16))!
        let tomSunrise = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 6, minute: 41))!

        let allItems = [
            ZmanItem(key: "pastSunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset", date: pastSunset),
            ZmanItem(key: "tomAlot", hebrewTitle: "עלות השחר", englishTitle: "Alot", icon: "moon", date: tomAlot),
            ZmanItem(key: "tomSunrise", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise", date: tomSunrise)
        ]

        let pager = UpcomingZmanPager(
            allItems: allItems,
            referenceDate: now,
            timeZone: timeZone,
            pageSize: 5,
            locale: Locale(identifier: "he_IL")
        )

        let page0 = pager.items(for: 0)
        XCTAssertEqual(page0.count, 2)
        XCTAssertEqual(page0[0].item.key, "tomAlot")
        XCTAssertTrue(page0[0].isTomorrow)
        XCTAssertEqual(page0[0].dayLabel, "מחר")
        XCTAssertEqual(page0[1].item.key, "tomSunrise")
        XCTAssertTrue(page0[1].isTomorrow)
    }

    // 4. English localization gives "Tomorrow"
    func testEnglishLocalizationTomorrow() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 23, minute: 0))!
        let tomAlot = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 5, minute: 16))!

        let allItems = [
            ZmanItem(key: "tomAlot", hebrewTitle: "עלות השחר", englishTitle: "Alot", icon: "moon", date: tomAlot)
        ]

        let pager = UpcomingZmanPager(
            allItems: allItems,
            referenceDate: now,
            timeZone: timeZone,
            pageSize: 5,
            locale: Locale(identifier: "en_US")
        )

        let page0 = pager.items(for: 0)
        XCTAssertEqual(page0.count, 1)
        XCTAssertEqual(page0[0].dayLabel, "Tomorrow")
    }

    // 5. Wrap-around cyclic navigation
    func testCyclicWrapAround() {
        let timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 100000)

        var items: [ZmanItem] = []
        for i in 0..<12 {
            items.append(ZmanItem(
                key: "z_\(i)",
                hebrewTitle: "זמן \(i)",
                englishTitle: "Zman \(i)",
                icon: "star",
                date: now.addingTimeInterval(Double(i * 3600))
            ))
        }

        let pager = UpcomingZmanPager(allItems: items, referenceDate: now, timeZone: timeZone, pageSize: 5)
        XCTAssertEqual(pager.pageCount, 3)

        // Index 0 -> page 0
        let p0 = pager.items(for: 0)
        XCTAssertEqual(p0.first?.item.key, "z_0")

        // Index 2 -> page 2
        let p2 = pager.items(for: 2)
        XCTAssertEqual(p2.first?.item.key, "z_10")

        // Index 3 (overflow) wraps cyclically to 0
        let pWrapForward = pager.items(for: 3)
        XCTAssertEqual(pWrapForward.first?.item.key, "z_0")

        // Index -1 wraps cyclically to 2
        let pWrapBack = pager.items(for: -1)
        XCTAssertEqual(pWrapBack.first?.item.key, "z_10")
    }

    // 5. Cross-timezone: London vs New York
    func testCrossTimeZoneHandling() {
        let nyZone = TimeZone(identifier: "America/New_York")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = nyZone

        let nowNY = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 14, minute: 0))!
        let zmanNY = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 16, minute: 30))!

        let item = ZmanItem(key: "nyMincha", hebrewTitle: "מנחה", englishTitle: "Mincha", icon: "sun", date: zmanNY)
        let pager = UpcomingZmanPager(allItems: [item], referenceDate: nowNY, timeZone: nyZone, pageSize: 5)

        XCTAssertEqual(pager.pageCount, 1)
        let page0 = pager.items(for: 0)
        XCTAssertEqual(page0.count, 1)
        XCTAssertEqual(page0[0].item.key, "nyMincha")
    }
}
