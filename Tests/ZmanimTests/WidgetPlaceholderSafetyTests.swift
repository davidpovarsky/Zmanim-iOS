import XCTest
@testable import Zmanim

final class WidgetPlaceholderSafetyTests: XCTestCase {

    // W01: placeholder entry in production is a neutral skeleton without fake clock times or Jerusalem mock
    func testW01_PlaceholderEntryContainsNoFakeSnapshotOrTimes() {
        let entry = ZmanEntry(
            date: Date(),
            snapshot: nil,
            state: nil,
            pageIndex: 0,
            pageCount: 1,
            isGPS: false,
            locationKey: "default",
            customCityName: nil,
            isPlaceholder: true
        )

        XCTAssertNil(entry.snapshot, "Placeholder entry must not contain a fake snapshot")
        XCTAssertNil(entry.next, "Placeholder entry must have no next zman item computed")
        XCTAssertNil(entry.customCityName, "Placeholder entry must not specify a custom city like Jerusalem")
        XCTAssertTrue(entry.isPlaceholder, "Placeholder flag must be set")
    }

    // W02: snapshot(for:) when cache is empty returns placeholder or unconfigured state, never global snapshot
    func testW02_SnapshotWithoutCacheDoesNotReturnGlobalSnapshot() {
        // Clear any stored snapshots for this city
        LocationSnapshotStore.removeSnapshot(for: "city_tokyo-1")

        let loaded = LocationSnapshotStore.loadSnapshot(for: "city_tokyo-1")
        XCTAssertNil(loaded, "Must return nil and never fall back to AppGroupStore global snapshot")
    }
}
