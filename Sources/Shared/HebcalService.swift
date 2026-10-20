import CoreLocation
import Foundation
import os

enum HebcalService {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "HebcalService")

    static let definitions: [ZmanDefinition] = [
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

    struct Response: Decodable {
        let date: String
        let times: [String: String]
    }

    enum ServiceError: LocalizedError {
        case invalidURL
        case invalidResponse(Int)
        case emptyData

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return NSLocalizedString("error.invalid_url", comment: "")
            case .invalidResponse(let statusCode):
                return String(format: NSLocalizedString("error.invalid_response_format", comment: ""), statusCode)
            case .emptyData:
                return NSLocalizedString("error.empty_data", comment: "")
            }
        }
    }

    /// Fetches today and tomorrow immediately for quick UI display.
    static func fetchTodayAndTomorrow(
        location: CLLocation,
        timeZone: TimeZone,
        starting startDate: Date = Date()
    ) async throws -> [ZmanItem] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let day0 = startDate
        guard let day1 = cal.date(byAdding: .day, value: 1, to: startDate) else {
            return try await fetchDay(location: location, timeZone: timeZone, date: day0)
        }

        async let items0 = fetchDay(location: location, timeZone: timeZone, date: day0)
        async let items1 = fetchDay(location: location, timeZone: timeZone, date: day1)

        let combined = try await (items0 + items1)
        return combined.sorted { $0.date < $1.date }
    }

    /// Fetches multiple days: front-loads today and tomorrow, then fetches the remaining days concurrently.
    static func fetchDays(
        location: CLLocation,
        timeZone: TimeZone,
        starting startDate: Date = Date(),
        count: Int = 8
    ) async throws -> [ZmanItem] {
        guard count > 0 else { return [] }
        if count <= 2 {
            return try await fetchTodayAndTomorrow(location: location, timeZone: timeZone, starting: startDate)
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        // Front-load initial 2 days
        let initialItems = try await fetchTodayAndTomorrow(location: location, timeZone: timeZone, starting: startDate)

        // Fetch remaining days with bounded concurrency
        var remainingItems: [ZmanItem] = []
        try await withThrowingTaskGroup(of: [ZmanItem].self) { group in
            for offset in 2..<count {
                guard let day = cal.date(byAdding: .day, value: offset, to: startDate) else { continue }
                group.addTask {
                    try await fetchDay(location: location, timeZone: timeZone, date: day)
                }
            }
            for try await dayItems in group {
                remainingItems.append(contentsOf: dayItems)
            }
        }

        let all = initialItems + remainingItems
        return all.sorted { $0.date < $1.date }
    }

    static func fetchDay(
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
