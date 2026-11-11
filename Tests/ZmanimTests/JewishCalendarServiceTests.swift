import XCTest
@testable import Zmanim

final class JewishCalendarServiceTests: XCTestCase {
    func testRoshChodeshAndCandleLightingParseSeparately() throws {
        let json = """
        {"items":[
          {"title":"Rosh Chodesh Kislev","hebrew":"ראש חודש כסלו","date":"2026-11-10","category":"roshchodesh"},
          {"title":"Candle lighting: 16:20","hebrew":"הדלקת נרות","date":"2026-11-13T16:20:00+02:00","category":"candles"},
          {"title":"Parashat Toldot","hebrew":"פרשת תולדות","date":"2026-11-14","category":"parashat"}
        ]}
        """
        let zone = try XCTUnwrap(TimeZone(identifier: "Asia/Jerusalem"))
        let events = try JewishCalendarService.decodeEvents(Data(json.utf8), timeZone: zone)
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.first?.category, "roshchodesh")
        XCTAssertNil(events.first?.time)
        XCTAssertEqual(events.last?.category, "parashat")
        let timed = JewishCalendarService.timedItems(from: events)
        XCTAssertEqual(timed.count, 1)
        XCTAssertEqual(timed.first?.key, "candleLighting")
        XCTAssertEqual(Calendar(identifier: .gregorian).component(.hour, from: timed[0].date), 14)
    }

    func testFastStartEndAndChametzAreKept() throws {
        let json = """
        {"items":[
          {"title":"Fast begins","hebrew":"תחילת הצום","date":"2027-03-22T04:29:00+02:00","category":"zmanim","subcat":"fast"},
          {"title":"Fast ends","hebrew":"סיום הצום","date":"2027-03-22T18:07:00+02:00","category":"zmanim","subcat":"fast"},
          {"title":"Biur Chametz","date":"2027-04-21T11:32:00+03:00","category":"zmanim","subcat":"biurChametz"}
        ]}
        """
        let events = try JewishCalendarService.decodeEvents(Data(json.utf8), timeZone: .gmt)
        XCTAssertEqual(JewishCalendarService.timedItems(from: events).map(\.key),
                       ["fastStart", "fastEnd", "biurChametz"])
    }

    func testMissingOptionalHebrewTitleAndMemoAreSupported() throws {
        let json = """
        {"items":[{"title":"Fast of Esther","date":"2027-03-22","category":"holiday"}]}
        """
        let events = try JewishCalendarService.decodeEvents(Data(json.utf8), timeZone: .gmt)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].title, "Fast of Esther")
        XCTAssertNil(events[0].time)
    }
}
