//
//  MOTLocationWeatherModels.swift
//  IsraelMOT
//
//  Independent coordinate-based weather source. Transit region IDs are NOT
//  weather locations. Data: Norwegian Meteorological Institute (MET Norway).
//  Forecast data licensed CC BY 4.0; attribution appears on the weather card.
//

import Foundation

nonisolated public struct MOTLocationWeatherSnapshot: Sendable, Equatable {
    public let hours: [MOTLocationWeatherHour]
    public let retrievedAt: Date
    public let locationLatitude: Double
    public let locationLongitude: Double
    public static let attribution = "Weather data: MET Norway (CC BY 4.0)"

    public init(
        hours: [MOTLocationWeatherHour],
        retrievedAt: Date,
        locationLatitude: Double,
        locationLongitude: Double
    ) {
        self.hours = hours
        self.retrievedAt = retrievedAt
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
    }
}

nonisolated public struct MOTLocationWeatherHour: Sendable, Equatable {
    public let time: Date
    public let temperatureCelsius: Double
    public let windMetersPerSecond: Double?
    public let precipitationChancePercent: Double?
    public let iconKey: String

    public init(
        time: Date,
        temperatureCelsius: Double,
        windMetersPerSecond: Double? = nil,
        precipitationChancePercent: Double? = nil,
        iconKey: String
    ) {
        self.time = time
        self.temperatureCelsius = temperatureCelsius
        self.windMetersPerSecond = windMetersPerSecond
        self.precipitationChancePercent = precipitationChancePercent
        self.iconKey = iconKey
    }
}

nonisolated public enum MOTLocationWeatherError: Error {
    case invalidCoordinate
    case serverUnavailable
    case emptyForecast
}

public enum METLocationWeatherConverter {
    /// Convert MET Norway's symbol codes to keys already supported by WeatherFormatter.
    /// Audited rule: snow and sleet take precedence over showers/rain so snowshowers do not become rain.
    public static func iconKey(from symbol: String) -> String {
        let code = symbol.lowercased()
        let isNight = code.contains("_night")
        let suffix = isNight ? "night" : "day"

        if code.contains("sleet") {
            return "sleet"
        }
        if code.contains("snow") {
            return "snow"
        }
        if code.contains("thunder") || code.contains("rain") || code.contains("showers") {
            return "rain"
        }
        if code.contains("fog") {
            return "fog"
        }
        if code.contains("clearsky") {
            return "clear-\(suffix)"
        }
        if code.contains("partlycloudy") || code.contains("fair") {
            return "partly-cloudy-\(suffix)"
        }
        if code.contains("cloudy") {
            return "cloudy"
        }
        return "unknown"
    }
}
