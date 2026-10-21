import Foundation

/// Portable, validated saved-city configuration for WidgetKit.
/// A widget extension can resolve its selected city without depending on
/// App Group entitlements surviving a third-party signing process.
/// Only explicitly selected saved cities use this identifier format.
public enum WidgetSavedCityPayload {
    public static let prefix = "city-v2:"

    private struct Record: Codable {
        let version: Int
        let cityID: String
        let name: String
        let latitude: Double
        let longitude: Double
        let timeZoneID: String
    }

    /// Stable across launches for unchanged city details.
    public static func identifier(for city: SavedCity) -> String {
        let record = Record(
            version: 1,
            cityID: city.id,
            name: city.name,
            latitude: city.latitude,
            longitude: city.longitude,
            timeZoneID: city.timeZoneID
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(record) else { return "" }
        let encoded = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return prefix + encoded
    }

    /// Decode only self-contained city choices, never guess coordinates.
    public static func city(from identifier: String) -> SavedCity? {
        guard identifier.hasPrefix(prefix) else { return nil }
        let payload = String(identifier.dropFirst(prefix.count))
        guard !payload.isEmpty, payload.utf8.count <= 4096 else { return nil }
        let base64 = payload.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: padded),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.version == 1,
              !record.cityID.isEmpty,
              record.cityID.utf8.count <= 128,
              record.name.utf8.count <= 256,
              record.latitude.isFinite, record.longitude.isFinite
        else { return nil }

        let city = SavedCity(
            id: record.cityID,
            name: record.name,
            latitude: record.latitude,
            longitude: record.longitude,
            timeZoneID: record.timeZoneID
        )
        return city.isValid ? city : nil
    }

    /// Supports existing WidgetKit configurations created before the fix.
    public static func legacyCityID(from identifier: String) -> String? {
        if identifier.hasPrefix("city:") {
            let id = String(identifier.dropFirst("city:".count))
            return id.isEmpty ? nil : id
        }
        if identifier.hasPrefix("city_") {
            let id = String(identifier.dropFirst("city_".count))
            return id.isEmpty ? nil : id
        }
        return nil
    }
}
