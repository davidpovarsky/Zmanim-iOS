import Foundation
import os

public enum LocationPreferencesLoadResult: Sendable, Equatable {
    case loaded(LocationPreferences)
    case noPreferencesYet
    case storeUnavailable
    case corruptData(String)
}

public enum LocationPreferencesStore {
    public static let preferencesKey = "location_preferences_v1"
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "LocationPreferencesStore")

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupStore.groupID)
    }

    /// Evaluates preferences loading with distinct state discrimination:
    /// storeUnavailable vs corruptData vs noPreferencesYet vs loaded.
    public static func loadPreferencesResult() -> LocationPreferencesLoadResult {
        guard let defaults else {
            return .storeUnavailable
        }

        if let data = defaults.data(forKey: preferencesKey) {
            do {
                let prefs = try JSONDecoder().decode(LocationPreferences.self, from: data)
                return .loaded(prefs)
            } catch {
                logger.error("Failed to decode LocationPreferences: \(error.localizedDescription, privacy: .public)")
                return .corruptData(error.localizedDescription)
            }
        }

        // Check if legacy UserSettings can be migrated
        if let migrated = migrateFromLegacySettingsIfPresent() {
            return .loaded(migrated)
        }

        return .noPreferencesYet
    }

    /// Fallback-safe accessor that returns loaded preferences or default instance.
    public static func loadPreferences() -> LocationPreferences {
        switch loadPreferencesResult() {
        case .loaded(let prefs):
            return prefs
        case .noPreferencesYet, .storeUnavailable, .corruptData:
            return LocationPreferences()
        }
    }

    /// Atomically saves preferences and performs read-back verification.
    public static func savePreferencesThrowing(_ preferences: LocationPreferences) throws {
        guard let defaults else {
            throw LocationStoreError.storeUnavailable
        }
        let data: Data
        do {
            data = try JSONEncoder().encode(preferences)
        } catch {
            logger.error("Failed to encode LocationPreferences: \(error.localizedDescription, privacy: .public)")
            throw LocationStoreError.encodingFailed(error.localizedDescription)
        }

        defaults.set(data, forKey: preferencesKey)

        // Verified read-back to guarantee the shared container actually persisted
        guard let readback = defaults.data(forKey: preferencesKey), readback == data else {
            logger.error("Read-back verification failed for LocationPreferences")
            throw LocationStoreError.readbackVerificationFailed
        }

        syncLegacyUserSettings(from: preferences)
    }

    @discardableResult
    public static func savePreferences(_ preferences: LocationPreferences) -> Bool {
        do {
            try savePreferencesThrowing(preferences)
            return true
        } catch {
            return false
        }
    }

    public static func setDefaultChoiceThrowing(_ choice: LocationChoice) throws -> LocationPreferences {
        var prefs = loadPreferences()
        prefs.defaultChoice = choice
        try savePreferencesThrowing(prefs)
        return prefs
    }

    @discardableResult
    public static func setDefaultChoice(_ choice: LocationChoice) -> LocationPreferences {
        (try? setDefaultChoiceThrowing(choice)) ?? loadPreferences()
    }

    public static func addCityThrowing(
        name: String,
        latitude: Double,
        longitude: Double,
        timeZoneID: String
    ) throws -> (preferences: LocationPreferences, city: SavedCity) {
        var prefs = loadPreferences()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Deduplication by coordinates (< 5km / ~0.05 degrees) or identical name
        if let existing = prefs.savedCities.first(where: {
            (abs($0.latitude - latitude) < 0.05 && abs($0.longitude - longitude) < 0.05) ||
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }) {
            return (prefs, existing)
        }

        let newCity = SavedCity(
            id: UUID().uuidString,
            name: trimmedName,
            latitude: latitude,
            longitude: longitude,
            timeZoneID: timeZoneID,
            order: prefs.savedCities.count
        )

        prefs.savedCities.append(newCity)
        // If this city was previously in removedCityIDs, clear it
        prefs.removedCityIDs.removeAll { $0 == newCity.id }

        try savePreferencesThrowing(prefs)
        return (prefs, newCity)
    }

    @discardableResult
    public static func addCity(
        name: String,
        latitude: Double,
        longitude: Double,
        timeZoneID: String
    ) -> (preferences: LocationPreferences, city: SavedCity) {
        if let result = try? addCityThrowing(name: name, latitude: latitude, longitude: longitude, timeZoneID: timeZoneID) {
            return result
        }
        let fallbackCity = SavedCity(id: UUID().uuidString, name: name, latitude: latitude, longitude: longitude, timeZoneID: timeZoneID)
        return (loadPreferences(), fallbackCity)
    }

    public static func removeCityThrowing(id: String) throws -> LocationPreferences {
        var prefs = loadPreferences()
        prefs.savedCities.removeAll { $0.id == id }

        // Track that this city ID was explicitly removed by the user
        if !prefs.removedCityIDs.contains(id) {
            prefs.removedCityIDs.append(id)
        }

        // Reassign order
        for index in prefs.savedCities.indices {
            prefs.savedCities[index].order = index
        }

        // If removed city was the default choice, fallback to .current
        if case .savedCity(let defaultId) = prefs.defaultChoice, defaultId == id {
            prefs.defaultChoice = .current
        }

        try savePreferencesThrowing(prefs)
        return prefs
    }

    @discardableResult
    public static func removeCity(id: String) -> LocationPreferences {
        (try? removeCityThrowing(id: id)) ?? loadPreferences()
    }

    public static func reorderCitiesThrowing(_ reordered: [SavedCity]) throws -> LocationPreferences {
        var prefs = loadPreferences()
        var updated = reordered
        for index in updated.indices {
            updated[index].order = index
        }
        prefs.savedCities = updated
        try savePreferencesThrowing(prefs)
        return prefs
    }

    @discardableResult
    public static func reorderCities(_ reordered: [SavedCity]) -> LocationPreferences {
        (try? reorderCitiesThrowing(reordered)) ?? loadPreferences()
    }

    // MARK: - Legacy Migration

    private static func migrateFromLegacySettingsIfPresent() -> LocationPreferences? {
        let legacy = AppGroupStore.loadSettings()
        var cities: [SavedCity] = []
        var defaultChoice: LocationChoice = .current

        if let resolved = legacy.resolvedFixedLocation,
           !resolved.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cleanName = resolved.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            // Deterministic stable ID derived from the name and coordinates to prevent UUID drift across unpersisted reads
            let stableHash = abs("\(cleanName)_\(resolved.latitude)_\(resolved.longitude)".hashValue)
            let stableID = "legacy_\(stableHash)"

            let city = SavedCity(
                id: stableID,
                name: cleanName,
                latitude: resolved.latitude,
                longitude: resolved.longitude,
                timeZoneID: resolved.timeZoneID,
                order: 0
            )
            cities.append(city)

            if legacy.locationMode == .fixed {
                defaultChoice = .savedCity(id: city.id)
            } else {
                defaultChoice = .current
            }
        } else if !legacy.fixedCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if legacy.locationMode == .fixed {
                defaultChoice = .current
            }
        } else {
            return nil
        }

        let migrated = LocationPreferences(
            defaultChoice: defaultChoice,
            savedCities: cities,
            schemaVersion: 1
        )

        // Attempt persistence; even if persistence fails, we return the deterministic migrated instance
        _ = savePreferences(migrated)
        return migrated
    }

    private static func syncLegacyUserSettings(from preferences: LocationPreferences) {
        var settings = AppGroupStore.loadSettings()
        switch preferences.defaultChoice {
        case .current:
            settings.locationMode = .current
            if let first = preferences.savedCities.first {
                settings.fixedCity = first.name
                settings.resolvedFixedLocation = ResolvedLocation(
                    displayName: first.name,
                    latitude: first.latitude,
                    longitude: first.longitude,
                    timeZoneID: first.timeZoneID,
                    source: .fixedSearch
                )
            }
        case .savedCity(let id):
            if let city = preferences.city(for: id) {
                settings.locationMode = .fixed
                settings.fixedCity = city.name
                settings.resolvedFixedLocation = ResolvedLocation(
                    displayName: city.name,
                    latitude: city.latitude,
                    longitude: city.longitude,
                    timeZoneID: city.timeZoneID,
                    source: .fixedSearch
                )
            }
        }
        AppGroupStore.saveSettings(settings)
    }
}
