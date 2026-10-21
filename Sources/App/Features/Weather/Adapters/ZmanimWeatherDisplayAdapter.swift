import Foundation
import OneBusAwayWeatherCore
import OneBusAwayWeatherUI

public enum ZmanimWeatherDisplayAdapter {
    /// Adapts the internal `WeatherSnapshot` to `MOTLocationWeatherSnapshot` from `OneBusAwayWeatherCore`.
    public static func makeMOTSnapshot(from snapshot: WeatherSnapshot) -> MOTLocationWeatherSnapshot {
        let hours: [MOTLocationWeatherHour] = snapshot.hours.map { hour in
            let iconKey = METLocationWeatherConverter.iconKey(from: hour.symbolCode)
            return MOTLocationWeatherHour(
                time: hour.time,
                temperatureCelsius: hour.temperatureCelsius,
                windMetersPerSecond: hour.windMetersPerSecond,
                precipitationChancePercent: hour.precipitationChancePercent,
                iconKey: iconKey
            )
        }

        return MOTLocationWeatherSnapshot(
            hours: hours,
            retrievedAt: snapshot.retrievedAt,
            locationLatitude: snapshot.locationLatitude,
            locationLongitude: snapshot.locationLongitude
        )
    }

    /// Constructs the authoritative `WeatherDisplay` from `OneBusAwayWeatherUI`.
    public static func makeWeatherDisplay(
        from snapshot: WeatherSnapshot,
        cityName: String,
        timeZone: TimeZone,
        locale: Locale = .autoupdatingCurrent,
        now: Date = Date(),
        language: String? = nil
    ) -> WeatherDisplay? {
        let motSnapshot = makeMOTSnapshot(from: snapshot)
        return WeatherDisplay(
            locationForecast: motSnapshot,
            locationName: cityName,
            locale: locale,
            timeZone: timeZone,
            now: now,
            language: language
        )
    }

    /// Maps the current forecast icon key and solar transitions to `WeatherCondition` for SwiftUISky backgrounds.
    public static func resolveSkyCondition(
        iconKey: String,
        isNight: Bool,
        sunrise: Date?,
        sunset: Date?,
        now: Date
    ) -> WeatherCondition? {
        let severe = ["thunderstorm", "snow", "sleet", "rain", "fog"]
        if !severe.contains(iconKey) {
            let twilightWindow: TimeInterval = 45 * 60
            if let sunrise, abs(now.timeIntervalSince(sunrise)) <= twilightWindow {
                return .sunrise
            } else if let sunset, abs(now.timeIntervalSince(sunset)) <= twilightWindow {
                return .sunset
            }
        }

        switch iconKey {
        case "thunderstorm":
            return .thunderstorm
        case "snow", "sleet":
            return .snow
        case "rain":
            return .rain
        case "fog":
            return .fog
        case "cloudy":
            return isNight ? .cloudyNight : .overcastDay
        case "partly-cloudy-night":
            return .cloudyNight
        case "partly-cloudy-day":
            return .partlyCloudyDay
        case "clear-night":
            return .clearNight
        case "clear-day":
            return .clearDay
        default:
            return nil
        }
    }
}
