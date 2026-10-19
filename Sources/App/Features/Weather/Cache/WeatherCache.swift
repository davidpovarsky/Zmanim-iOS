import Foundation
import CoreLocation

public actor WeatherCache {
    public static let shared = WeatherCache()

    private var currentSnapshot: WeatherSnapshot?
    private var cachedTimeZoneID: String?

    public init() {}

    /// Retrieves a valid, unexpired cached snapshot for the given coordinate and time zone.
    public func getCached(
        latitude: Double,
        longitude: Double,
        timeZoneID: String,
        now: Date = Date()
    ) -> WeatherSnapshot? {
        guard let snapshot = currentSnapshot else { return nil }
        guard cachedTimeZoneID == timeZoneID else { return nil }

        // Validate expiry
        if let expires = snapshot.expiresAt, now >= expires {
            return nil
        }

        // Distance check: within ~5km
        let cachedLoc = CLLocation(latitude: snapshot.locationLatitude, longitude: snapshot.locationLongitude)
        let queryLoc = CLLocation(latitude: latitude, longitude: longitude)
        guard cachedLoc.distance(from: queryLoc) < 5000 else {
            return nil
        }

        return snapshot
    }

    /// Stores a new snapshot along with its time zone.
    public func save(snapshot: WeatherSnapshot, timeZoneID: String) {
        self.currentSnapshot = snapshot
        self.cachedTimeZoneID = timeZoneID
    }

    /// Retrieves the Last-Modified header value for conditional HTTP requests if coordinates match.
    public func getLastModified(latitude: Double, longitude: Double) -> String? {
        guard let snapshot = currentSnapshot else { return nil }
        let cachedLoc = CLLocation(latitude: snapshot.locationLatitude, longitude: snapshot.locationLongitude)
        let queryLoc = CLLocation(latitude: latitude, longitude: longitude)
        guard cachedLoc.distance(from: queryLoc) < 5000 else { return nil }
        return snapshot.lastModified
    }

    /// Extends expiration on HTTP 304 Not Modified.
    public func refreshExpiration(newExpiresAt: Date?) {
        guard let existing = currentSnapshot else { return }
        self.currentSnapshot = WeatherSnapshot(
            hours: existing.hours,
            retrievedAt: Date(),
            locationLatitude: existing.locationLatitude,
            locationLongitude: existing.locationLongitude,
            expiresAt: newExpiresAt ?? existing.expiresAt,
            lastModified: existing.lastModified
        )
    }

    /// Clears the in-memory cache, e.g. when changing cities.
    public func clear() {
        self.currentSnapshot = nil
        self.cachedTimeZoneID = nil
    }
}
