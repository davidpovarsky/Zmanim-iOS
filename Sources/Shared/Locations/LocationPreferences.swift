import Foundation

/// Persistent user location preferences stored in the shared App Group.
public struct LocationPreferences: Codable, Hashable, Sendable {
    public var defaultChoice: LocationChoice
    public var savedCities: [SavedCity]
    public var schemaVersion: Int

    public init(
        defaultChoice: LocationChoice = .current,
        savedCities: [SavedCity] = [],
        schemaVersion: Int = 1
    ) {
        self.defaultChoice = defaultChoice
        self.savedCities = savedCities
        self.schemaVersion = schemaVersion
    }

    public func city(for id: String) -> SavedCity? {
        savedCities.first { $0.id == id }
    }

    public func city(for choice: LocationChoice) -> SavedCity? {
        guard case .savedCity(let id) = choice else { return nil }
        return city(for: id)
    }
}
