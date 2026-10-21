import XCTest
@testable import Zmanim

final class CitySearchTests: XCTestCase {
    func testSuggestionFullDescription() {
        let withSubtitle = CitySearchSuggestion(title: "Jerusalem", subtitle: "Israel")
        XCTAssertEqual(withSubtitle.fullDescription, "Jerusalem, Israel")

        let withoutSubtitle = CitySearchSuggestion(title: "Tel Aviv", subtitle: "")
        XCTAssertEqual(withoutSubtitle.fullDescription, "Tel Aviv")
    }

    func testResolvedLocationProperties() {
        let loc = ResolvedLocation(
            displayName: "Haifa",
            latitude: 32.794,
            longitude: 34.989,
            timeZoneID: "Asia/Jerusalem",
            source: .fixedSearch
        )

        XCTAssertEqual(loc.displayName, "Haifa")
        XCTAssertEqual(loc.timeZone.identifier, "Asia/Jerusalem")
        XCTAssertEqual(loc.source, .fixedSearch)
    }

    func testCitySearchErrorsLocalized() {
        XCTAssertFalse(CitySearchError.noResults.localizedDescription.isEmpty)
        XCTAssertFalse(CitySearchError.invalidCoordinates.localizedDescription.isEmpty)
        XCTAssertFalse(CitySearchError.timeZoneNotFound.localizedDescription.isEmpty)
    }
}
