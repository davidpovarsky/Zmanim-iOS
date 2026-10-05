import Foundation

enum AppGroupStore {
    static let groupID="group.com.davidpovarsky.zmanim"
    private static var defaults:UserDefaults { UserDefaults(suiteName:groupID) ?? .standard }
    static func loadSettings()->UserSettings { guard let d=defaults.data(forKey:"settings"), let v=try? JSONDecoder().decode(UserSettings.self,from:d) else { return UserSettings() }; return v }
    static func saveSettings(_ v:UserSettings){ if let d=try? JSONEncoder().encode(v){ defaults.set(d,forKey:"settings") } }
    static func loadSnapshot()->ZmanSnapshot? { guard let d=defaults.data(forKey:"snapshot"), let v=try? JSONDecoder().decode(ZmanSnapshot.self,from:d) else{return nil}; return v }
    static func saveSnapshot(_ v:ZmanSnapshot){ if let d=try? JSONEncoder().encode(v){defaults.set(d,forKey:"snapshot")} }
    static var quickReminderEnabled:Bool { get{defaults.bool(forKey:"quickReminder")} set{defaults.set(newValue,forKey:"quickReminder")} }
}
