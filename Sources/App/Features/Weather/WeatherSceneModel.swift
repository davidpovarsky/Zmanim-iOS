import Combine
import CoreLocation
import Foundation
import SwiftUI

@MainActor
final class WeatherSceneModel: ObservableObject {
    @Published var condition: WeatherCondition = .clearDay
    @Published var cloudCover: Double = 0.20
    @Published var isDay: Bool = true
    @Published var lastUpdated: Date?
    @Published var previewOverride: WeatherScenePreview?

    private var currentLocation: CLLocationCoordinate2D?
    private var lastFetchTime: Date?

    init() {}

    public func update(
        location: CLLocationCoordinate2D,
        now: Date,
        sunrise: Date?,
        sunset: Date?,
        force: Bool = false
    ) async {
        if let preview = previewOverride {
            applyPreview(preview, now: now, sunrise: sunrise, sunset: sunset)
            return
        }

        currentLocation = location
        let report = await WeatherService.shared.fetchWeather(for: location, force: force)

        let resolved = WeatherCondition.resolve(
            wmoCode: report.weatherCode,
            isDay: report.isDay,
            cloudCoverPercent: report.cloudCover,
            now: now,
            sunrise: sunrise,
            sunset: sunset
        )

        self.condition = resolved
        self.cloudCover = Double(report.cloudCover) / 100.0
        self.isDay = report.isDay
        self.lastUpdated = report.fetchedAt
    }

    public func setPreview(_ preview: WeatherScenePreview?) {
        self.previewOverride = preview
    }

    private func applyPreview(
        _ preview: WeatherScenePreview,
        now: Date,
        sunrise: Date?,
        sunset: Date?
    ) {
        self.condition = preview.condition
        self.cloudCover = preview.cloudCover
        self.isDay = preview.isDay
        self.lastUpdated = now
    }
}

public enum WeatherScenePreview: String, CaseIterable, Identifiable {
    case clearMorning = "בוקר בהיר"
    case middaySun = "צהריים שטופי שמש"
    case partlyCloudyAfternoon = "אחר הצהריים מעונן חלקית"
    case overcastAfternoon = "אחר הצהריים מעונן"
    case goldenSunset = "שקיעה זהובה"
    case twilight = "דמדומים"
    case clearNight = "לילה בהיר זרוע כוכבים"
    case rain = "גשם"
    case snow = "שלג"
    case fog = "ערפל"

    public var id: String { rawValue }

    public var condition: WeatherCondition {
        switch self {
        case .clearMorning: return .clearDay
        case .middaySun: return .clearDay
        case .partlyCloudyAfternoon: return .partlyCloudyDay
        case .overcastAfternoon: return .overcastDay
        case .goldenSunset: return .sunset
        case .twilight: return .sunset
        case .clearNight: return .clearNight
        case .rain: return .rain
        case .snow: return .snow
        case .fog: return .fog
        }
    }

    public var cloudCover: Double {
        switch self {
        case .clearMorning, .middaySun, .clearNight: return 0.05
        case .partlyCloudyAfternoon: return 0.40
        case .overcastAfternoon: return 0.95
        case .goldenSunset, .twilight: return 0.15
        case .rain: return 0.85
        case .snow: return 0.70
        case .fog: return 0.60
        }
    }

    public var isDay: Bool {
        switch self {
        case .clearNight: return false
        default: return true
        }
    }

    public func simulatedDate(for baseDate: Date, sunrise: Date?, sunset: Date?) -> Date {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: baseDate)
        switch self {
        case .clearMorning:
            comps.hour = 8; comps.minute = 30
        case .middaySun:
            comps.hour = 12; comps.minute = 30
        case .partlyCloudyAfternoon:
            comps.hour = 15; comps.minute = 0
        case .overcastAfternoon:
            comps.hour = 16; comps.minute = 30
        case .goldenSunset:
            if let sunset { return sunset.addingTimeInterval(-10 * 60) }
            comps.hour = 18; comps.minute = 15
        case .twilight:
            if let sunset { return sunset.addingTimeInterval(20 * 60) }
            comps.hour = 18; comps.minute = 45
        case .clearNight:
            comps.hour = 23; comps.minute = 30
        case .rain:
            comps.hour = 14; comps.minute = 0
        case .snow:
            comps.hour = 10; comps.minute = 0
        case .fog:
            comps.hour = 7; comps.minute = 0
        }
        return calendar.date(from: comps) ?? baseDate
    }
}
