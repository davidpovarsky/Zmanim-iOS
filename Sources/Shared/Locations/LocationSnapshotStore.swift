import CoreLocation
import Foundation
import os

public enum LocationSnapshotStore {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "LocationSnapshotStore")

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupStore.groupID)
    }

    public static func storageKey(for identity: LocationIdentity) -> String {
        identity.canonicalStorageKey
    }

    public static func storageKey(for sourceID: String) -> String {
        if sourceID == "current" || sourceID == "current-gps" {
            return "snapshot_current"
        }
        if sourceID.hasPrefix("city_") {
            return "snapshot_\(sourceID)"
        }
        if sourceID.hasPrefix("city:") {
            let id = String(sourceID.dropFirst("city:".count))
            return "snapshot_city_\(id)"
        }
        return "snapshot_\(sourceID)"
    }

    /// Loads snapshot strictly for the specified identity with zero cross-city fallback.
    public static func loadSnapshot(for identity: LocationIdentity) -> ZmanSnapshot? {
        guard let defaults else { return nil }
        let key = storageKey(for: identity)
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            let snapshot = try JSONDecoder().decode(ZmanSnapshot.self, from: data)
            // If snapshot contains sourceIdentity metadata, ensure it matches
            if let snapIdentity = snapshot.sourceIdentity, snapIdentity != identity {
                logger.error("Snapshot identity mismatch for key \(key): expected \(identity), got \(snapIdentity)")
                return nil
            }
            return snapshot
        } catch {
            logger.error("Failed to decode ZmanSnapshot for key \(key): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Loads snapshot for a string key with zero cross-city fallback.
    public static func loadSnapshot(for sourceID: String) -> ZmanSnapshot? {
        guard let defaults else { return nil }
        let key = storageKey(for: sourceID)
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(ZmanSnapshot.self, from: data)
        } catch {
            logger.error("Failed to decode ZmanSnapshot for key \(key): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Saves snapshot strictly under its canonical storage key and verifies read-back.
    public static func saveSnapshotThrowing(_ snapshot: ZmanSnapshot, for identity: LocationIdentity) throws {
        guard let defaults else {
            throw LocationStoreError.storeUnavailable
        }
        var updated = snapshot
        updated.sourceIdentity = identity

        let key = storageKey(for: identity)
        let data: Data
        do {
            data = try JSONEncoder().encode(updated)
        } catch {
            logger.error("Failed to encode ZmanSnapshot for key \(key): \(error.localizedDescription, privacy: .public)")
            throw LocationStoreError.encodingFailed(error.localizedDescription)
        }

        defaults.set(data, forKey: key)

        // Verified read-back
        guard let readback = defaults.data(forKey: key), readback == data else {
            logger.error("Read-back verification failed for ZmanSnapshot key \(key)")
            throw LocationStoreError.readbackVerificationFailed
        }

        // If this snapshot belongs to the current default location, also update global "snapshot" for backward compatibility
        let prefs = LocationPreferencesStore.loadPreferences()
        let isDefault: Bool
        switch prefs.defaultChoice {
        case .current:
            isDefault = (identity == .gps)
        case .savedCity(let id):
            isDefault = (identity == .savedCity(id: id))
        }
        if isDefault {
            defaults.set(data, forKey: "snapshot")
        }
    }

    @discardableResult
    public static func saveSnapshot(_ snapshot: ZmanSnapshot, for identity: LocationIdentity) -> Bool {
        do {
            try saveSnapshotThrowing(snapshot, for: identity)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public static func saveSnapshot(_ snapshot: ZmanSnapshot, for sourceID: String) -> Bool {
        let identity: LocationIdentity
        if sourceID == "current" || sourceID == "current-gps" {
            identity = .gps
        } else if sourceID.hasPrefix("city_") {
            identity = .savedCity(id: String(sourceID.dropFirst("city_".count)))
        } else if sourceID.hasPrefix("city:") {
            identity = .savedCity(id: String(sourceID.dropFirst("city:".count)))
        } else {
            // Fallback string storage
            guard let defaults else { return false }
            let key = storageKey(for: sourceID)
            do {
                let data = try JSONEncoder().encode(snapshot)
                defaults.set(data, forKey: key)
                return true
            } catch {
                return false
            }
        }
        return saveSnapshot(snapshot, for: identity)
    }

    public static func removeSnapshot(for identity: LocationIdentity) {
        guard let defaults else { return }
        let key = storageKey(for: identity)
        defaults.removeObject(forKey: key)
    }

    public static func removeSnapshot(for sourceID: String) {
        guard let defaults else { return }
        let key = storageKey(for: sourceID)
        defaults.removeObject(forKey: key)
    }

    /// Checks whether the snapshot is authentic, matches the target, and provides coverage for today.
    public static func isFresh(
        _ snapshot: ZmanSnapshot,
        for identity: LocationIdentity? = nil,
        now: Date = Date(),
        requireTomorrow: Bool = false
    ) -> Bool {
        if let identity {
            return SnapshotValidator.isFresh(snapshot: snapshot, for: identity, now: now, requireTomorrow: requireTomorrow)
        }
        // Generic freshness check: valid timezone, non-empty, and covers now
        guard !snapshot.items.isEmpty, snapshot.locationSignature != "demo" else { return false }
        guard let tz = TimeZone(identifier: snapshot.timeZoneID) else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let hasToday = snapshot.items.contains { cal.isDate($0.date, inSameDayAs: now) }
        guard hasToday else { return false }
        if requireTomorrow {
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now) else { return false }
            return snapshot.items.contains { cal.isDate($0.date, inSameDayAs: tomorrow) }
        }
        return true
    }
}
