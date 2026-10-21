import Foundation

/// Pure logic selector for day items and 5-item page partitions in widgets.
public struct WidgetDaySelector: Sendable {
    public let dayItems: [ZmanItem]
    public let pageSize: Int
    public let pageCount: Int
    public let sunrise: Date?
    public let sunset: Date?

    public init(
        allItems: [ZmanItem],
        referenceDate: Date,
        timeZone: TimeZone,
        pageSize: Int = 5
    ) {
        let items = ZmanDayResolver.itemsForDay(from: allItems, date: referenceDate, timeZone: timeZone)
        self.dayItems = items
        self.pageSize = max(1, pageSize)
        let count = items.count
        self.pageCount = count == 0 ? 1 : Int(ceil(Double(count) / Double(pageSize)))
        self.sunrise = items.first { $0.key == "sunrise" }?.date
        self.sunset = items.first { $0.key == "sunset" }?.date
    }

    /// Returns the items belonging to `pageIndex` (0-indexed).
    public func items(for pageIndex: Int) -> [ZmanItem] {
        guard !dayItems.isEmpty, pageIndex >= 0, pageIndex < pageCount else { return [] }
        let start = pageIndex * pageSize
        let end = min(start + pageSize, dayItems.count)
        guard start < dayItems.count else { return [] }
        return Array(dayItems[start..<end])
    }
}
