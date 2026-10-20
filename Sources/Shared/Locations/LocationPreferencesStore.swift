import Foundation
import os

public enum LocationPreferencesStore {
    public static let preferencesKey = "location_preferences_v1"
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "LocationPreferencesStore")

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupStore.groupID)
    }

    public static func loadPreferences() -> LocationPreferences {
        guard let defaults else {
            return LocationPreferences()
        }

        if let data = defaults.data(forKey: preferencesKey) {
            do {
                return try JSONDecoder().decode(LocationPreferences.self, from: data)
            } catch {
                logger.error("Failed to decode LocationPreferences: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Perform backward-compatibility migration from legacy UserSettings
        return migrateFromLegacySettings()
    }

    @discardableResult
    public static func savePreferences(_ preferences: LocationPreferences) -> Bool {
        guard let defaults else { return false }
        do {
            let data = try JSONEncoder().encode(preferences)
            defaults.set(data, forKey: preferencesKey)
            syncLegacyUserSettings(from: preferences)
            return true
        } catch {
            logger.error("Failed to encode LocationPreferences: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @discardableResult
    public static func setDefaultChoice(_ choice: LocationChoice) -> LocationPreferences {
        var prefs = loadPreferences()
        prefs.defaultChoice = choice
        savePreferences(prefs)
        return prefs
    }

    @discardableResult
    public static func addCity(name: String, latitude: Double, longitude: Double, timeZoneID: String) -> (preferences: LocationPreferences, city: SavedCity) {
        var prefs = loadPreferences()

        // Check for deduplication by coordinates (< 5km / ~0.05 degrees) or identical name
        if let existing = prefs.savedCities.first(where: {
            (abs($0.latitude - latitude) < 0.05 && abs($0.longitude - longitude) < 0.05) ||
            $0.name.caseInsensitiveCompare(name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }) {
            return (prefs, existing)
        }

        let newCity = SavedCity(
            id: UUID().uuidString,
            name: name,
            latitude: latitude,
            longitude: longitude,
            timeZoneID: timeZoneID,
            order: prefs.savedCities.count
        )

        prefs.savedCities.append(newCity)
        savePreferences(prefs)
        return (prefs, newCity)
    }

    @discardableResult
    public static func removeCity(id: String) -> LocationPreferences {
        var prefs = loadPreferences()
        prefs.savedCities.removeAll { $0.id == id }

        // Reassign order
        for (index, _) in prefs.savedCities.enumerated() {
            prefs.savedCities[index].order = index
        }

        // If removed city was the default choice, fallback to .current
        if case .savedCity(let defaultId) = prefs.defaultChoice, defaultId == id {
            prefs.defaultChoice = .current
        }

        savePreferences(prefs)
        return prefs
    }

    @discardableResult
    public static func reorderCities(_ reordered: [SavedCity]) -> LocationPreferences {
        var prefs = loadPreferences()
        var updated = reordered
        for (index, _) in updated.enumerated() {
            updated[index].order = index
        }
        prefs.savedCities = updated
        savePreferences(prefs)
        return prefs
    }

    // MARK: - Legacy Migration

    private static func migrateFromLegacySettings() -> LocationPreferences {
        let legacy = AppGroupStore.loadSettings()
        var cities: [SavedCity] = []
        var defaultChoice: LocationChoice = .current

        if let resolved = legacy.resolvedFixedLocation,
           !resolved.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let city = SavedCity(
                id: UUID().uuidString,
                name: resolved.displayName,
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
                // Legacy fixed city name without coordinates: default to current GPS safely
                defaultChoice = .current
            }
        }

        let migrated = LocationPreferences(
            defaultChoice: defaultChoice,
            savedCities: cities,
            schemaVersion: 1
        )

        if let defaults, let data = try? JSONEncoder().encode(migrated) {
            defaults.set(data, forKey: preferencesKey)
        }

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
