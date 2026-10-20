import Foundation

/// Represents a persistent saved city with coordinates and time zone.
public struct SavedCity: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var timeZoneID: String
    public var order: Int

    public init(
        id: String = UUID().uuidString,
        name: String,
        latitude: Double,
        longitude: Double,
        timeZoneID: String,
        order: Int = 0
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneID = timeZoneID
        self.order = order
    }

    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .current
    }

    public var isValid: Bool {
        latitude >= -90.0 && latitude <= 90.0 &&
        longitude >= -180.0 && longitude <= 180.0 &&
        !name.isEmpty
    }
}
