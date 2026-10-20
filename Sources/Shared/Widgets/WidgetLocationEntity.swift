import AppIntents
import Foundation

public struct WidgetLocationEntity: AppEntity, Identifiable {
    public static var defaultQuery = WidgetLocationQuery()
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("widget.location_entity_name", defaultValue: "מיקום")
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
        let prefs = LocationPreferencesStore.loadPreferences()
        return identifiers.compactMap { id -> WidgetLocationEntity? in
            if id == "app-default" {
                return WidgetLocationEntity(
                    id: "app-default",
                    name: NSLocalizedString("widget.location_option.app_default", value: "ברירת המחדל של האפליקציה", comment: "")
                )
            } else if id == "current-gps" {
                return WidgetLocationEntity(
                    id: "current-gps",
                    name: NSLocalizedString("widget.location_option.current", value: "המיקום הנוכחי (GPS)", comment: "")
                )
            } else if id.hasPrefix("city:") {
                let cityId = String(id.dropFirst("city:".count))
                if let city = prefs.savedCities.first(where: { $0.id == cityId }) {
                    return WidgetLocationEntity(id: id, name: city.name)
                } else {
                    return WidgetLocationEntity(
                        id: id,
                        name: NSLocalizedString("location.city_removed_widget", value: "העיר הוסרה — ערוך את הווידג'ט", comment: "")
                    )
                }
            }
            return nil
        }
    }

    public func suggestedEntities() async throws -> [WidgetLocationEntity] {
        var results: [WidgetLocationEntity] = [
            WidgetLocationEntity(
                id: "app-default",
                name: NSLocalizedString("widget.location_option.app_default", value: "ברירת המחדל של האפליקציה", comment: "")
            ),
            WidgetLocationEntity(
                id: "current-gps",
                name: NSLocalizedString("widget.location_option.current", value: "המיקום הנוכחי (GPS)", comment: "")
            )
        ]

        let prefs = LocationPreferencesStore.loadPreferences()
        for city in prefs.savedCities {
            results.append(WidgetLocationEntity(id: "city:\(city.id)", name: city.name))
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
            name: NSLocalizedString("widget.location_option.app_default", value: "ברירת המחדל של האפליקציה", comment: "")
        )
    }
}
