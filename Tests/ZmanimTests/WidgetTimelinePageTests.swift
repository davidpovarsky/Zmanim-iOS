import XCTest
@testable import Zmanim

final class WidgetTimelinePageTests: XCTestCase {

    // W03: At 15:00, upcoming items strictly exclude past morning zmanim
    func testW03_At1500UpcomingItemsExcludePastMorningTimes() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 15, minute: 0))!
        let alot = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 5, minute: 15))!
        let sunrise = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 6, minute: 30))!
        let chatzot = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 12, minute: 30))!
        let minchaKetana = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 16, minute: 0))!
        let sunset = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 18, minute: 30))!

        let allItems = [
            ZmanItem(key: "alot", hebrewTitle: "עלות השחר", englishTitle: "Alot", icon: "moon", date: alot),
            ZmanItem(key: "sunrise", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise", date: sunrise),
            ZmanItem(key: "chatzot", hebrewTitle: "חצות", englishTitle: "Chatzot", icon: "sun", date: chatzot),
            ZmanItem(key: "minchaKetana", hebrewTitle: "מנחה קטנה", englishTitle: "Mincha Ketana", icon: "sun.min", date: minchaKetana),
            ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset", date: sunset)
        ]

        let pager = UpcomingZmanPager(allItems: allItems, referenceDate: now, timeZone: timeZone, pageSize: 5)
        let page0 = pager.items(for: 0)

        XCTAssertEqual(page0.count, 2)
        XCTAssertEqual(page0[0].item.key, "minchaKetana")
        XCTAssertEqual(page0[1].item.key, "sunset")
        XCTAssertFalse(page0.contains(where: { $0.item.key == "alot" }))
        XCTAssertFalse(page0.contains(where: { $0.item.key == "sunrise" }))
        XCTAssertFalse(page0.contains(where: { $0.item.key == "chatzot" }))
    }

    // W04: At 22:48 (all today items passed), page 0 starts with tomorrow's earliest morning zman (e.g. Alot HaShachar),
    // and NOT sunset/tzeit/RT tomorrow as the opening page
    func testW04_At2248Page0StartsWithEarliestTomorrowZman() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 22, minute: 48))!
        let todaySunset = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 18, minute: 15))!
        let todayTzeit = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 19, minute: 0))!

        let tomAlot = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 5, minute: 16))!
        let tomSunrise = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 6, minute: 45))!
        let tomChatzot = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12, minute: 30))!
        let tomMincha = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 16, minute: 0))!
        let tomSunset = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 18, minute: 14))!
        let tomTzeit = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 18, minute: 58))!
        let tomRT = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 19, minute: 26))!

        let allItems = [
            ZmanItem(key: "sunsetToday", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset", date: todaySunset),
            ZmanItem(key: "tzeitToday", hebrewTitle: "צאת הכוכבים", englishTitle: "Tzeit", icon: "moon", date: todayTzeit),
            ZmanItem(key: "alotTom", hebrewTitle: "עלות השחר", englishTitle: "Alot", icon: "moon", date: tomAlot),
            ZmanItem(key: "sunriseTom", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise", date: tomSunrise),
            ZmanItem(key: "chatzotTom", hebrewTitle: "חצות", englishTitle: "Chatzot", icon: "sun", date: tomChatzot),
            ZmanItem(key: "minchaTom", hebrewTitle: "מנחה קטנה", englishTitle: "Mincha", icon: "sun.min", date: tomMincha),
            ZmanItem(key: "sunsetTom", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset", date: tomSunset),
            ZmanItem(key: "tzeitTom", hebrewTitle: "צאת הכוכבים", englishTitle: "Tzeit", icon: "moon", date: tomTzeit),
            ZmanItem(key: "rtTom", hebrewTitle: "רבנו תם", englishTitle: "RT", icon: "moon.fill", date: tomRT)
        ]

        let pager = UpcomingZmanPager(allItems: allItems, referenceDate: now, timeZone: timeZone, pageSize: 5)
        let page0 = pager.items(for: 0)

        XCTAssertEqual(page0.count, 5)
        XCTAssertEqual(page0[0].item.key, "alotTom", "Page 0 at late night must start with earliest tomorrow zman (Alot HaShachar)")
        XCTAssertEqual(page0[1].item.key, "sunriseTom")
        XCTAssertEqual(page0[2].item.key, "chatzotTom")
        XCTAssertEqual(page0[3].item.key, "minchaTom")
        XCTAssertEqual(page0[4].item.key, "sunsetTom")

        // Page 1 contains remaining evening times
        let page1 = pager.items(for: 1)
        XCTAssertEqual(page1.count, 2)
        XCTAssertEqual(page1[0].item.key, "tzeitTom")
        XCTAssertEqual(page1[1].item.key, "rtTom")
    }

    // W05: Expiry after 60 seconds returns to page 0
    func testW05_60SecondExpiryRevertsToPage0() {
        let now = Date()
        let expired = now.addingTimeInterval(65)
        let state = WidgetPageState(pageIndex: 2, lastInteractionAt: now, expiresAt: now.addingTimeInterval(60), dayKey: "2026-10-20", locationFingerprint: "city_test")

        let effective = WidgetPageStateStore.effectivePageIndex(
            state: state,
            currentDate: expired,
            currentDayKey: "2026-10-20",
            currentLocationFingerprint: "city_test",
            pageCount: 3
        )

        XCTAssertEqual(effective, 0, "Effective page index must revert to 0 once 60 seconds expired")
    }

    // W06: Two widgets for two cities: paging in one does not change page in the other
    func testW06_PagingInOneCityDoesNotChangeTheOther() {
        let now = Date()
        let stateA = WidgetPageState(pageIndex: 2, lastInteractionAt: now, expiresAt: now.addingTimeInterval(60), dayKey: "2026-10-20", locationFingerprint: "city_a")
        WidgetPageStateStore.saveState(stateA, for: "city_a")

        let loadedB = WidgetPageStateStore.loadState(for: "city_b")
        XCTAssertNil(loadedB, "City B must have no state loaded from City A")

        let effB = WidgetPageStateStore.effectivePageIndex(
            state: loadedB,
            currentDate: now,
            currentDayKey: "2026-10-20",
            currentLocationFingerprint: "city_b",
            pageCount: 3
        )
        XCTAssertEqual(effB, 0, "City B must remain on page 0")
    }

    // W07: Day rollover in different timezone calculates day rollover according to that timezone
    func testW07_DayRolloverCalculatedInTargetTimeZone() {
        let nyZone = TimeZone(identifier: "America/New_York")!
        let jmZone = TimeZone(identifier: "Asia/Jerusalem")!

        // When it is 01:00 AM on Oct 21 in Jerusalem, it is still 18:00 PM on Oct 20 in New York
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = jmZone
        let testDate = formatter.date(from: "2026-10-21 01:00")!

        let jmDayKey = WidgetPageStateStore.dayKey(for: testDate, timeZone: jmZone)
        let nyDayKey = WidgetPageStateStore.dayKey(for: testDate, timeZone: nyZone)

        XCTAssertEqual(jmDayKey, "2026-10-21")
        XCTAssertEqual(nyDayKey, "2026-10-20")
    }
}
