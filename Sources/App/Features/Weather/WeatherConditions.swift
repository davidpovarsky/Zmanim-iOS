import Foundation
import SwiftUISky

public enum WeatherCondition: String, Sendable, CaseIterable {
    case clearDay = "בהיר"
    case partlyCloudyDay = "מעונן חלקית"
    case overcastDay = "מעונן"
    case sunrise = "זריחה"
    case sunset = "שקיעה"
    case clearNight = "לילה בהיר"
    case cloudyNight = "לילה מעונן"
    case rain = "גשם"
    case snow = "שלג"
    case fog = "ערפל"
    case thunderstorm = "סופת רעמים"

    public var skyCondition: SkyWeatherCondition {
        switch self {
        case .clearDay, .clearNight, .sunrise, .sunset:
            return .clear
        case .partlyCloudyDay:
            return .partlyCloudy
        case .overcastDay, .cloudyNight:
            return .overcast
        case .rain:
            return .rain
        case .snow:
            return .snow
        case .fog:
            return .fog
        case .thunderstorm:
            return .thunderstorm
        }
    }

    public static func resolve(
        wmoCode: Int,
        isDay: Bool,
        cloudCoverPercent: Int,
        now: Date,
        sunrise: Date?,
        sunset: Date?
    ) -> WeatherCondition {
        // Severe or precipitation conditions take precedence over clear twilight transitions
        if [95, 96, 99].contains(wmoCode) {
            return .thunderstorm
        }
        if [51, 53, 55, 61, 63, 65, 80, 81, 82].contains(wmoCode) {
            return .rain
        }
        if [56, 57, 66, 67, 71, 73, 75, 77, 85, 86].contains(wmoCode) {
            return .snow
        }
        if [45, 48].contains(wmoCode) {
            return .fog
        }

        // Halachic solar transitions: 45 minutes around sunrise and sunset
        let twilightWindow: TimeInterval = 45 * 60
        if let sunrise, abs(now.timeIntervalSince(sunrise)) <= twilightWindow {
            return .sunrise
        }
        if let sunset, abs(now.timeIntervalSince(sunset)) <= twilightWindow {
            return .sunset
        }

        if isDay {
            if wmoCode == 3 || cloudCoverPercent >= 80 {
                return .overcastDay
            } else if wmoCode == 1 || wmoCode == 2 || cloudCoverPercent >= 35 {
                return .partlyCloudyDay
            } else {
                return .clearDay
            }
        } else {
            if cloudCoverPercent >= 50 || wmoCode >= 2 {
                return .cloudyNight
            } else {
                return .clearNight
            }
        }
    }
}
