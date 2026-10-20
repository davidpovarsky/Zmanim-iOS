import Combine
import CoreLocation
import Foundation
import OneBusAwayWeatherCore
import OneBusAwayWeatherUI
import SwiftUI
import os

@MainActor
public final class WeatherSceneModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "WeatherSceneModel")

    @Published public var isAvailable: Bool = false
    @Published public var condition: WeatherCondition? = nil
    @Published public var cloudCover: Double? = nil
    @Published public var currentSnapshot: WeatherSnapshot? = nil
    @Published public var weatherDisplay: WeatherDisplay? = nil
    @Published public var lastUpdated: Date? = nil
    @Published public var isFetching: Bool = false
    #if DEBUG
    @Published public var previewOverride: WeatherScenePreview? = nil
    #endif

    public var effectiveCloudCover: Double {
        cloudCover ?? 0.0
    }

    private var currentCoordinate: CLLocationCoordinate2D?
    private var currentCityName: String = ""
    private var updateGeneration: UInt64 = 0

    public init() {
        // Starts strictly unavailable with no fabricated weather data
        self.isAvailable = false
        self.condition = nil
        self.cloudCover = nil
        self.currentSnapshot = nil
        self.weatherDisplay = nil
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
        defer {
            if generation == self.updateGeneration {
                isFetching = false
            }
        }

        do {
            let snapshot = try await METNorwayWeatherClient.shared.fetchForecast(
                latitude: location.latitude,
                longitude: location.longitude,
                timeZone: timeZone,
                force: force
            )

            guard generation == self.updateGeneration else { return }

            guard let display = ZmanimWeatherDisplayAdapter.makeWeatherDisplay(
                from: snapshot,
                cityName: cityName,
                timeZone: timeZone,
                now: now
            ) else {
                throw METWeatherError.emptyData
            }

            let currentHour = snapshot.hours.first(where: { abs($0.time.timeIntervalSince(now)) <= 3600 })
                ?? snapshot.hours.last(where: { $0.time <= now && now.timeIntervalSince($0.time) <= 7200 })

            // Determine day/night relative to actual Halachic sunrise/sunset or MET symbol
            let rawSymbol = currentHour?.symbolCode ?? "unknown"
            let isNight: Bool
            if let sunrise, let sunset, sunset > sunrise {
                isNight = now < sunrise || now > sunset
            } else if rawSymbol.hasSuffix("_night") {
                isNight = true
            } else if rawSymbol.hasSuffix("_day") {
                isNight = false
            } else {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = timeZone
                let hour = cal.component(.hour, from: now)
                isNight = hour < 6 || hour >= 19
            }

            let iconKey = METLocationWeatherConverter.iconKey(from: rawSymbol)
            let resolvedCondition = ZmanimWeatherDisplayAdapter.resolveSkyCondition(
                iconKey: iconKey,
                isNight: isNight,
                sunrise: sunrise,
                sunset: sunset,
                now: now
            )

            // Strictly authentic cloud fraction; never fabricate estimated measurements
            let clouds: Double?
            if let cloudFraction = currentHour?.cloudAreaFractionPercent {
                clouds = cloudFraction / 100.0
            } else {
                clouds = nil
            }

            self.currentSnapshot = snapshot
            self.weatherDisplay = display
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
               let display = ZmanimWeatherDisplayAdapter.makeWeatherDisplay(
                   from: existing,
                   cityName: cityName,
                   timeZone: timeZone,
                   now: now
               ) {
                self.weatherDisplay = display
                self.isAvailable = true
            } else {
                // Expired, failed, or wrong location: strictly reset to unavailable
                self.currentSnapshot = nil
                self.weatherDisplay = nil
                self.condition = nil
                self.cloudCover = nil
                self.isAvailable = false
            }
        }
    }

    /// Resets the model when changing locations or cities.
    public func resetForLocationChange() {
        self.updateGeneration &+= 1
        self.currentSnapshot = nil
        self.weatherDisplay = nil
        self.condition = nil
        self.cloudCover = nil
        self.isAvailable = false
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
            self.weatherDisplay = nil
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

        let mockHours: [WeatherHour] = (0..<25).map { i in
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
        self.weatherDisplay = ZmanimWeatherDisplayAdapter.makeWeatherDisplay(
            from: mockSnapshot,
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
        case .goldenSunset: return .sunset
        case .twilight: return .sunrise
        case .clearNight: return .clearNight
        case .rain: return .rain
        case .snow: return .snow
        case .fog: return .fog
        }
    }

    public var cloudCover: Double {
        switch self {
        case .clearMorning, .middaySun, .clearNight: return 0.0
        case .partlyCloudyAfternoon: return 0.45
        case .overcastAfternoon: return 0.85
        case .goldenSunset, .twilight: return 0.15
        case .rain: return 0.90
        case .snow: return 0.80
        case .fog: return 0.70
        }
    }

    public var symbolCode: String {
        switch self {
        case .clearMorning, .middaySun: return "clearsky_day"
        case .partlyCloudyAfternoon: return "partlycloudy_day"
        case .overcastAfternoon: return "cloudy"
        case .goldenSunset, .twilight: return "clearsky_day"
        case .clearNight: return "clearsky_night"
        case .rain: return "rain"
        case .snow: return "snow"
        case .fog: return "fog"
        }
    }

    public var iconKey: String {
        switch self {
        case .clearMorning, .middaySun, .goldenSunset, .twilight: return "clear-day"
        case .partlyCloudyAfternoon: return "partly-cloudy-day"
        case .overcastAfternoon: return "cloudy"
        case .clearNight: return "clear-night"
        case .rain: return "rain"
        case .snow: return "snow"
        case .fog: return "fog"
        }
    }
}
#endif
