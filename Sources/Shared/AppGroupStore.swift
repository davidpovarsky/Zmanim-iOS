import Foundation
import os

enum AppGroupStore {
    static let groupID = "group.com.davidpovarsky.zmanim"
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "AppGroupStore")

    private static var defaults: UserDefaults? {
        guard let suite = UserDefaults(suiteName: groupID) else {
            logger.error("App Group is unavailable: \(Self.groupID, privacy: .public)")
            return nil
        }
        return suite
    }

    static var isAvailable: Bool { defaults != nil }

    static func loadSettings() -> UserSettings {
        guard let defaults, let data = defaults.data(forKey: "settings") else {
            return UserSettings()
        }
        guard let value = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            logger.error("Unable to decode shared settings")
            return UserSettings()
        }
        return value
    }

    @discardableResult
    static func saveSettings(_ value: UserSettings) -> Bool {
        guard let defaults, let data = try? JSONEncoder().encode(value) else {
            logger.error("Unable to save settings because App Group is unavailable or encoding failed")
            return false
        }
        defaults.set(data, forKey: "settings")
        return true
    }

    static func loadSnapshot() -> ZmanSnapshot? {
        guard let defaults, let data = defaults.data(forKey: "snapshot") else {
            return nil
        }
        guard let value = try? JSONDecoder().decode(ZmanSnapshot.self, from: data) else {
            logger.error("Unable to decode shared zman snapshot")
            return nil
        }
        return value
    }

    @discardableResult
    static func saveSnapshot(_ value: ZmanSnapshot) -> Bool {
        guard let defaults, let data = try? JSONEncoder().encode(value) else {
            logger.error("Unable to save snapshot because App Group is unavailable or encoding failed")
            return false
        }
        defaults.set(data, forKey: "snapshot")
        return true
    }

    static var quickReminderEnabled: Bool {
        get { defaults?.bool(forKey: "quickReminder") ?? false }
        set { defaults?.set(newValue, forKey: "quickReminder") }
    }
}
