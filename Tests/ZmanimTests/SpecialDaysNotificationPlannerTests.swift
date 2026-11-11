import XCTest
@testable import Zmanim

final class SpecialDaysNotificationPlannerTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "Asia/Jerusalem")!

    func testDisabledMasterProducesZeroNotifications() {
        let settings = UserSettings(
            specialDaysMasterEnabled: false,
            shabbatEnabled: true,
            holidayEnabled: true
        )

        let items: [ZmanItem] = [
            ZmanItem(key: "candleLighting", hebrewTitle: "כניסת שבת", englishTitle: "Candle Lighting", icon: "flame.fill", date: Date().addingTimeInterval(3600))
        ]

        let planned = SpecialDayNotificationPlanner.plan(
            settings: settings,
            items: items,
            timeZone: timeZone,
            now: Date()
        )

        XCTAssertTrue(planned.isEmpty)
    }

    func testShabbatPlanningSchedulesCandleAndHavdalah() {
        let settings = UserSettings(
            specialDaysMasterEnabled: true,
            shabbatEnabled: true,
            holidayEnabled: false
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        // Find next Friday 17:00 and Saturday 18:30
        let now = Date()
        var fridayComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        fridayComponents.weekday = 6 // Friday
        fridayComponents.hour = 17
        fridayComponents.minute = 0
        let fridayCandle = calendar.date(from: fridayComponents)!

        var saturdayComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        saturdayComponents.weekday = 7 // Saturday
        saturdayComponents.hour = 18
        saturdayComponents.minute = 30
        let saturdayHavdalah = calendar.date(from: saturdayComponents)!

        let items: [ZmanItem] = [
            ZmanItem(key: "candleLighting", hebrewTitle: "כניסת שבת", englishTitle: "Candle Lighting", icon: "flame.fill", date: fridayCandle),
            ZmanItem(key: "tzeit7083deg", hebrewTitle: "צאת שבת", englishTitle: "Havdalah", icon: "sparkles", date: saturdayHavdalah)
        ]

        let planned = SpecialDayNotificationPlanner.plan(
            settings: settings,
            items: items,
            timeZone: timeZone,
            now: fridayCandle.addingTimeInterval(-7200) // 2 hours before Friday candle
        )

        XCTAssertEqual(planned.count, 2)
        XCTAssertTrue(planned[0].id.hasPrefix("zmanim.special.shabbat.candle."))
        XCTAssertTrue(planned[1].id.hasPrefix("zmanim.special.shabbat.havdalah."))
    }
}
