import Foundation

/// Item wrapper indicating whether a zman belongs to today or is overflowing to tomorrow/future.
public struct UpcomingZmanItem: Identifiable, Sendable, Equatable {
    public let item: ZmanItem
    public let isTomorrow: Bool
    public let dayLabel: String?

    public var id: String {
        "\(item.id)-\(isTomorrow ? "tomorrow" : "today")"
    }

    public init(item: ZmanItem, isTomorrow: Bool, dayLabel: String?) {
        self.item = item
        self.isTomorrow = isTomorrow
        self.dayLabel = dayLabel
    }
}

/// Pure logic pager that partitions upcoming zmanim starting strictly from `referenceDate` (now).
/// Past morning zmanim are excluded from the initial page.
/// If fewer than 5 zmanim remain today, continues seamlessly to tomorrow's zmanim with a localized "מחר" / "Tomorrow" label.
public struct UpcomingZmanPager: Sendable {
    public let allUpcomingItems: [UpcomingZmanItem]
    public let pageSize: Int
    public let pageCount: Int
    public let referenceDate: Date
    public let timeZone: TimeZone
    public let sunrise: Date?
    public let sunset: Date?

    public init(
        allItems: [ZmanItem],
        referenceDate: Date,
        timeZone: TimeZone,
        pageSize: Int = 5,
        locale: Locale = .autoupdatingCurrent
    ) {
        self.pageSize = max(1, pageSize)
        self.referenceDate = referenceDate
        self.timeZone = timeZone

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let isEnglish = (locale.language.languageCode?.identifier ?? (locale.identifier.hasPrefix("en") ? "en" : "he")) == "en"
        let tomorrowLabel = isEnglish ? "Tomorrow" : "מחר"

        let todayItems = ZmanDayResolver.itemsForDay(from: allItems, date: referenceDate, timeZone: timeZone)
        self.sunrise = todayItems.first { $0.key == "sunrise" }?.date
        self.sunset = todayItems.first { $0.key == "sunset" }?.date

        // Filter upcoming items for today (date >= referenceDate)
        let upcomingToday = todayItems.filter { $0.date >= referenceDate }.sorted { $0.date < $1.date }

        var collected: [UpcomingZmanItem] = []
        for item in upcomingToday {
            collected.append(UpcomingZmanItem(item: item, isTomorrow: false, dayLabel: nil))
        }

        // Add tomorrow's zmanim
        if let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: referenceDate) {
            let tomorrowItems = ZmanDayResolver.itemsForDay(from: allItems, date: tomorrowDate, timeZone: timeZone).sorted { $0.date < $1.date }
            for item in tomorrowItems {
                collected.append(UpcomingZmanItem(item: item, isTomorrow: true, dayLabel: tomorrowLabel))
            }
        }

        // Fallback for multi-day gaps if needed
        if collected.isEmpty {
            let futureItems = allItems.filter { $0.date >= referenceDate }.sorted { $0.date < $1.date }
            for item in futureItems {
                let isTom = !calendar.isDate(item.date, inSameDayAs: referenceDate)
                collected.append(UpcomingZmanItem(item: item, isTomorrow: isTom, dayLabel: isTom ? tomorrowLabel : nil))
            }
        }

        self.allUpcomingItems = collected
        let count = collected.count
        self.pageCount = count == 0 ? 1 : Int(ceil(Double(count) / Double(pageSize)))
    }

    /// Returns the 5 items for `pageIndex` with cyclic wrap-around.
    public func items(for pageIndex: Int) -> [UpcomingZmanItem] {
        guard !allUpcomingItems.isEmpty, pageCount > 0 else { return [] }
        let safeIndex = ((pageIndex % pageCount) + pageCount) % pageCount
        let start = safeIndex * pageSize
        let end = min(start + pageSize, allUpcomingItems.count)
        guard start < allUpcomingItems.count else { return [] }
        return Array(allUpcomingItems[start..<end])
    }
}
