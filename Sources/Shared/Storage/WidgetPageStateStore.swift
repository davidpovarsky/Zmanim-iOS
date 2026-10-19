import Foundation
import os

public struct WidgetPageState: Codable, Hashable, Sendable {
    public var pageIndex: Int
    public var lastInteractionAt: Date
    public var expiresAt: Date
    public var dayKey: String
    public var locationFingerprint: String
    public var schemaVersion: Int

    public init(
        pageIndex: Int = 0,
        lastInteractionAt: Date = Date(),
        expiresAt: Date = Date(),
        dayKey: String = "",
        locationFingerprint: String = "",
        schemaVersion: Int = 1
    ) {
        self.pageIndex = pageIndex
        self.lastInteractionAt = lastInteractionAt
        self.expiresAt = expiresAt
        self.dayKey = dayKey
        self.locationFingerprint = locationFingerprint
        self.schemaVersion = schemaVersion
    }
}

public enum WidgetPageStateStore {
    private static let key = "widget_page_state_v1"
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "WidgetPageStateStore")

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupStore.groupID)
    }

    public static func loadState() -> WidgetPageState? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(WidgetPageState.self, from: data)
        } catch {
            logger.error("Failed to decode WidgetPageState: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    @discardableResult
    public static func saveState(_ state: WidgetPageState) -> Bool {
        guard let defaults else { return false }
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: key)
            return true
        } catch {
            logger.error("Failed to encode WidgetPageState: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    public static func resetState() {
        defaults?.removeObject(forKey: key)
    }

    /// Formats a stable day key YYYY-MM-DD in the specified timeZone.
    public static func dayKey(for date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Resolves the effective page index considering expiry (60s), day rollover, and location change.
    public static func effectivePageIndex(
        state: WidgetPageState?,
        currentDate: Date,
        currentDayKey: String,
        currentLocationFingerprint: String,
        pageCount: Int
    ) -> Int {
        guard let state else { return 0 }
        guard state.dayKey == currentDayKey else { return 0 }
        guard state.locationFingerprint == currentLocationFingerprint else { return 0 }
        guard currentDate < state.expiresAt else { return 0 }
        guard pageCount > 0 else { return 0 }

        if state.pageIndex < 0 || state.pageIndex >= pageCount {
            return 0
        }
        return state.pageIndex
    }
}
