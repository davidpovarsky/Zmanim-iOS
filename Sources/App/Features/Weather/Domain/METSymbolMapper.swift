import Foundation

public enum METSymbolMapper {
    /// Maps a MET Norway symbol code to a normalized icon key.
    /// Crucially guarantees that snow and sleet conditions (e.g. `snowshowers_day`)
    /// are evaluated before generic `showers` or `rain`, preventing misclassification.
    public static func iconKey(from symbol: String) -> String {
        let code = symbol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !code.isEmpty, code != "unknown" else { return "unknown" }
        let isNight = code.contains("_night")
        let suffix = isNight ? "night" : "day"

        if code.contains("thunder") {
            return "thunderstorm"
        }
        // Check snow and sleet strictly BEFORE showers/rain
        if code.contains("snow") {
            return "snow"
        }
        if code.contains("sleet") {
            return "sleet"
        }
        if code.contains("rain") || code.contains("drizzle") || code.contains("showers") {
            return "rain"
        }
        if code.contains("fog") {
            return "fog"
        }
        if code.contains("cloudy") && !code.contains("partly") {
            return "cloudy"
        }
        if code.contains("partlycloudy") || code.contains("fair") {
            return "partly-cloudy-\(suffix)"
        }
        if code.contains("clearsky") || code.contains("clear") {
            return "clear-\(suffix)"
        }
        return "unknown"
    }

    /// Hebrew condition summary text for display.
    public static func conditionText(for symbol: String) -> String {
        let code = symbol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !code.isEmpty, code != "unknown" else { return "—" }
        let isNight = code.contains("_night")

        if code.contains("thunder") {
            return "סופת רעמים"
        }
        if code.contains("snow") {
            return code.contains("shower") ? "ממטרי שלג" : "שלג"
        }
        if code.contains("sleet") {
            return "משקעי קרח"
        }
        if code.contains("rain") || code.contains("drizzle") || code.contains("showers") {
            return code.contains("shower") ? "ממטרים" : "גשם"
        }
        if code.contains("fog") {
            return "ערפל"
        }
        if code.contains("cloudy") && !code.contains("partly") {
            return "מעונן"
        }
        if code.contains("partlycloudy") || code.contains("fair") {
            return "מעונן חלקית"
        }
        if code.contains("clearsky") || code.contains("clear") {
            return isNight ? "לילה בהיר" : "בהיר"
        }
        return "—"
    }

    /// SF Symbol icon name for a given normalized icon key.
    public static func systemImageName(for iconKey: String) -> String {
        switch iconKey {
        case "clear-day": return "sun.max.fill"
        case "clear-night": return "moon.stars.fill"
        case "partly-cloudy-day": return "cloud.sun.fill"
        case "partly-cloudy-night": return "cloud.moon.fill"
        case "cloudy": return "cloud.fill"
        case "rain": return "cloud.rain.fill"
        case "sleet": return "cloud.sleet.fill"
        case "snow": return "cloud.snow.fill"
        case "fog": return "cloud.fog.fill"
        case "thunderstorm": return "cloud.bolt.rain.fill"
        case "wind": return "wind"
        default: return "cloud.sun.fill"
        }
    }

    /// Maps an icon key and night state to the corresponding WeatherCondition for SwiftUISky.
    public static func weatherCondition(for iconKey: String, isNight: Bool) -> WeatherCondition? {
        switch iconKey {
        case "thunderstorm":
            return .thunderstorm
        case "snow":
            return .snow
        case "sleet":
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
