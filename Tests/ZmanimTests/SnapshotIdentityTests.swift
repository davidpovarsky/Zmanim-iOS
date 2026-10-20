import CoreLocation
import XCTest
@testable import Zmanim

final class SnapshotIdentityTests: XCTestCase {

    // S07: Snapshot with same city name but different coordinates -> validator rejects
    func testS07_ValidatorRejectsSnapshotWithMismatchedCoordinates() {
        let now = Date()
        let items = [
            ZmanItem(key: "sunrise", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise", date: now.addingTimeInterval(3600))
        ]
        // Jerusalem coordinates
        let jerusalemCoords = CLLocationCoordinate2D(latitude: 31.778, longitude: 35.235)

        // Snapshot claiming to be Jerusalem but with Tel Aviv coordinates (~60km away)
        let mismatchedSnapshot = ZmanSnapshot(
            cityName: "Jerusalem",
            timeZoneID: "Asia/Jerusalem",
            latitude: 32.0853,
            longitude: 34.7818,
            updatedAt: now,
            items: items,
            sourceIdentity: .savedCity(id: "j-1")
        )

        let result = SnapshotValidator.validate(
            snapshot: mismatchedSnapshot,
            for: .savedCity(id: "j-1"),
            expectedCoordinates: jerusalemCoords,
            maxCoordinateDistanceMeters: 20_000, // 20km tolerance
            requiredDate: now
        )

        switch result {
        case .failure(let error):
            if case .coordinatesMismatch(let dist, let maxDist) = error {
                XCTAssertGreaterThan(dist, maxDist)
            } else {
                XCTFail("Expected coordinatesMismatch error, got \(error)")
            }
        case .success:
            XCTFail("Validator must reject snapshot when coordinates diverge significantly")
        }
    }

    // S08: Snapshot with matching coordinates but wrong timezone -> validator rejects
    func testS08_ValidatorRejectsSnapshotWithWrongTimeZone() {
        let now = Date()
        let items = [
            ZmanItem(key: "sunrise", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise", date: now.addingTimeInterval(3600))
        ]

        let snap = ZmanSnapshot(
            cityName: "Jerusalem",
            timeZoneID: "America/New_York", // Mismatched time zone
            latitude: 31.778,
            longitude: 35.235,
            updatedAt: now,
            items: items,
            sourceIdentity: .savedCity(id: "j-1")
        )

        let result = SnapshotValidator.validate(
            snapshot: snap,
            for: .savedCity(id: "j-1"),
            expectedTimeZoneID: "Asia/Jerusalem",
            requiredDate: now
        )

        switch result {
        case .failure(let error):
            if case .timeZoneMismatch(let expected, let actual) = error {
                XCTAssertEqual(expected, "Asia/Jerusalem")
                XCTAssertEqual(actual, "America/New_York")
            } else {
                XCTFail("Expected timeZoneMismatch error, got \(error)")
            }
        case .success:
            XCTFail("Validator must reject snapshot with wrong time zone")
        }
    }

    // S09: Old snapshot that covers today and tomorrow for correct location -> validator accepts
    func testS09_OldSnapshotCoveringTodayAndTomorrowIsAccepted() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let now = Date()
        let todayMorning = cal.date(bySettingHour: 6, minute: 0, second: 0, of: now)!
        let tomorrowMorning = cal.date(byAdding: .day, value: 1, to: todayMorning)!

        // Snapshot generated yesterday, but covering both today and tomorrow
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let items = [
            ZmanItem(key: "sunrise", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise", date: todayMorning),
            ZmanItem(key: "sunriseTom", hebrewTitle: "זריחה מחר", englishTitle: "Sunrise Tomorrow", icon: "sunrise", date: tomorrowMorning)
        ]

        let snap = ZmanSnapshot(
            cityName: "Jerusalem",
            timeZoneID: "Asia/Jerusalem",
            latitude: 31.778,
            longitude: 35.235,
            updatedAt: yesterday,
            items: items,
            sourceIdentity: .savedCity(id: "j-1")
        )

        let result = SnapshotValidator.validate(
            snapshot: snap,
            for: .savedCity(id: "j-1"),
            expectedCoordinates: CLLocationCoordinate2D(latitude: 31.778, longitude: 35.235),
            expectedTimeZoneID: "Asia/Jerusalem",
            requiredDate: now,
            requireTomorrowCoverage: true
        )

        switch result {
        case .success(let validated):
            XCTAssertEqual(validated.cityName, "Jerusalem")
            XCTAssertEqual(validated.items.count, 2)
        case .failure(let err):
            XCTFail("Validator should accept snapshot that covers today and tomorrow even if updatedAt was yesterday: \(err)")
        }
    }

    // S10: Snapshot with only yesterday's items -> validator rejects for today
    func testS10_SnapshotWithOnlyYesterdayItemsIsRejected() {
        let timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let now = Date()
        let yesterdayMorning = cal.date(byAdding: .day, value: -1, to: now)!
        let yesterdayItems = [
            ZmanItem(key: "sunrise", hebrewTitle: "זריחה", englishTitle: "Sunrise", icon: "sunrise", date: yesterdayMorning)
        ]

        let snap = ZmanSnapshot(
            cityName: "Jerusalem",
            timeZoneID: "Asia/Jerusalem",
            latitude: 31.778,
            longitude: 35.235,
            updatedAt: yesterdayMorning,
            items: yesterdayItems,
            sourceIdentity: .savedCity(id: "j-1")
        )

        let result = SnapshotValidator.validate(
            snapshot: snap,
            for: .savedCity(id: "j-1"),
            requiredDate: now
        )

        switch result {
        case .failure(let error):
            if case .insufficientCoverage = error {
                // Expected
            } else {
                XCTFail("Expected insufficientCoverage, got \(error)")
            }
        case .success:
            XCTFail("Validator must reject snapshot that only has yesterday's items")
        }
    }
}
