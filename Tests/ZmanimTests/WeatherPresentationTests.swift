import XCTest
@testable import Zmanim

final class WeatherPresentationTests: XCTestCase {
    func testPresentationBuilds24HourWindowAndCalculatesHiLo() {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let tz = TimeZone(identifier: "Asia/Jerusalem")!

        let hours: [WeatherHour] = (0..<30).map { i in
            let date = now.addingTimeInterval(Double(i * 3600))
            return WeatherHour(
                time: date,
                temperatureCelsius: 15.0 + Double(i % 10), // 15 to 24
                windMetersPerSecond: 4.0,
                precipitationChancePercent: 10.0,
                cloudAreaFractionPercent: 50.0,
                symbolCode: "partlycloudy_day",
                iconKey: "partly-cloudy-day"
            )
        }

        let snapshot = WeatherSnapshot(
            hours: hours,
            retrievedAt: now,
            locationLatitude: 31.778,
            locationLongitude: 35.235,
            expiresAt: now.addingTimeInterval(1800)
        )

        let presentation = WeatherPresentation(
            snapshot: snapshot,
            cityName: "ירושלים",
            timeZone: tz,
            now: now
        )

        XCTAssertNotNil(presentation)
        guard let p = presentation else { return }

        // Hourly strip should contain exactly 24 upcoming hours
        XCTAssertEqual(p.hourly.count, 24)
        XCTAssertEqual(p.hourly.first?.timeLabel, "עכשיו")
        XCTAssertTrue(p.hourly.first?.isNow == true)
        XCTAssertFalse(p.hourly[1].isNow)

        // Feels like must strictly be nil
        XCTAssertNil(p.stats.feelsLikeText)

        // High / Low should be evaluated over the 24 hours
        XCTAssertNotNil(p.header.highLowText)
        XCTAssertTrue(p.header.highLowText?.contains("24°") == true)
        XCTAssertTrue(p.header.highLowText?.contains("15°") == true)
    }

    func testPresentationRejectsSnapshotWithNoCurrentSample() {
        let now = Date()
        let tz = TimeZone(identifier: "Asia/Jerusalem")!

        // All samples are 5+ hours in the future
        let futureHours: [WeatherHour] = (5..<15).map { i in
            WeatherHour(
                time: now.addingTimeInterval(Double(i * 3600)),
                temperatureCelsius: 20.0,
                symbolCode: "clearsky_day",
                iconKey: "clear-day"
            )
        }

        let snapshot = WeatherSnapshot(
            hours: futureHours,
            retrievedAt: now,
            locationLatitude: 31.778,
            locationLongitude: 35.235
        )

        let presentation = WeatherPresentation(
            snapshot: snapshot,
            cityName: "ירושלים",
            timeZone: tz,
            now: now
        )

        XCTAssertNil(presentation, "Snapshot with no sample around now must be rejected to prevent displaying future hour as 'now'")
    }

    func testPresentationRejectsStalePastSnapshot() {
        let now = Date()
        let tz = TimeZone(identifier: "Asia/Jerusalem")!

        // All samples are 5+ hours in the past
        let pastHours: [WeatherHour] = (-15 ..< -5).map { i in
            WeatherHour(
                time: now.addingTimeInterval(Double(i * 3600)),
                temperatureCelsius: 20.0,
                symbolCode: "clearsky_day",
                iconKey: "clear-day"
            )
        }

        let snapshot = WeatherSnapshot(
            hours: pastHours,
            retrievedAt: now.addingTimeInterval(-3600 * 5),
            locationLatitude: 31.778,
            locationLongitude: 35.235
        )

        let presentation = WeatherPresentation(
            snapshot: snapshot,
            cityName: "ירושלים",
            timeZone: tz,
            now: now
        )

        XCTAssertNil(presentation, "Snapshot where all samples are in the distant past must be rejected")
    }
}
