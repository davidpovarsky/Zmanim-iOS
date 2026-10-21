import XCTest
@testable import Zmanim

final class WidgetDaySelectorTests: XCTestCase {
    func testPartitionsDayItemsIntoPagesOfFive() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 5))!

        var items: [ZmanItem] = []
        for i in 0..<12 {
            let itemDate = baseDate.addingTimeInterval(TimeInterval(i * 3600))
            items.append(ZmanItem(key: "zman_\(i)", hebrewTitle: "זמן \(i)", englishTitle: "Zman \(i)", icon: "star", date: itemDate))
        }

        let selector = WidgetDaySelector(allItems: items, referenceDate: baseDate, timeZone: timeZone, pageSize: 5)
        XCTAssertEqual(selector.dayItems.count, 12)
        XCTAssertEqual(selector.pageCount, 3)

        let page0 = selector.items(for: 0)
        XCTAssertEqual(page0.count, 5)
        XCTAssertEqual(page0.first?.key, "zman_0")
        XCTAssertEqual(page0.last?.key, "zman_4")

        let page1 = selector.items(for: 1)
        XCTAssertEqual(page1.count, 5)
        XCTAssertEqual(page1.first?.key, "zman_5")
        XCTAssertEqual(page1.last?.key, "zman_9")

        let page2 = selector.items(for: 2)
        XCTAssertEqual(page2.count, 2)
        XCTAssertEqual(page2.first?.key, "zman_10")
        XCTAssertEqual(page2.last?.key, "zman_11")

        let pageOutOfBounds = selector.items(for: 3)
        XCTAssertTrue(pageOutOfBounds.isEmpty)
    }

    func testHandlesEmptyItemsGracefully() {
        let timeZone = TimeZone.current
        let selector = WidgetDaySelector(allItems: [], referenceDate: Date(), timeZone: timeZone)
        XCTAssertEqual(selector.pageCount, 1)
        XCTAssertTrue(selector.items(for: 0).isEmpty)
    }
}
