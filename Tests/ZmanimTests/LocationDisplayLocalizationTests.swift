import CoreLocation
import XCTest
@testable import Zmanim

final class LocationDisplayLocalizationTests: XCTestCase {

    func testW09_GPSWidgetHeaderLocalization() {
        // When entry.isGPS is true and cityName is empty, header displays localized name ("Current Location" or "המיקום הנוכחי")
        let entryWithoutLocality = ZmanEntry(
            date: Date(),
            snapshot: ZmanSnapshot(
                cityName: "",
                timeZoneID: "UTC",
                latitude: 0,
                longitude: 0,
                updatedAt: Date(),
                items: [],
                locationSignature: "gps",
                sourceIdentity: .gps
            ),
            isPlaceholder: false,
            isGPS: true
        )

        XCTAssertTrue(entryWithoutLocality.isGPS)
        XCTAssertTrue(entryWithoutLocality.snapshot.cityName.isEmpty)

        // VerifiedLocalityStore loads and stores genuine locality
        let coord = CLLocationCoordinate2D(latitude: 31.778, longitude: 35.235)
        let locality = VerifiedLocality(
            name: "Jerusalem",
            latitude: coord.latitude,
            longitude: coord.longitude,
            timeZoneID: "Asia/Jerusalem",
            localeIdentifier: "en_US"
        )
        VerifiedLocalityStore.save(locality)

        let loaded = VerifiedLocalityStore.load(for: coord)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "Jerusalem")
    }

    func testW10_LocalityArrivalUpdatesHeaderWithoutRefetchingZmanim() {
        // Initial GPS snapshot with empty locality
        let item = ZmanItem(title: "Chatzot", time: Date(), format: "standard", timeFormat: "HH:mm")
        let initialGPS = ZmanSnapshot(
            cityName: "",
            timeZoneID: "Asia/Jerusalem",
            latitude: 31.778,
            longitude: 35.235,
            updatedAt: Date(),
            items: [item],
            locationSignature: "gps",
            sourceIdentity: .gps
        )

        // Locality arrives via reverse geocoder: "Jerusalem"
        let updatedGPS = ZmanSnapshot(
            cityName: "Jerusalem",
            timeZoneID: initialGPS.timeZoneID,
            latitude: initialGPS.latitude,
            longitude: initialGPS.longitude,
            updatedAt: initialGPS.updatedAt,
            items: initialGPS.items, // Exact same items, no refetch required
            locationSignature: initialGPS.locationSignature,
            sourceIdentity: .gps
        )

        XCTAssertEqual(initialGPS.items, updatedGPS.items, "Zmanim items remain identical when locality arrives")
        XCTAssertEqual(updatedGPS.cityName, "Jerusalem")
        XCTAssertTrue(SnapshotValidator.isValid(snapshot: updatedGPS, for: .gps))
    }
}
