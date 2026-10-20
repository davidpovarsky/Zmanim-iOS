import Foundation

public struct ZmanItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let key: String
    public let hebrewTitle: String
    public let englishTitle: String
    public let icon: String
    public let date: Date

    public init(key: String, hebrewTitle: String, englishTitle: String, icon: String, date: Date) {
        self.key = key
        self.hebrewTitle = hebrewTitle
        self.englishTitle = englishTitle
        self.icon = icon
        self.date = date
        self.id = "\(key)-\(Int(date.timeIntervalSince1970))"
    }

    public func localizedTitle(locale: Locale = .autoupdatingCurrent) -> String {
        let lang = locale.language.languageCode?.identifier ?? (locale.identifier.hasPrefix("en") ? "en" : "he")
        if lang == "en" && !englishTitle.isEmpty {
            return englishTitle
        }
        return hebrewTitle
    }

    public var displayTitle: String {
        localizedTitle()
    }
}

public struct ZmanDefinition: Hashable, Sendable {
    public let key: String
    public let hebrewTitle: String
    public let englishTitle: String
    public let icon: String

    public init(key: String, hebrewTitle: String, englishTitle: String, icon: String) {
        self.key = key
        self.hebrewTitle = hebrewTitle
        self.englishTitle = englishTitle
        self.icon = icon
    }

    public func localizedTitle(locale: Locale = .autoupdatingCurrent) -> String {
        let lang = locale.language.languageCode?.identifier ?? (locale.identifier.hasPrefix("en") ? "en" : "he")
        if lang == "en" && !englishTitle.isEmpty {
            return englishTitle
        }
        return hebrewTitle
    }
}

public enum LocationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case current, fixed
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .current:
            return NSLocalizedString("location.current", value: "המיקום הנוכחי", comment: "")
        case .fixed:
            return NSLocalizedString("location.fixed", value: "עיר קבועה", comment: "")
        }
    }
}

public struct NotificationRule: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var zmanKey: String
    public var title: String
    public var offsetMinutes: Int
    public var isEnabled: Bool
    public var customName: String?

    public init(id: String? = nil, zmanKey: String, title: String, offsetMinutes: Int = -15, isEnabled: Bool = false, customName: String? = nil) {
        self.id = id ?? zmanKey
        self.zmanKey = zmanKey
        self.title = title
        self.offsetMinutes = offsetMinutes
        self.isEnabled = isEnabled
        self.customName = customName
    }

    public var displayTitle: String {
        let s = customName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? title : s
    }
}

public struct UserSettings: Codable, Hashable, Sendable {
    public var locationMode: LocationMode = .current
    public var fixedCity = ""
    public var shabbatMasterEnabled = false
    public var holidayMasterEnabled = false
    public var rules: [NotificationRule] = Self.defaultRules

    public init(
        locationMode: LocationMode = .current,
        fixedCity: String = "",
        shabbatMasterEnabled: Bool = false,
        holidayMasterEnabled: Bool = false,
        rules: [NotificationRule] = Self.defaultRules
    ) {
        self.locationMode = locationMode
        self.fixedCity = fixedCity
        self.shabbatMasterEnabled = shabbatMasterEnabled
        self.holidayMasterEnabled = holidayMasterEnabled
        self.rules = rules
    }

    public static let defaultRules: [NotificationRule] = [
        .init(zmanKey: "alotHaShachar", title: "עלות השחר"),
        .init(zmanKey: "misheyakir", title: "משיכיר"),
        .init(zmanKey: "sunrise", title: "זריחה"),
        .init(zmanKey: "sofZmanShmaMGA", title: "סוף זמן ק״ש (מג״א)"),
        .init(zmanKey: "sofZmanShma", title: "סוף זמן ק״ש (גר״א)"),
        .init(zmanKey: "sofZmanTfilla", title: "סוף זמן תפילה"),
        .init(zmanKey: "chatzot", title: "חצות היום"),
        .init(zmanKey: "minchaGedola", title: "מנחה גדולה"),
        .init(zmanKey: "minchaKetana", title: "מנחה קטנה"),
        .init(zmanKey: "plagHaMincha", title: "פלג המנחה"),
        .init(zmanKey: "sunset", title: "שקיעה"),
        .init(zmanKey: "tzeit7083deg", title: "צאת הכוכבים"),
        .init(zmanKey: "tzeitRT", title: "צאת הכוכבים (רבנו תם)"),
        .init(zmanKey: "candleLighting", title: "כניסת שבת")
    ]
}

public struct ZmanSnapshot: Codable, Hashable, Sendable {
    public var cityName: String
    public var timeZoneID: String
    public var latitude: Double
    public var longitude: Double
    public var updatedAt: Date
    public var items: [ZmanItem]
    public var locationSignature: String?

    public init(
        cityName: String,
        timeZoneID: String,
        latitude: Double,
        longitude: Double,
        updatedAt: Date,
        items: [ZmanItem],
        locationSignature: String? = nil
    ) {
        self.cityName = cityName
        self.timeZoneID = timeZoneID
        self.latitude = latitude
        self.longitude = longitude
        self.updatedAt = updatedAt
        self.items = items
        self.locationSignature = locationSignature
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
}
