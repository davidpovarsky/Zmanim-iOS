import XCTest
@testable import Zmanim

final class METForecastDTOTests: XCTestCase {
    func testDecodeCompactForecastJSON() throws {
        let sampleJSON = """
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [35.235, 31.778, 750]
          },
          "properties": {
            "meta": {
              "updated_at": "2026-10-19T17:00:00Z",
              "units": {
                "air_temperature": "celsius"
              }
            },
            "timeseries": [
              {
                "time": "2026-10-19T18:00:00Z",
                "data": {
                  "instant": {
                    "details": {
                      "air_temperature": 21.4,
                      "cloud_area_fraction": 45.0,
                      "wind_speed": 4.2
                    }
                  },
                  "next_1_hours": {
                    "summary": {
                      "symbol_code": "partlycloudy_night"
                    },
                    "details": {
                      "probability_of_precipitation": 15.0
                    }
                  }
                }
              },
              {
                "time": "2026-10-19T19:00:00Z",
                "data": {
                  "instant": {
                    "details": {
                      "air_temperature": 20.1
                    }
                  },
                  "next_6_hours": {
                    "summary": {
                      "symbol_code": "clearsky_night"
                    }
                  }
                }
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let snapshot = try METNorwayWeatherClient.decodeForecast(
            data: sampleJSON,
            latitude: 31.778,
            longitude: 35.235,
            expiresAt: Date(timeIntervalSince1970: 2000000000),
            lastModified: "Mon, 19 Oct 2026 17:00:00 GMT"
        )

        XCTAssertEqual(snapshot.hours.count, 2)

        let first = snapshot.hours[0]
        XCTAssertEqual(first.temperatureCelsius, 21.4)
        XCTAssertEqual(first.windMetersPerSecond, 4.2)
        XCTAssertEqual(first.cloudAreaFractionPercent, 45.0)
        XCTAssertEqual(first.precipitationChancePercent, 15.0)
        XCTAssertEqual(first.symbolCode, "partlycloudy_night")
        XCTAssertEqual(first.iconKey, "partly-cloudy-night")

        let second = snapshot.hours[1]
        XCTAssertEqual(second.temperatureCelsius, 20.1)
        XCTAssertNil(second.windMetersPerSecond)
        XCTAssertNil(second.cloudAreaFractionPercent)
        XCTAssertNil(second.precipitationChancePercent)
        XCTAssertEqual(second.symbolCode, "clearsky_night")
        XCTAssertEqual(second.iconKey, "clear-night")
    }

    func testDecodingThrowsOnEmptyTimeseries() {
        let emptyJSON = """
        {
          "properties": {
            "timeseries": []
          }
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(
            try METNorwayWeatherClient.decodeForecast(
                data: emptyJSON,
                latitude: 31.778,
                longitude: 35.235
            )
        )
    }
}
