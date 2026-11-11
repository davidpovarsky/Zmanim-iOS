import Foundation
import CoreLocation

public struct JewishCalendarEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let hebrewTitle: String?
    public let category: String
    public let subcategory: String?
    public let date: Date
    public let time: Date?
    public let memo: String?
    public var displayTitle: String {
        Locale.autoupdatingCurrent.language.languageCode?.identifier == "he" ? (hebrewTitle ?? title) : title
    }
}

public enum JewishCalendarService {
    private struct Feed: Decodable {
        let items: [Event]
    }
    private struct Event: Decodable {
        let title: String
        let hebrew: String?
        let date: String
        let category: String
        let subcat: String?
        let memo: String?
    }

    public static func fetch(location: CLLocation, timeZone: TimeZone, start: Date = Date(), days: Int = 35, israel: Bool) async throws -> [JewishCalendarEvent] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let end = cal.date(byAdding: .day, value: max(1, days), to: start) ?? start
        var components = URLComponents(string: "https://www.hebcal.com/hebcal")!
        components.queryItems = [
            .init(name: "cfg", value: "json"),
            .init(name: "v", value: "1"),
            .init(name: "start", value: formatter.string(from: start)),
            .init(name: "end", value: formatter.string(from: end)),
            .init(name: "latitude", value: String(location.coordinate.latitude)),
            .init(name: "longitude", value: String(location.coordinate.longitude)),
            .init(name: "tzid", value: timeZone.identifier),
            .init(name: "i", value: israel ? "on" : "off"),
            .init(name: "c", value: "on"),
            .init(name: "b", value: "18"),
            .init(name: "M", value: "on"),
            .init(name: "s", value: "on"),
            .init(name: "maj", value: "on"),
            .init(name: "min", value: "on"),
            .init(name: "mod", value: "on"),
            .init(name: "nx", value: "on"),
            .init(name: "mf", value: "on"),
            .init(name: "ss", value: "on"),
            .init(name: "o", value: "on"),
            .init(name: "leyning", value: "off")
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decodeEvents(data, timeZone: timeZone)
    }

    public static func decodeEvents(_ data: Data, timeZone: TimeZone) throws -> [JewishCalendarEvent] {
        let feed = try JSONDecoder().decode(Feed.self, from: data)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let iso = ISO8601DateFormatter()
        return feed.items.compactMap { event in
            let moment = iso.date(from: event.date)
            let day = moment ?? formatter.date(from: String(event.date.prefix(10)))
            guard let day else { return nil }
            return JewishCalendarEvent(
                id: event.category + ":" + event.date + ":" + event.title,
                title: event.title,
                hebrewTitle: event.hebrew,
                category: event.category,
                subcategory: event.subcat,
                date: day,
                time: moment,
                memo: event.memo
            )
        }.sorted { $0.date < $1.date }
    }

    public static func timedItems(from events: [JewishCalendarEvent]) -> [ZmanItem] {
        events.compactMap { event in
            guard let time = event.time else { return nil }
            switch event.category {
            case "candles":
                return ZmanItem(key: "candleLighting", hebrewTitle: event.hebrewTitle ?? "הדלקת נרות", englishTitle: event.title, icon: "flame.fill", date: time)
            case "havdalah":
                return ZmanItem(key: "havdalah", hebrewTitle: event.hebrewTitle ?? "הבדלה", englishTitle: event.title, icon: "sparkles", date: time)
            case "zmanim":
                let key = event.subcategory == "fast"
                    ? (event.title.lowercased().contains("begins") ? "fastStart" : "fastEnd")
                    : (event.subcategory ?? "calendarZman")
                return ZmanItem(key: key, hebrewTitle: event.hebrewTitle ?? event.title, englishTitle: event.title, icon: "clock", date: time)
            default:
                return nil
            }
        }
    }
}
