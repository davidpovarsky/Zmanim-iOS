import CoreLocation
import Foundation

public struct VerifiedLocality: Codable, Hashable, Sendable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneID: String
    public let localeIdentifier: String
    public let verifiedAt: Date

    public init(
        name: String,
        latitude: Double,
        longitude: Double,
        timeZoneID: String,
        localeIdentifier: String,
        verifiedAt: Date = Date()
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneID = timeZoneID
        self.localeIdentifier = localeIdentifier
        self.verifiedAt = verifiedAt
    }
}

public enum VerifiedLocalityStore {
    private static let storageKey = "verified_locality_gps_v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupStore.groupID)
    }

    public static func load(for coordinate: CLLocationCoordinate2D, maxDistanceMeters: Double = 5000) -> VerifiedLocality? {
        guard let defaults, let data = defaults.data(forKey: storageKey) else { return nil }
        guard let locality = try? JSONDecoder().decode(VerifiedLocality.self, from: data) else { return nil }
        let storedLoc = CLLocation(latitude: locality.latitude, longitude: locality.longitude)
        let queryLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard storedLoc.distance(from: queryLoc) <= maxDistanceMeters else { return nil }
        return locality
    }

    public static func save(_ locality: VerifiedLocality) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(locality) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
