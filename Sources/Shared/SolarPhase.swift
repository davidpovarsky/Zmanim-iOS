import Foundation

/// Pure representation of solar daylight phase for a specific moment and halachic sun times.
public enum SolarPhase: Equatable, Sendable {
    case beforeSunrise
    case daylight(progress: Double)
    case afterSunset
    case unavailable

    public static func resolve(now: Date, sunrise: Date?, sunset: Date?) -> SolarPhase {
        guard let sunrise, let sunset, sunset > sunrise else {
            return .unavailable
        }
        if now < sunrise {
            return .beforeSunrise
        } else if now > sunset {
            return .afterSunset
        } else {
            let elapsed = now.timeIntervalSince(sunrise)
            let total = sunset.timeIntervalSince(sunrise)
            let rawProgress = elapsed / total
            let progress = min(max(rawProgress, 0.0), 1.0)
            return .daylight(progress: progress)
        }
    }

    public var isDaylight: Bool {
        if case .daylight = self { return true }
        return false
    }

    public var progress: Double {
        if case let .daylight(p) = self { return p }
        return 0.0
    }
}
