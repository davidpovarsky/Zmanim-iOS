import Foundation
import os

public enum LocationSnapshotStore {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "LocationSnapshotStore")

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupStore.groupID)
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

    public static func loadSnapshot(for sourceID: String) -> ZmanSnapshot? {
        guard let defaults else { return nil }
        let key = storageKey(for: sourceID)
        if let data = defaults.data(forKey: key) {
            do {
                return try JSONDecoder().decode(ZmanSnapshot.self, from: data)
            } catch {
                logger.error("Failed to decode ZmanSnapshot for key \(key): \(error.localizedDescription, privacy: .public)")
            }
        }

        // Fallback to global snapshot if looking for default or current
        if sourceID == "current" || sourceID == "default" || sourceID == "app-default" {
            return AppGroupStore.loadSnapshot()
        }

        return nil
    }

    @discardableResult
    public static func saveSnapshot(_ snapshot: ZmanSnapshot, for sourceID: String) -> Bool {
        guard let defaults else { return false }
        let key = storageKey(for: sourceID)
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: key)

            // If this snapshot belongs to the current default location, also update global "snapshot" for backward compatibility
            let prefs = LocationPreferencesStore.loadPreferences()
            let isDefault: Bool
            switch prefs.defaultChoice {
            case .current:
                isDefault = (sourceID == "current" || sourceID == "current-gps" || sourceID == "app-default")
            case .savedCity(let id):
                isDefault = (sourceID == "city_\(id)" || sourceID == "city:\(id)" || sourceID == id)
            }
            if isDefault {
                defaults.set(data, forKey: "snapshot")
            }

            return true
        } catch {
            logger.error("Failed to encode ZmanSnapshot for key \(key): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    public static func removeSnapshot(for sourceID: String) {
        guard let defaults else { return }
        let key = storageKey(for: sourceID)
        defaults.removeObject(forKey: key)
    }

    /// Checks whether the snapshot is fresh for today and has upcoming items or valid coverage.
    public static func isFresh(_ snapshot: ZmanSnapshot, now: Date) -> Bool {
        guard !snapshot.items.isEmpty else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = snapshot.timeZone
        let isToday = cal.isDate(snapshot.updatedAt, inSameDayAs: now)
        let hasUpcoming = snapshot.items.contains(where: { $0.date > now })
        return isToday && hasUpcoming
    }
}
