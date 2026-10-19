import Combine
import CoreLocation
import Foundation
import SwiftUI
import os

@MainActor
public final class WeatherSceneModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "WeatherSceneModel")

    @Published public var isAvailable: Bool = false
    @Published public var condition: WeatherCondition? = nil
    @Published public var cloudCover: Double = 0.0
    @Published public var currentSnapshot: WeatherSnapshot? = nil
    @Published public var presentation: WeatherPresentation? = nil
    @Published public var lastUpdated: Date? = nil
    @Published public var isFetching: Bool = false
    #if DEBUG
    @Published public var previewOverride: WeatherScenePreview? = nil
    #endif

    private var currentCoordinate: CLLocationCoordinate2D?
    private var currentCityName: String = ""
    private var updateGeneration: UInt64 = 0

    public init() {
        // Starts strictly unavailable with no fabricated weather data
        self.isAvailable = false
        self.condition = nil
        self.cloudCover = 0.0
        self.currentSnapshot = nil
        self.presentation = nil
    }

    /// Updates the weather state strictly using genuine MET Norway data or cached snapshot.
    public func update(
        location: CLLocationCoordinate2D,
        cityName: String,
        timeZone: TimeZone,
        now: Date = Date(),
        sunrise: Date? = nil,
        sunset: Date? = nil,
        force: Bool = false
    ) async {
        self.updateGeneration &+= 1
        let generation = self.updateGeneration
        self.currentCoordinate = location
        self.currentCityName = cityName

        #if DEBUG
        if let preview = previewOverride {
            applyPreview(preview, cityName: cityName, timeZone: timeZone, now: now, sunrise: sunrise, sunset: sunset)
            return
        }
        #endif

        isFetching = true
        defer { isFetching = false }

        do {
            let snapshot = try await METNorwayWeatherClient.shared.fetchForecast(
                latitude: location.latitude,
                longitude: location.longitude,
                timeZone: timeZone,
                force: force
            )

            guard generation == self.updateGeneration else { return }

            guard let pres = WeatherPresentation(
                snapshot: snapshot,
                cityName: cityName,
                timeZone: timeZone,
                now: now
            ) else {
                throw METWeatherError.emptyData
            }

            let currentHour = snapshot.hours.first(where: { abs($0.time.timeIntervalSince(now)) <= 3600 })
                ?? snapshot.hours.last(where: { $0.time <= now && now.timeIntervalSince($0.time) <= 7200 })

            // Determine day/night relative to actual Halachic sunrise/sunset
            let isNight: Bool
            if let sunrise, let sunset, sunset > sunrise {
                isNight = now < sunrise || now > sunset
            } else {
                let hour = Calendar.current.component(.hour, from: now)
                isNight = hour < 6 || hour >= 19
            }

            let iconKey = currentHour?.iconKey ?? "unknown"
            var resolvedCondition = METSymbolMapper.weatherCondition(for: iconKey, isNight: isNight)

            // Severe/precipitation conditions take precedence over twilight
            let isPrecipOrSevere = ["thunderstorm", "snow", "sleet", "rain", "fog"].contains(iconKey)
            if !isPrecipOrSevere, resolvedCondition != nil {
                let twilightWindow: TimeInterval = 45 * 60
                if let sunrise, abs(now.timeIntervalSince(sunrise)) <= twilightWindow {
                    resolvedCondition = .sunrise
                } else if let sunset, abs(now.timeIntervalSince(sunset)) <= twilightWindow {
                    resolvedCondition = .sunset
                }
            }

            let clouds: Double
            if let cloudFraction = currentHour?.cloudAreaFractionPercent {
                clouds = cloudFraction / 100.0
            } else if let resolvedCondition {
                switch resolvedCondition {
                case .clearDay, .clearNight, .sunrise, .sunset:
                    clouds = 0.0
                case .partlyCloudyDay:
                    clouds = 0.4
                case .overcastDay, .cloudyNight:
                    clouds = 0.85
                case .rain, .snow, .thunderstorm:
                    clouds = 0.9
                case .fog:
                    clouds = 0.7
                }
            } else {
                clouds = 0.0
            }

            self.currentSnapshot = snapshot
            self.presentation = pres
            self.condition = resolvedCondition
            self.cloudCover = clouds
            self.lastUpdated = snapshot.retrievedAt
            self.isAvailable = true
        } catch {
            guard generation == self.updateGeneration else { return }
            Self.logger.warning("Weather fetch failed: \(error.localizedDescription, privacy: .public)")

            // Only retain an existing snapshot if it is STILL unexpired AND within 5km of the active location
            if let existing = currentSnapshot,
               let expires = existing.expiresAt, now < expires,
               CLLocation(latitude: existing.locationLatitude, longitude: existing.locationLongitude)
                   .distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude)) < 5000,
               let pres = WeatherPresentation(snapshot: existing, cityName: cityName, timeZone: timeZone, now: now) {
                self.presentation = pres
                self.isAvailable = true
            } else {
                // Expired, failed, or wrong location: strictly reset to unavailable
                self.currentSnapshot = nil
                self.presentation = nil
                self.condition = nil
                self.cloudCover = 0.0
                self.isAvailable = false
            }
        }
    }

    /// Resets the model when changing locations or cities.
    public func resetForLocationChange() {
        self.updateGeneration &+= 1
        self.currentSnapshot = nil
        self.presentation = nil
        self.condition = nil
        self.cloudCover = 0.0
        self.isAvailable = false
        Task {
            await WeatherCache.shared.clear()
        }
    }

    #if DEBUG
    public func setPreview(_ preview: WeatherScenePreview?) {
        // Strictly restricted to test harness launch arguments; never available in regular app flow
        guard ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-WeatherPreview:") }) else {
            return
        }
        self.previewOverride = preview
        if let preview {
            applyPreview(
                preview,
                cityName: currentCityName.isEmpty ? "ירושלים" : currentCityName,
                timeZone: .current,
                now: Date(),
                sunrise: nil,
                sunset: nil
            )
        } else {
            self.previewOverride = nil
            self.isAvailable = false
            self.condition = nil
            self.cloudCover = 0.0
            self.presentation = nil
        }
    }

    private func applyPreview(
        _ preview: WeatherScenePreview,
        cityName: String,
        timeZone: TimeZone,
        now: Date,
        sunrise: Date?,
        sunset: Date?
    ) {
        self.isAvailable = true
        self.condition = preview.condition
        self.cloudCover = preview.cloudCover
        self.lastUpdated = now

        let mockHours: [WeatherHour] = (0..<24).map { i in
            let hourDate = now.addingTimeInterval(Double(i * 3600))
            return WeatherHour(
                time: hourDate,
                temperatureCelsius: 18.0 + Double(i % 5),
                windMetersPerSecond: 3.5,
                precipitationChancePercent: preview == .rain ? 80.0 : (preview == .snow ? 70.0 : 0.0),
                cloudAreaFractionPercent: preview.cloudCover * 100.0,
                symbolCode: preview.symbolCode,
                iconKey: preview.iconKey
            )
        }

        let mockSnapshot = WeatherSnapshot(
            hours: mockHours,
            retrievedAt: now,
            locationLatitude: 31.778,
            locationLongitude: 35.235,
            expiresAt: now.addingTimeInterval(1800)
        )

        self.currentSnapshot = mockSnapshot
        self.presentation = WeatherPresentation(
            snapshot: mockSnapshot,
            cityName: cityName,
            timeZone: timeZone,
            now: now
        )
    }
    #endif
}

#if DEBUG
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
        case .clearMorning, .middaySun: return .clearDay
        case .partlyCloudyAfternoon: return .partlyCloudyDay
        case .overcastAfternoon: return .overcastDay
        case .goldenSunset, .twilight: return .sunset
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

    public var symbolCode: String {
        switch self {
        case .clearMorning, .middaySun: return "clearsky_day"
        case .partlyCloudyAfternoon: return "partlycloudy_day"
        case .overcastAfternoon: return "cloudy"
        case .goldenSunset, .twilight: return "fair_day"
        case .clearNight: return "clearsky_night"
        case .rain: return "rain"
        case .snow: return "snow"
        case .fog: return "fog"
        }
    }

    public var iconKey: String {
        METSymbolMapper.iconKey(from: symbolCode)
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
#endif
