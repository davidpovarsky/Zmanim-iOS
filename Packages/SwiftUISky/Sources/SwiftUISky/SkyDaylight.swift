import Foundation

/// Northern-hemisphere meteorological season.
public enum SkySeason: CaseIterable, Sendable {
    case spring
    case summer
    case autumn
    case winter

    public init(month: Int) {
        switch month {
        case 3 ... 5:
            self = .spring
        case 6 ... 8:
            self = .summer
        case 9 ... 11:
            self = .autumn
        default:
            self = .winter
        }
    }

    public var cloudCoverage: Double {
        switch self {
        case .spring: 1.0
        case .summer: 0.75
        case .autumn: 0.9
        case .winter: 1.1
        }
    }

    public var cloudScale: Double {
        switch self {
        case .spring: 0.92
        case .summer: 1.15
        case .autumn: 1.0
        case .winter: 0.82
        }
    }

    public var wispCount: Int {
        switch self {
        case .spring: 4
        case .summer: 3
        case .autumn: 7
        case .winter: 5
        }
    }

    public var tint: SkyRGB {
        switch self {
        case .spring: SkyRGB(red: 0.72, green: 0.87, blue: 0.90)
        case .summer: SkyRGB(red: 0.40, green: 0.60, blue: 0.96)
        case .autumn: SkyRGB(red: 0.96, green: 0.80, blue: 0.62)
        case .winter: SkyRGB(red: 0.80, green: 0.84, blue: 0.90)
        }
    }

    public var tintStrength: Double {
        switch self {
        case .spring: 0.16
        case .summer: 0.14
        case .autumn: 0.16
        case .winter: 0.22
        }
    }

    public var twilightWarmth: Double {
        switch self {
        case .spring: 0.9
        case .summer: 1.05
        case .autumn: 1.2
        case .winter: 0.7
        }
    }
}

/// Daylight status driven by actual Halachic sunrise and sunset when available,
/// or an astronomical approximation as fallback.
public struct SkyDaylight: Equatable, Sendable {
    public let hour: Double
    public let season: SkySeason
    public let sunrise: Double
    public let sunset: Double
    public let daylight: Double
    public let twilight: Double
    public let sunProgress: Double?
    public let isEvening: Bool

    public static let twilightHalfWindow = 0.9

    public init(
        date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        actualSunrise: Date? = nil,
        actualSunset: Date? = nil
    ) {
        let components = calendar.dateComponents([.month, .hour, .minute, .second], from: date)
        let hour = Double(components.hour ?? 12)
            + Double(components.minute ?? 0) / 60
            + Double(components.second ?? 0) / 3600

        let sunriseHour: Double
        let sunsetHour: Double

        if let actualSunrise, let actualSunset, actualSunset > actualSunrise {
            let riseComp = calendar.dateComponents([.hour, .minute, .second], from: actualSunrise)
            let setComp = calendar.dateComponents([.hour, .minute, .second], from: actualSunset)
            sunriseHour = Double(riseComp.hour ?? 6) + Double(riseComp.minute ?? 0) / 60 + Double(riseComp.second ?? 0) / 3600
            sunsetHour = Double(setComp.hour ?? 18) + Double(setComp.minute ?? 0) / 60 + Double(setComp.second ?? 0) / 3600
        } else {
            let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 172)
            let daylightHours = 12 + 2.6 * cos(2 * .pi * (dayOfYear - 172) / 365.25)
            sunriseHour = 12.2 - daylightHours / 2
            sunsetHour = 12.2 + daylightHours / 2
        }

        let window = Self.twilightHalfWindow
        let rising = SkyMath.smoothstep(sunriseHour - window, sunriseHour + window, hour)
        let setting = 1 - SkyMath.smoothstep(sunsetHour - window, sunsetHour + window, hour)
        let daylight = rising * setting

        self.hour = hour
        self.season = SkySeason(month: components.month ?? 1)
        self.sunrise = sunriseHour
        self.sunset = sunsetHour
        self.daylight = daylight
        self.twilight = 1 - abs(2 * daylight - 1)
        self.isEvening = hour >= ((sunriseHour + sunsetHour) / 2)

        if hour > sunriseHour - window, hour < sunsetHour + window {
            self.sunProgress = SkyMath.clamp((hour - sunriseHour) / max(0.1, (sunsetHour - sunriseHour)), 0, 1)
        } else {
            self.sunProgress = nil
        }
    }

    public var nightWeight: Double { 1 - daylight }
}
