import Foundation

/// Resolves the zmanim items belonging to a specific calendar day in a given time zone.
public enum ZmanDayResolver {
    /// Filters and sorts zmanim for the local calendar day of `date` in `timeZone`.
    public static func itemsForDay(
        from allItems: [ZmanItem],
        date: Date,
        timeZone: TimeZone
    ) -> [ZmanItem] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let dayItems = allItems.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let sorted = dayItems.sorted { $0.date < $1.date }

        // Deduplicate items with identical keys for the same day
        var seenKeys = Set<String>()
        var unique: [ZmanItem] = []
        for item in sorted {
            if !seenKeys.contains(item.key) {
                seenKeys.insert(item.key)
                unique.append(item)
            }
        }
        return unique
    }

    /// Finds the sunrise date for the given day in `timeZone`.
    public static func sunrise(from items: [ZmanItem], date: Date, timeZone: TimeZone) -> Date? {
        itemsForDay(from: items, date: date, timeZone: timeZone).first { $0.key == "sunrise" }?.date
    }

    /// Finds the sunset date for the given day in `timeZone`.
    public static func sunset(from items: [ZmanItem], date: Date, timeZone: TimeZone) -> Date? {
        itemsForDay(from: items, date: date, timeZone: timeZone).first { $0.key == "sunset" }?.date
    }
}
