import Foundation
import CoreLocation
import OneBusAwayWeatherCore
import os

public enum METWeatherError: LocalizedError, Equatable {
    case invalidCoordinates
    case invalidURL
    case serverError(Int)
    case emptyData
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCoordinates:
            return "קואורדינטות מיקום שגויות."
        case .invalidURL:
            return "לא ניתן ליצור כתובת לבקשת מזג האוויר."
        case .serverError(let code):
            return "שירות מזג האוויר החזיר שגיאה \(code)."
        case .emptyData:
            return "לא התקבלו נתוני תחזית משירות מזג האוויר."
        case .decodingFailed(let reason):
            return "פענוח נתוני מזג האוויר נכשל: \(reason)"
        }
    }
}

public actor METNorwayWeatherClient {
    public static let shared = METNorwayWeatherClient()
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "METNorwayWeatherClient")

    private let session: URLSession
    private let cache: WeatherCache

    public init(
        session: URLSession? = nil,
        cache: WeatherCache = .shared
    ) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10
            config.timeoutIntervalForResource = 15
            self.session = URLSession(configuration: config)
        }
        self.cache = cache
    }

    /// Fetches a genuine location forecast for GPS or fixed-city coordinates via MET Norway.
    /// Strictly no fake fallback data: throws on network or server error.
    public func fetchForecast(
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        force: Bool = false
    ) async throws -> WeatherSnapshot {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw METWeatherError.invalidCoordinates
        }

        let now = Date()

        // 1. Check valid unexpired cache
        if !force, let cached = await cache.getCached(
            latitude: latitude,
            longitude: longitude,
            timeZoneID: timeZone.identifier,
            now: now
        ) {
            return cached
        }

        // 2. Build URL with at most 4 decimals of precision per MET Norway guidelines
        var components = URLComponents(string: "https://api.met.no/weatherapi/locationforecast/2.0/compact")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.4f", longitude))
        ]

        guard let url = components?.url else {
            throw METWeatherError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Project-specific real User-Agent per ToS
        request.setValue(
            "Zmanim-iOS/1.0 (https://github.com/davidpovarsky/Zmanim-iOS; contact: https://github.com/davidpovarsky/Zmanim-iOS/issues)",
            forHTTPHeaderField: "User-Agent"
        )

        // Conditional HTTP header
        if !force, let lastModified = await cache.getLastModified(latitude: latitude, longitude: longitude) {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw METWeatherError.emptyData
        }

        // Handle 304 Not Modified
        if http.statusCode == 304 {
            let expiresAt = Self.parseExpiresDate(from: http)
            await cache.refreshExpiration(newExpiresAt: expiresAt)
            if let cached = await cache.getCached(
                latitude: latitude,
                longitude: longitude,
                timeZoneID: timeZone.identifier,
                now: now
            ) {
                return cached
            }
        }

        guard http.statusCode == 200 else {
            Self.logger.warning("MET Norway non-200 status: \(http.statusCode)")
            throw METWeatherError.serverError(http.statusCode)
        }

        let expiresAt = Self.parseExpiresDate(from: http)
        let lastModified = http.value(forHTTPHeaderField: "Last-Modified")

        let snapshot = try Self.decodeForecast(
            data: data,
            latitude: latitude,
            longitude: longitude,
            expiresAt: expiresAt,
            lastModified: lastModified
        )

        await cache.save(snapshot: snapshot, timeZoneID: timeZone.identifier)
        return snapshot
    }

    /// Pure function for decoding MET Norway Locationforecast 2.0 JSON.
    public nonisolated static func decodeForecast(
        data: Data,
        latitude: Double,
        longitude: Double,
        expiresAt: Date? = nil,
        lastModified: String? = nil
    ) throws -> WeatherSnapshot {
        let dto: METLocationForecastDTO
        do {
            dto = try JSONDecoder().decode(METLocationForecastDTO.self, from: data)
        } catch {
            throw METWeatherError.decodingFailed(error.localizedDescription)
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let hours: [WeatherHour] = dto.properties.timeseries.compactMap { entry in
            guard let date = isoFormatter.date(from: entry.time)
                ?? fractionalFormatter.date(from: entry.time) else { return nil }

            let symbolCode = entry.data.next1Hours?.summary?.symbolCode
                ?? entry.data.next6Hours?.summary?.symbolCode
                ?? entry.data.next12Hours?.summary?.symbolCode
                ?? "unknown"

            let precip = entry.data.next1Hours?.details?.probabilityOfPrecipitation
                ?? entry.data.next6Hours?.details?.probabilityOfPrecipitation

            let iconKey = METLocationWeatherConverter.iconKey(from: symbolCode)

            return WeatherHour(
                time: date,
                temperatureCelsius: entry.data.instant.details.airTemperature,
                windMetersPerSecond: entry.data.instant.details.windSpeed,
                precipitationChancePercent: precip,
                cloudAreaFractionPercent: entry.data.instant.details.cloudAreaFraction,
                symbolCode: symbolCode,
                iconKey: iconKey
            )
        }

        guard !hours.isEmpty else {
            throw METWeatherError.emptyData
        }

        let sortedHours = hours.sorted { $0.time < $1.time }

        return WeatherSnapshot(
            hours: sortedHours,
            retrievedAt: Date(),
            locationLatitude: latitude,
            locationLongitude: longitude,
            expiresAt: expiresAt ?? Date().addingTimeInterval(1800),
            lastModified: lastModified
        )
    }

    private nonisolated static func parseExpiresDate(from response: HTTPURLResponse) -> Date? {
        guard let expiresString = response.value(forHTTPHeaderField: "Expires") else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: expiresString)
    }
}
