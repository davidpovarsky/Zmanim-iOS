import Foundation

public struct WeatherSnapshot: Sendable, Equatable, Codable {
    public let hours: [WeatherHour]
    public let retrievedAt: Date
    public let locationLatitude: Double
    public let locationLongitude: Double
    public let expiresAt: Date?
    public let lastModified: String?
    public static var attribution: String {
        NSLocalizedString("weather.source_attribution", comment: "")
    }

    public func attribution(language: String? = nil) -> String {
        if let language, let langBundle = LocalizationBundleHelper.bundle(forLanguage: language) {
            return NSLocalizedString("weather.source_attribution", bundle: langBundle, comment: "")
        }
        return Self.attribution
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
