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

public enum LocalizationBundleHelper {
    public static func bundle(forLanguage lang: String) -> Bundle? {
        let cleanLang = lang.components(separatedBy: "_").first ?? lang
        let bundles = Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let path = bundle.path(forResource: cleanLang, ofType: "lproj"),
               let langBundle = Bundle(path: path) {
                return langBundle
            }
        }
        if let path = Bundle.main.path(forResource: cleanLang, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return langBundle
        }
        return nil
    }
}

public enum LocationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case current, fixed
    public var id: String { rawValue }

    public func localizedTitle(locale: Locale = .autoupdatingCurrent) -> String {
        let isEnglish = (locale.language.languageCode?.identifier ?? (locale.identifier.hasPrefix("en") ? "en" : "he")) == "en"
        switch self {
        case .current:
            return isEnglish ? "Current Location" : "המיקום הנוכחי"
        case .fixed:
            return isEnglish ? "Fixed City" : "עיר קבועה"
        }
    }

    public var title: String {
        localizedTitle()
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

public enum LocationSource: String, Codable, Hashable, Sendable {
    case gps
    case fixedSearch
}

public struct ResolvedLocation: Codable, Hashable, Sendable {
    public var displayName: String
    public var latitude: Double
    public var longitude: Double
    public var timeZoneID: String
    public var source: LocationSource

    public init(
        displayName: String,
        latitude: Double,
        longitude: Double,
        timeZoneID: String,
        source: LocationSource
    ) {
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneID = timeZoneID
        self.source = source
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
}

public struct UserSettings: Codable, Hashable, Sendable {
    public var locationMode: LocationMode = .current
    public var fixedCity = ""
    public var resolvedFixedLocation: ResolvedLocation? = nil
    public var specialDaysMasterEnabled = false
    public var shabbatEnabled = false
    public var holidayEnabled = false
    public var rules: [NotificationRule] = Self.defaultRules

    public var shabbatMasterEnabled: Bool {
        get { specialDaysMasterEnabled && shabbatEnabled }
        set {
            specialDaysMasterEnabled = newValue
            shabbatEnabled = newValue
        }
    }

    public var holidayMasterEnabled: Bool {
        get { holidayEnabled }
        set { holidayEnabled = newValue }
    }

    public init(
        locationMode: LocationMode = .current,
        fixedCity: String = "",
        resolvedFixedLocation: ResolvedLocation? = nil,
        specialDaysMasterEnabled: Bool = false,
        shabbatEnabled: Bool = false,
        holidayEnabled: Bool = false,
        rules: [NotificationRule] = Self.defaultRules
    ) {
        self.locationMode = locationMode
        self.fixedCity = fixedCity
        self.resolvedFixedLocation = resolvedFixedLocation
        self.specialDaysMasterEnabled = specialDaysMasterEnabled
        self.shabbatEnabled = shabbatEnabled
        self.holidayEnabled = holidayEnabled
        self.rules = rules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        locationMode = try container.decodeIfPresent(LocationMode.self, forKey: .locationMode) ?? .current
        fixedCity = try container.decodeIfPresent(String.self, forKey: .fixedCity) ?? ""
        resolvedFixedLocation = try container.decodeIfPresent(ResolvedLocation.self, forKey: .resolvedFixedLocation)
        rules = try container.decodeIfPresent([NotificationRule].self, forKey: .rules) ?? Self.defaultRules

        if let special = try container.decodeIfPresent(Bool.self, forKey: .specialDaysMasterEnabled) {
            specialDaysMasterEnabled = special
            shabbatEnabled = try container.decodeIfPresent(Bool.self, forKey: .shabbatEnabled) ?? special
            holidayEnabled = try container.decodeIfPresent(Bool.self, forKey: .holidayEnabled) ?? false
        } else {
            // Backward-compatibility migration from legacy shabbatMasterEnabled / holidayMasterEnabled
            let legacyShabbat = try container.decodeIfPresent(Bool.self, forKey: .shabbatMasterLegacy) ?? false
            let legacyHoliday = try container.decodeIfPresent(Bool.self, forKey: .holidayMasterLegacy) ?? false
            specialDaysMasterEnabled = legacyShabbat || legacyHoliday
            shabbatEnabled = legacyShabbat
            holidayEnabled = legacyHoliday
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(locationMode, forKey: .locationMode)
        try container.encode(fixedCity, forKey: .fixedCity)
        try container.encodeIfPresent(resolvedFixedLocation, forKey: .resolvedFixedLocation)
        try container.encode(specialDaysMasterEnabled, forKey: .specialDaysMasterEnabled)
        try container.encode(shabbatEnabled, forKey: .shabbatEnabled)
        try container.encode(holidayEnabled, forKey: .holidayEnabled)
        try container.encode(rules, forKey: .rules)
        // Also write legacy keys for backward-compatible readers
        try container.encode(shabbatMasterEnabled, forKey: .shabbatMasterLegacy)
        try container.encode(holidayMasterEnabled, forKey: .holidayMasterLegacy)
    }

    private enum CodingKeys: String, CodingKey {
        case locationMode
        case fixedCity
        case resolvedFixedLocation
        case specialDaysMasterEnabled
        case shabbatEnabled
        case holidayEnabled
        case rules
        case shabbatMasterLegacy = "shabbatMasterEnabled"
        case holidayMasterLegacy = "holidayMasterEnabled"
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
    public var sourceIdentity: LocationIdentity?
    public var schemaVersion: Int
    public var coverageStart: Date?
    public var coverageEnd: Date?

    public init(
        cityName: String,
        timeZoneID: String,
        latitude: Double,
        longitude: Double,
        updatedAt: Date,
        items: [ZmanItem],
        locationSignature: String? = nil,
        sourceIdentity: LocationIdentity? = nil,
        schemaVersion: Int = 1,
        coverageStart: Date? = nil,
        coverageEnd: Date? = nil
    ) {
        self.cityName = cityName
        self.timeZoneID = timeZoneID
        self.latitude = latitude
        self.longitude = longitude
        self.updatedAt = updatedAt
        self.items = items
        self.locationSignature = locationSignature
        self.sourceIdentity = sourceIdentity
        self.schemaVersion = schemaVersion
        self.coverageStart = coverageStart ?? items.first?.date
        self.coverageEnd = coverageEnd ?? items.last?.date
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.cityName = try container.decodeIfPresent(String.self, forKey: .cityName) ?? ""
        self.timeZoneID = try container.decode(String.self, forKey: .timeZoneID)
        self.latitude = try container.decode(Double.self, forKey: .latitude)
        self.longitude = try container.decode(Double.self, forKey: .longitude)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.items = try container.decode([ZmanItem].self, forKey: .items)
        self.locationSignature = try container.decodeIfPresent(String.self, forKey: .locationSignature)
        self.sourceIdentity = try container.decodeIfPresent(LocationIdentity.self, forKey: .sourceIdentity)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.coverageStart = try container.decodeIfPresent(Date.self, forKey: .coverageStart) ?? items.first?.date
        self.coverageEnd = try container.decodeIfPresent(Date.self, forKey: .coverageEnd) ?? items.last?.date
    }

    private enum CodingKeys: String, CodingKey {
        case cityName
        case timeZoneID
        case latitude
        case longitude
        case updatedAt
        case items
        case locationSignature
        case sourceIdentity
        case schemaVersion
        case coverageStart
        case coverageEnd
    }

    public var validTimeZone: TimeZone? { TimeZone(identifier: timeZoneID) }
    public var timeZone: TimeZone { validTimeZone ?? .current }
}
