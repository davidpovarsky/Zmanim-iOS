import XCTest
@testable import Zmanim

final class WeatherCacheTests: XCTestCase {
    func testCacheStoresAndRetrievesValidSnapshot() async {
        let cache = WeatherCache()
        let now = Date()

        let hour = WeatherHour(
            time: now,
            temperatureCelsius: 23.0,
            symbolCode: "clearsky_day",
            iconKey: "clear-day"
        )
        let snapshot = WeatherSnapshot(
            hours: [hour],
            retrievedAt: now,
            locationLatitude: 31.778,
            locationLongitude: 35.235,
            expiresAt: now.addingTimeInterval(1800),
            lastModified: "Mon, 19 Oct 2026 12:00:00 GMT"
        )

        await cache.save(snapshot: snapshot, timeZoneID: "Asia/Jerusalem")

        let retrieved = await cache.getCached(
            latitude: 31.778,
            longitude: 35.235,
            timeZoneID: "Asia/Jerusalem",
            now: now
        )
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.hours.count, 1)
        XCTAssertEqual(retrieved?.hours.first?.temperatureCelsius, 23.0)
    }

    func testCacheInvalidatesOnExpiry() async {
        let cache = WeatherCache()
        let now = Date()

        let hour = WeatherHour(
            time: now,
            temperatureCelsius: 23.0,
            symbolCode: "clearsky_day",
            iconKey: "clear-day"
        )
        let snapshot = WeatherSnapshot(
            hours: [hour],
            retrievedAt: now,
            locationLatitude: 31.778,
            locationLongitude: 35.235,
            expiresAt: now.addingTimeInterval(60) // expires in 60s
        )

        await cache.save(snapshot: snapshot, timeZoneID: "Asia/Jerusalem")

        // Query at 70s later
        let later = now.addingTimeInterval(70)
        let expired = await cache.getCached(
            latitude: 31.778,
            longitude: 35.235,
            timeZoneID: "Asia/Jerusalem",
            now: later
        )
        XCTAssertNil(expired)
    }

    func testCacheInvalidatesOnDistantLocation() async {
        let cache = WeatherCache()
        let now = Date()

        let hour = WeatherHour(
            time: now,
            temperatureCelsius: 23.0,
            symbolCode: "clearsky_day",
            iconKey: "clear-day"
        )
        let snapshot = WeatherSnapshot(
            hours: [hour],
            retrievedAt: now,
            locationLatitude: 31.778, // Jerusalem
            locationLongitude: 35.235,
            expiresAt: now.addingTimeInterval(1800)
        )

        await cache.save(snapshot: snapshot, timeZoneID: "Asia/Jerusalem")

        // Tel Aviv coordinates (~50km away)
        let telAviv = await cache.getCached(
            latitude: 32.085,
            longitude: 34.781,
            timeZoneID: "Asia/Jerusalem",
            now: now
        )
        XCTAssertNil(telAviv)
    }

    func testRefreshExpirationExtendsExpiry() async {
        let cache = WeatherCache()
        let now = Date()

        let hour = WeatherHour(
            time: now,
            temperatureCelsius: 23.0,
            symbolCode: "clearsky_day",
            iconKey: "clear-day"
        )
        let snapshot = WeatherSnapshot(
            hours: [hour],
            retrievedAt: now,
            locationLatitude: 31.778,
            locationLongitude: 35.235,
            expiresAt: now.addingTimeInterval(30)
        )

        await cache.save(snapshot: snapshot, timeZoneID: "Asia/Jerusalem")
        let extendedExpiry = now.addingTimeInterval(3600)
        await cache.refreshExpiration(newExpiresAt: extendedExpiry)

        let queryAt60 = now.addingTimeInterval(60)
        let retrieved = await cache.getCached(
            latitude: 31.778,
            longitude: 35.235,
            timeZoneID: "Asia/Jerusalem",
            now: queryAt60
        )
        XCTAssertNotNil(retrieved)
    }
}
