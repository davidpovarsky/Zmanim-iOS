import Foundation

/// Persistent user location preferences stored in the shared App Group.
public struct LocationPreferences: Codable, Hashable, Sendable {
    public var defaultChoice: LocationChoice
    public var savedCities: [SavedCity]
    public var schemaVersion: Int
    public var removedCityIDs: [String]

    public init(
        defaultChoice: LocationChoice = .current,
        savedCities: [SavedCity] = [],
        schemaVersion: Int = 1,
        removedCityIDs: [String] = []
    ) {
        self.defaultChoice = defaultChoice
        self.savedCities = savedCities
        self.schemaVersion = schemaVersion
        self.removedCityIDs = removedCityIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.defaultChoice = try container.decodeIfPresent(LocationChoice.self, forKey: .defaultChoice) ?? .current
        self.savedCities = try container.decodeIfPresent([SavedCity].self, forKey: .savedCities) ?? []
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.removedCityIDs = try container.decodeIfPresent([String].self, forKey: .removedCityIDs) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case defaultChoice
        case savedCities
        case schemaVersion
        case removedCityIDs
    }

    public func city(for id: String) -> SavedCity? {
        savedCities.first { $0.id == id }
    }

    public func city(for choice: LocationChoice) -> SavedCity? {
        guard case .savedCity(let id) = choice else { return nil }
        return city(for: id)
    }
}
