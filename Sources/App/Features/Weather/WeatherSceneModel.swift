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
    @Published public var cloudCover: Double = 0.0
    @Published public var currentSnapshot: WeatherSnapshot? = nil
    @Published public var weatherDisplay: WeatherDisplay? = nil
    @Published public var lastUpdated: Date? = nil
    @Published public var isFetching: Bool = false
    #if DEBUG
    @Published public var previewOverride: WeatherScenePreview? = nil
    #endif

    public var effectiveCloudCover: Double {
        cloudCover
    }

    private var currentCoordinate: CLLocationCoordinate2D?
    private var currentCityName: String = ""
    public private(set) var currentSnapshotTimeZone: TimeZone? = nil
    private var updateGeneration: UInt64 = 0

    public init() {
        // Starts strictly unavailable with no fabricated weather data
        self.isAvailable = false
        self.condition = nil
        self.cloudCover = 0.0
        self.currentSnapshot = nil
        self.weatherDisplay = nil
        self.currentSnapshotTimeZone = nil
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
        self.currentSnapshotTimeZone = timeZone

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
            let clouds: Double = (currentHour?.cloudAreaFractionPercent.map { $0 / 100.0 }) ?? 0.0

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
                self.cloudCover = 0.0
                self.isAvailable = false
            }
        }
    }

    /// Recomputes dynamic sky condition from existing snapshot once sunrise/sunset arrive from Hebcal.
    /// Strictly avoids redundant network requests to MET Norway when valid forecast data is already present.
    public func recomputeSkyContext(
        sunrise: Date?,
        sunset: Date?,
        now: Date = Date()
    ) {
        guard let snapshot = currentSnapshot, isAvailable else { return }
        let zone = currentSnapshotTimeZone ?? .current

        let currentHour = snapshot.hours.first(where: { abs($0.time.timeIntervalSince(now)) <= 3600 })
            ?? snapshot.hours.last(where: { $0.time <= now && now.timeIntervalSince($0.time) <= 7200 })
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
            cal.timeZone = zone
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

        let clouds: Double = (currentHour?.cloudAreaFractionPercent.map { $0 / 100.0 }) ?? 0.0

        self.condition = resolvedCondition
        self.cloudCover = clouds
    }

    /// Resets the model when changing locations or cities.
    public func resetForLocationChange() {
        self.updateGeneration &+= 1
        self.currentSnapshot = nil
        self.weatherDisplay = nil
        self.condition = nil
        self.cloudCover = 0.0
        self.isAvailable = false
        self.currentSnapshotTimeZone = nil
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
        self.weatherDisplay = WeatherDisplay(
            cityName: cityName,
            timeZone: timeZone,
            buttonTitle: "22°",
            header: WeatherDisplay.Header(
                iconName: "sun.max.fill",
                temperature: "22°",
                conditionSummary: "בהיר"
            ),
            stats: [
                WeatherDisplay.Stat(label: "משקעים", value: "0%"),
                WeatherDisplay.Stat(label: "רוח", value: "3 קמ״ש"),
                WeatherDisplay.Stat(label: "עננות", value: "\(Int(preview.cloudCover * 100))%")
            ],
            hourly: []
        )
    }
    #endif
}
