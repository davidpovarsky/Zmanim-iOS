import CoreLocation
import Foundation
import os

public enum HebcalService {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "HebcalService")

    public static let definitions: [ZmanDefinition] = [
        .init(key: "alotHaShachar", hebrewTitle: "עלות השחר", englishTitle: "Alot HaShachar", icon: "moon.stars.fill"),
        .init(key: "misheyakir", hebrewTitle: "משיכיר", englishTitle: "Misheyakir", icon: "eye.fill"),
        .init(key: "sunrise", hebrewTitle: "הנץ החמה", englishTitle: "Sunrise", icon: "sunrise.fill"),
        .init(key: "sofZmanShmaMGA", hebrewTitle: "סוף זמן ק״ש מג״א", englishTitle: "Latest Shema · MGA", icon: "book.closed.fill"),
        .init(key: "sofZmanShma", hebrewTitle: "סוף זמן ק״ש גר״א", englishTitle: "Latest Shema · Gra", icon: "book.closed.fill"),
        .init(key: "sofZmanTfilla", hebrewTitle: "סוף זמן תפילה", englishTitle: "Latest Shacharit", icon: "clock.fill"),
        .init(key: "chatzot", hebrewTitle: "חצות היום", englishTitle: "Chatzot", icon: "sun.max.fill"),
        .init(key: "minchaGedola", hebrewTitle: "מנחה גדולה", englishTitle: "Mincha Gedola", icon: "sun.haze.fill"),
        .init(key: "minchaKetana", hebrewTitle: "מנחה קטנה", englishTitle: "Mincha Ketana", icon: "sun.haze.fill"),
        .init(key: "plagHaMincha", hebrewTitle: "פלג המנחה", englishTitle: "Plag HaMincha", icon: "sunset.fill"),
        .init(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill"),
        .init(key: "tzeit7083deg", hebrewTitle: "צאת הכוכבים", englishTitle: "Tzeit 7.083°", icon: "moon.fill"),
        .init(key: "candleLighting", hebrewTitle: "כניסת שבת", englishTitle: "Candle Lighting", icon: "flame.fill")
    ]

    public struct Response: Decodable {
        public let date: String
        public let times: [String: String]
    }

    public enum ServiceError: LocalizedError {
        case invalidURL
        case invalidResponse(Int)
        case emptyData

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "לא ניתן ליצור בקשה ל-Hebcal."
            case .invalidResponse(let statusCode):
                return "Hebcal החזיר שגיאה \(statusCode)."
            case .emptyData:
                return "לא התקבלו נתונים מ-Hebcal."
            }
        }
    }

    public static func fetchDays(
        location: CLLocation,
        timeZone: TimeZone,
        starting startDate: Date = Date(),
        count: Int = 8
    ) async throws -> [ZmanItem] {
        var all: [ZmanItem] = []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        for offset in 0..<count {
            guard let day = cal.date(byAdding: .day, value: offset, to: startDate) else { continue }
            all += try await fetchDay(location: location, timeZone: timeZone, date: day)
        }
        return all.sorted { $0.date < $1.date }
    }

    public static func fetchDay(
        location: CLLocation,
        timeZone: TimeZone,
        date: Date
    ) async throws -> [ZmanItem] {
        var c = URLComponents(string: "https://www.hebcal.com/zmanim")
        c?.queryItems = [
            .init(name: "cfg", value: "json"),
            .init(name: "latitude", value: String(format: "%.6f", location.coordinate.latitude)),
            .init(name: "longitude", value: String(format: "%.6f", location.coordinate.longitude)),
            .init(name: "tzid", value: timeZone.identifier),
            .init(name: "date", value: apiDate(date, timeZone: timeZone)),
            .init(name: "sec", value: "1")
        ]
        guard let url = c?.url else {
            #if DEBUG
            logger.error("Failed to construct Hebcal URL")
            #endif
            throw ServiceError.invalidURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            #if DEBUG
            logger.error("Hebcal request failed: \(error.localizedDescription, privacy: .public)")
            #endif
            throw error
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            #if DEBUG
            logger.error("Hebcal HTTP error status: \(status)")
            #endif
            throw ServiceError.invalidResponse(status)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let parser = ISO8601DateFormatter()
        var items: [ZmanItem] = definitions.compactMap { d in
            guard let raw = decoded.times[d.key], let itemDate = parser.date(from: raw) else { return nil }
            return ZmanItem(key: d.key, hebrewTitle: d.hebrewTitle, englishTitle: d.englishTitle, icon: d.icon, date: itemDate)
        }

        if let sunset = items.first(where: { $0.key == "sunset" })?.date {
            items.append(ZmanItem(
                key: "tzeitRT",
                hebrewTitle: "צאת הכוכבים (רבנו תם)",
                englishTitle: "Rabbeinu Tam · 72 min",
                icon: "moon.stars.fill",
                date: sunset.addingTimeInterval(4320)
            ))
        }

        let sorted = items.sorted { $0.date < $1.date }
        #if DEBUG
        logger.debug("Successfully parsed \(sorted.count) zmanim for date \(apiDate(date, timeZone: timeZone), privacy: .public)")
        #endif
        return sorted
    }

    private static func apiDate(_ date: Date, timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
