import CoreLocation
import Foundation
import os

public struct CurrentWeatherReport: Sendable, Equatable {
    public let weatherCode: Int
    public let cloudCover: Int
    public let isDay: Bool
    public let precipitation: Double
    public let rain: Double
    public let snowfall: Double
    public let fetchedAt: Date

    public init(
        weatherCode: Int,
        cloudCover: Int,
        isDay: Bool,
        precipitation: Double = 0.0,
        rain: Double = 0.0,
        snowfall: Double = 0.0,
        fetchedAt: Date = Date()
    ) {
        self.weatherCode = weatherCode
        self.cloudCover = cloudCover
        self.isDay = isDay
        self.precipitation = precipitation
        self.rain = rain
        self.snowfall = snowfall
        self.fetchedAt = fetchedAt
    }
}

public actor WeatherService {
    public static let shared = WeatherService()
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "WeatherService")

    private struct CacheEntry {
        let coordinate: CLLocationCoordinate2D
        let report: CurrentWeatherReport
        let expiresAt: Date
    }

    private var cache: CacheEntry?
    private let cacheDuration: TimeInterval = 30 * 60 // 30 minutes
    private let session: URLSession

    public init(session: URLSession = .shared) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        self.session = URLSession(configuration: config)
    }

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let weather_code: Int?
            let cloud_cover: Int?
            let is_day: Int?
            let precipitation: Double?
            let rain: Double?
            let snowfall: Double?
        }
        let current: Current?
    }

    public func fetchWeather(for coordinate: CLLocationCoordinate2D, force: Bool = false) async -> CurrentWeatherReport {
        let now = Date()

        // Check cache validity (coordinate within ~5km and unexpired)
        if !force, let cached = cache, cached.expiresAt > now {
            let cachedLoc = CLLocation(latitude: cached.coordinate.latitude, longitude: cached.coordinate.longitude)
            let currentLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if cachedLoc.distance(from: currentLoc) < 5000 {
                return cached.report
            }
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.open-meteo.com"
        components.path = "/v1/forecast"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", coordinate.longitude)),
            URLQueryItem(name: "current", value: "weather_code,cloud_cover,is_day,precipitation,rain,snowfall"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components.url else {
            return fallbackReport(for: coordinate)
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                Self.logger.warning("Open-Meteo non-200 HTTP response")
                return cache?.report ?? fallbackReport(for: coordinate)
            }

            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            guard let current = decoded.current else {
                return cache?.report ?? fallbackReport(for: coordinate)
            }

            let report = CurrentWeatherReport(
                weatherCode: current.weather_code ?? 0,
                cloudCover: current.cloud_cover ?? 20,
                isDay: (current.is_day ?? 1) == 1,
                precipitation: current.precipitation ?? 0.0,
                rain: current.rain ?? 0.0,
                snowfall: current.snowfall ?? 0.0,
                fetchedAt: now
            )

            cache = CacheEntry(
                coordinate: coordinate,
                report: report,
                expiresAt: now.addingTimeInterval(cacheDuration)
            )

            #if DEBUG
            Self.logger.notice("Weather fetched successfully: code=\(report.weatherCode) clouds=\(report.cloudCover)% isDay=\(report.isDay)")
            #endif

            return report
        } catch {
            Self.logger.warning("Weather fetch error: \(error.localizedDescription, privacy: .public). Using fallback.")
            return cache?.report ?? fallbackReport(for: coordinate)
        }
    }

    private func fallbackReport(for coordinate: CLLocationCoordinate2D) -> CurrentWeatherReport {
        let hour = Calendar.current.component(.hour, from: Date())
        let isDay = hour >= 6 && hour < 19
        return CurrentWeatherReport(
            weatherCode: 1,
            cloudCover: 25,
            isDay: isDay,
            fetchedAt: Date()
        )
    }
}
