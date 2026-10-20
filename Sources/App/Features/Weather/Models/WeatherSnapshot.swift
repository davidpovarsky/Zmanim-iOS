import Foundation

public struct WeatherSnapshot: Sendable, Equatable, Codable {
    public let hours: [WeatherHour]
    public let retrievedAt: Date
    public let locationLatitude: Double
    public let locationLongitude: Double
    public let expiresAt: Date?
    public static var attribution: String {
        NSLocalizedString("weather.source_attribution", value: "נתוני מזג אוויר: MET Norway (CC BY 4.0)", comment: "")
    }

    public init(
        hours: [WeatherHour],
        retrievedAt: Date,
        locationLatitude: Double,
        locationLongitude: Double,
        expiresAt: Date? = nil,
        lastModified: String? = nil
    ) {
        self.hours = hours
        self.retrievedAt = retrievedAt
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.expiresAt = expiresAt
        self.lastModified = lastModified
    }
}
