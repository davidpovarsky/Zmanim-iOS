import Foundation

/// Compact, location-bound weather context shared with the notification extension.
public struct NotificationSkyState: Codable, Sendable {
    public let condition: String
    public let cloudCover: Double
    public let latitude: Double
    public let longitude: Double
    public let updatedAt: Date

    public init(condition: String, cloudCover: Double, latitude: Double, longitude: Double, updatedAt: Date) {
        self.condition = condition
        self.cloudCover = cloudCover
        self.latitude = latitude
        self.longitude = longitude
        self.updatedAt = updatedAt
    }

    public static func load() -> NotificationSkyState? {
        guard let data = UserDefaults(suiteName: "group.com.davidpovarsky.zmanim")?.data(forKey: "notificationSkyState"),
              let state = try? JSONDecoder().decode(NotificationSkyState.self, from: data),
              Date().timeIntervalSince(state.updatedAt) < 7200 else { return nil }
        return state
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: "group.com.davidpovarsky.zmanim")?.set(data, forKey: "notificationSkyState")
    }
}