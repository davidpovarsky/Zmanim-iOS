import XCTest
@testable import Zmanim

private final class URLProtocolMock: URLProtocol {
    static var mockHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.mockHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class METNorwayWeatherClientTests: XCTestCase {
    private var mockSession: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]
        mockSession = URLSession(configuration: config)
    }

    override func tearDown() {
        URLProtocolMock.mockHandler = nil
        mockSession = nil
        super.tearDown()
    }

    func testInvalidCoordinatesThrows() async {
        let client = METNorwayWeatherClient(session: mockSession)
        do {
            _ = try await client.fetchForecast(latitude: 95.0, longitude: 35.0, timeZone: .current)
            XCTFail("Should throw for latitude > 90")
        } catch let error as METWeatherError {
            XCTAssertEqual(error, .invalidCoordinates)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSuccessful200Response() async throws {
        let sampleJSON = """
        {
            "type": "Feature",
            "geometry": { "type": "Point", "coordinates": [35.21, 31.76] },
            "properties": {
                "meta": { "updated_at": "2026-10-20T10:00:00Z", "units": {} },
                "timeseries": [
                    {
                        "time": "2026-10-20T10:00:00Z",
                        "data": {
                            "instant": {
                                "details": {
                                    "air_temperature": 23.5,
                                    "relative_humidity": 45.0,
                                    "wind_speed": 3.2,
                                    "cloud_area_fraction": 15.0
                                }
                            },
                            "next_1_hours": {
                                "summary": { "symbol_code": "clearsky_day" }
                            }
                        }
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        URLProtocolMock.mockHandler = { request in
            let url = request.url!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json", "Expires": "Tue, 20 Oct 2026 11:00:00 GMT"]
            )!
            return (response, sampleJSON)
        }

        let client = METNorwayWeatherClient(session: mockSession)
        let snapshot = try await client.fetchForecast(
            latitude: 31.76,
            longitude: 35.21,
            timeZone: TimeZone(identifier: "Asia/Jerusalem")!,
            force: true
        )

        XCTAssertEqual(snapshot.hours.count, 1)
        XCTAssertEqual(snapshot.hours.first?.temperatureCelsius, 23.5)
        XCTAssertEqual(snapshot.hours.first?.symbolCode, "clearsky_day")
        XCTAssertEqual(snapshot.hours.first?.cloudAreaFractionPercent, 15.0)
    }

    func testServerError500Throws() async {
        URLProtocolMock.mockHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, Data())
        }

        let client = METNorwayWeatherClient(session: mockSession)
        do {
            _ = try await client.fetchForecast(latitude: 31.76, longitude: 35.21, timeZone: .current, force: true)
            XCTFail("Should throw server error for 500")
        } catch let error as METWeatherError {
            XCTAssertEqual(error, .serverError(500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
