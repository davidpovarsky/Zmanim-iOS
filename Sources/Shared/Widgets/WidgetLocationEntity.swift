import AppIntents
import Foundation

public struct WidgetLocationEntity: AppEntity, Identifiable {
    public static var defaultQuery = WidgetLocationQuery()
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("widget.location_entity_name")
    )

    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

public struct WidgetLocationQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [WidgetLocationEntity] {
        AppGroupDiagnostics.recordWidgetAck(processName: "widget.query")

        let prefsResult = LocationPreferencesStore.loadPreferencesResult()
        let prefs: LocationPreferences
        let isStoreAvailable: Bool

        switch prefsResult {
        case .loaded(let loaded):
            prefs = loaded
            isStoreAvailable = true
        case .noPreferencesYet:
            prefs = LocationPreferences()
            isStoreAvailable = true
        case .storeUnavailable, .corruptData:
            prefs = LocationPreferences()
            isStoreAvailable = false
        }

        return identifiers.compactMap { id -> WidgetLocationEntity? in
            if id == "app-default" {
                return WidgetLocationEntity(
                    id: "app-default",
                    name: NSLocalizedString("widget.location_option.app_default", comment: "")
                )
            } else if id == "current-gps" {
                return WidgetLocationEntity(
                    id: "current-gps",
                    name: NSLocalizedString("widget.location_option.current", comment: "")
                )
            } else if let portableCity = WidgetSavedCityPayload.city(from: id) {
                // Resolve from the configured intent even when SideStore signing
                // prevents the widget extension from mounting the shared App Group.
                // When preferences are available, honor explicit removals/renames.
                if isStoreAvailable && prefs.removedCityIDs.contains(portableCity.id) {
                    return WidgetLocationEntity(
                        id: id,
                        name: NSLocalizedString("location.city_removed_widget", comment: "")
                    )
                }
                let updatedName = prefs.city(for: portableCity.id)?.name
                return WidgetLocationEntity(id: id, name: updatedName ?? portableCity.name)
            } else if let cityId = WidgetSavedCityPayload.legacyCityID(from: id) {
                if let city = prefs.savedCities.first(where: { $0.id == cityId }) {
                    return WidgetLocationEntity(id: id, name: city.name)
                } else if !isStoreAvailable {
                    // Older intent IDs lack coordinates. Ask for re-selection.
                    return WidgetLocationEntity(
                        id: id,
                        name: NSLocalizedString("widget.open_app_to_refresh", comment: "")
                    )
                } else if prefs.removedCityIDs.contains(cityId) {
                    return WidgetLocationEntity(
                        id: id,
                        name: NSLocalizedString("location.city_removed_widget", comment: "")
                    )
                } else {
                    return WidgetLocationEntity(
                        id: id,
                        name: NSLocalizedString("widget.open_app_to_refresh", comment: "")
                    )
                }
            }
            return nil
        }
    }

    public func suggestedEntities() async throws -> [WidgetLocationEntity] {
        AppGroupDiagnostics.recordWidgetAck(processName: "widget.query.suggested")

        var results: [WidgetLocationEntity] = [
            WidgetLocationEntity(
                id: "app-default",
                name: NSLocalizedString("widget.location_option.app_default", comment: "")
            ),
            WidgetLocationEntity(
                id: "current-gps",
                name: NSLocalizedString("widget.location_option.current", comment: "")
            )
        ]

        let prefs = LocationPreferencesStore.loadPreferences()
        for city in prefs.savedCities where city.isValid {
            let portableID = WidgetSavedCityPayload.identifier(for: city)
            guard !portableID.isEmpty else { continue }
            // The selection itself carries verified coordinates and timezone,
            // so a widget remains functional after third-party IPA signing.
            results.append(WidgetLocationEntity(id: portableID, name: city.name))
        }

        return results
    }

    public func entities(matching string: String) async throws -> [WidgetLocationEntity] {
        let all = try await suggestedEntities()
        if string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    public func defaultResult() async -> WidgetLocationEntity? {
        WidgetLocationEntity(
            id: "app-default",
            name: NSLocalizedString("widget.location_option.app_default", comment: "")
        )
    }
}
