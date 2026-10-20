import CoreLocation
import Foundation

public actor WeatherCache {
    public static let shared = WeatherCache()

    private struct CacheEntry {
        var snapshot: WeatherSnapshot
        var timeZoneID: String
    }

    private var entries: [String: CacheEntry] = [:]

    public init() {}

    private func locationKey(latitude: Double, longitude: Double) -> String {
        let roundedLat = (latitude * 100).rounded() / 100
        let roundedLon = (longitude * 100).rounded() / 100
        return "\(roundedLat),\(roundedLon)"
    }

    /// Retrieves a valid, unexpired cached snapshot for the given coordinate and time zone.
    public func getCached(
        latitude: Double,
        longitude: Double,
        timeZoneID: String,
        now: Date = Date()
    ) -> WeatherSnapshot? {
        let queryLoc = CLLocation(latitude: latitude, longitude: longitude)

        for entry in entries.values {
            guard entry.timeZoneID == timeZoneID else { continue }
            let snap = entry.snapshot
            if let expires = snap.expiresAt, now >= expires {
                continue
            }
            let cachedLoc = CLLocation(latitude: snap.locationLatitude, longitude: snap.locationLongitude)
            if cachedLoc.distance(from: queryLoc) < 5000 {
                return snap
            }
        }
        return nil
    }

    /// Stores a new snapshot along with its time zone.
    public func save(snapshot: WeatherSnapshot, timeZoneID: String) {
        let key = locationKey(latitude: snapshot.locationLatitude, longitude: snapshot.locationLongitude)
        entries[key] = CacheEntry(snapshot: snapshot, timeZoneID: timeZoneID)
    }

    /// Retrieves the Last-Modified header value for conditional HTTP requests if coordinates match.
    public func getLastModified(latitude: Double, longitude: Double) -> String? {
        let queryLoc = CLLocation(latitude: latitude, longitude: longitude)
        for entry in entries.values {
            let snap = entry.snapshot
            let cachedLoc = CLLocation(latitude: snap.locationLatitude, longitude: snap.locationLongitude)
            if cachedLoc.distance(from: queryLoc) < 5000 {
                return snap.lastModified
            }
        }
        return nil
    }

    /// Extends expiration on HTTP 304 Not Modified.
    public func refreshExpiration(latitude: Double? = nil, longitude: Double? = nil, newExpiresAt: Date?) {
        if let latitude, let longitude {
            let queryLoc = CLLocation(latitude: latitude, longitude: longitude)
            for (key, entry) in entries {
                let snap = entry.snapshot
                let cachedLoc = CLLocation(latitude: snap.locationLatitude, longitude: snap.locationLongitude)
                if cachedLoc.distance(from: queryLoc) < 5000 {
                    let updated = WeatherSnapshot(
                        hours: snap.hours,
                        retrievedAt: Date(),
                        locationLatitude: snap.locationLatitude,
                        locationLongitude: snap.locationLongitude,
                        expiresAt: newExpiresAt ?? snap.expiresAt,
                        lastModified: snap.lastModified
                    )
                    entries[key]?.snapshot = updated
                    return
                }
            }
        } else if let firstKey = entries.keys.first, let existing = entries[firstKey]?.snapshot {
            entries[firstKey]?.snapshot = WeatherSnapshot(
                hours: existing.hours,
                retrievedAt: Date(),
                locationLatitude: existing.locationLatitude,
                locationLongitude: existing.locationLongitude,
                expiresAt: newExpiresAt ?? existing.expiresAt,
                lastModified: existing.lastModified
            )
        }
    }

    /// Clears the in-memory cache, e.g. for testing.
    public func clear() {
        entries.removeAll()
    }
}
