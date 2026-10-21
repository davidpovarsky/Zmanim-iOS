import Foundation

/// The same pure resolver is used by WidgetKit and by regression tests.
/// Explicit city selections include validated coordinates for extension
/// processes that cannot read an App Group after third-party IPA signing.
enum ResolvedWidgetTarget: Sendable, Equatable {
    case gps
    case savedCity(SavedCity)
    case sharedStoreUnavailable
    case savedCityMissing(cityID: String)
    case cityRemoved(cityID: String)
    case invalidConfiguration
}

enum WidgetTargetResolver {
    static func resolve(
        identifier: String?,
        preferencesResult: LocationPreferencesLoadResult
    ) -> ResolvedWidgetTarget {
        let preferences: LocationPreferences?
        switch preferencesResult {
        case .loaded(let loaded):
            preferences = loaded
        case .noPreferencesYet:
            preferences = LocationPreferences()
        case .storeUnavailable, .corruptData:
            preferences = nil
        }

        if identifier == "current-gps" { return .gps }

        if let identifier, let embedded = WidgetSavedCityPayload.city(from: identifier) {
            // Prefer current saved details, but never silently switch to GPS.
            if let preferences {
                if preferences.removedCityIDs.contains(embedded.id) {
                    return .cityRemoved(cityID: embedded.id)
                }
                if let updated = preferences.city(for: embedded.id), updated.isValid {
                    return .savedCity(updated)
                }
            }
            return .savedCity(embedded)
        }

        if identifier == nil || identifier == "app-default" {
            guard let preferences else { return .sharedStoreUnavailable }
            switch preferences.defaultChoice {
            case .current:
                return .gps
            case .savedCity(let id):
                return findSavedCity(id, in: preferences)
            }
        }

        if let identifier, let legacyID = WidgetSavedCityPayload.legacyCityID(from: identifier) {
            guard let preferences else { return .sharedStoreUnavailable }
            return findSavedCity(legacyID, in: preferences)
        }

        return .invalidConfiguration
    }

    private static func findSavedCity(_ id: String, in preferences: LocationPreferences) -> ResolvedWidgetTarget {
        if let city = preferences.city(for: id), city.isValid {
            return .savedCity(city)
        }
        if preferences.removedCityIDs.contains(id) {
            return .cityRemoved(cityID: id)
        }
        return .savedCityMissing(cityID: id)
    }
}
