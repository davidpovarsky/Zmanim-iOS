import Foundation

struct ZmanItem: Identifiable, Codable, Hashable {
    let id: String
    let key: String
    let hebrewTitle: String
    let englishTitle: String
    let icon: String
    let date: Date
    init(key: String, hebrewTitle: String, englishTitle: String, icon: String, date: Date) {
        self.key = key; self.hebrewTitle = hebrewTitle; self.englishTitle = englishTitle; self.icon = icon; self.date = date
        self.id = "\(key)-\(Int(date.timeIntervalSince1970))"
    }
}

struct ZmanDefinition: Hashable { let key: String; let hebrewTitle: String; let englishTitle: String; let icon: String }
enum LocationMode: String, Codable, CaseIterable, Identifiable { case current, fixed; var id: String { rawValue }; var title: String { self == .current ? "המיקום הנוכחי" : "עיר קבועה" } }

struct NotificationRule: Identifiable, Codable, Hashable {
    var id: String; var zmanKey: String; var title: String; var offsetMinutes: Int; var isEnabled: Bool; var customName: String?
    init(id: String? = nil, zmanKey: String, title: String, offsetMinutes: Int = -15, isEnabled: Bool = false, customName: String? = nil) { self.id=id ?? zmanKey; self.zmanKey=zmanKey; self.title=title; self.offsetMinutes=offsetMinutes; self.isEnabled=isEnabled; self.customName=customName }
    var displayTitle: String { let s=customName?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""; return s.isEmpty ? title : s }
}

struct UserSettings: Codable, Hashable {
    var locationMode: LocationMode = .current; var fixedCity = ""; var shabbatMasterEnabled=false; var holidayMasterEnabled=false
    var rules: [NotificationRule] = Self.defaultRules
    static let defaultRules: [NotificationRule] = [
        .init(zmanKey:"alotHaShachar",title:"עלות השחר"), .init(zmanKey:"misheyakir",title:"משיכיר"), .init(zmanKey:"sunrise",title:"זריחה"),
        .init(zmanKey:"sofZmanShmaMGA",title:"סוף זמן ק״ש (מג״א)"), .init(zmanKey:"sofZmanShma",title:"סוף זמן ק״ש (גר״א)"), .init(zmanKey:"sofZmanTfilla",title:"סוף זמן תפילה"),
        .init(zmanKey:"chatzot",title:"חצות היום"), .init(zmanKey:"minchaGedola",title:"מנחה גדולה"), .init(zmanKey:"minchaKetana",title:"מנחה קטנה"), .init(zmanKey:"plagHaMincha",title:"פלג המנחה"),
        .init(zmanKey:"sunset",title:"שקיעה"), .init(zmanKey:"tzeit7083deg",title:"צאת הכוכבים"), .init(zmanKey:"tzeitRT",title:"צאת הכוכבים (רבנו תם)"), .init(zmanKey:"candleLighting",title:"כניסת שבת")]
}

struct ZmanSnapshot: Codable, Hashable { var cityName:String; var timeZoneID:String; var latitude:Double; var longitude:Double; var updatedAt:Date; var items:[ZmanItem]; var timeZone:TimeZone { TimeZone(identifier:timeZoneID) ?? .current } }
