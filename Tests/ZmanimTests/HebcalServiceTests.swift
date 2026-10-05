import XCTest
import CoreLocation
@testable import Zmanim

final class HebcalServiceTests: XCTestCase {
    func testDefinitionsContainKeyZmanim() {
        let keys = Set(HebcalService.definitions.map(\.key))
        XCTAssertTrue(keys.contains("sunrise"))
        XCTAssertTrue(keys.contains("sunset"))
        XCTAssertTrue(keys.contains("sofZmanShma"))
        XCTAssertTrue(keys.contains("chatzot"))
        XCTAssertTrue(keys.contains("tzeit7083deg"))
    }

    func testResponseDecoding() throws {
        let sampleJSON = """
        {
            "date": "2026-10-05",
            "times": {
                "sunrise": "2026-10-05T06:33:00+03:00",
                "sunset": "2026-10-05T18:18:00+03:00",
                "chatzot": "2026-10-05T12:25:30+03:00",
                "tzeit7083deg": "2026-10-05T18:43:00+03:00"
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(HebcalService.Response.self, from: sampleJSON)
        XCTAssertEqual(response.date, "2026-10-05")
        XCTAssertEqual(response.times["sunrise"], "2026-10-05T06:33:00+03:00")
    }

    func testZmanItemSortingAndProperties() {
        let now = Date()
        let item1 = ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill", date: now.addingTimeInterval(3600))
        let item2 = ZmanItem(key: "sunrise", hebrewTitle: "הנץ", englishTitle: "Sunrise", icon: "sunrise.fill", date: now)

        let sorted = [item1, item2].sorted { $0.date < $1.date }
        XCTAssertEqual(sorted.first?.key, "sunrise")
        XCTAssertEqual(sorted.last?.key, "sunset")
    }
}
