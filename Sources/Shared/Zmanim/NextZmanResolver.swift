import Foundation

public struct NextZmanResult: Equatable, Sendable {
    public let item: ZmanItem
    public let isTomorrow: Bool
    public let dayLabel: String?

    public init(item: ZmanItem, isTomorrow: Bool, dayLabel: String?) {
        self.item = item
        self.isTomorrow = isTomorrow
        self.dayLabel = dayLabel
    }
}

public enum NextZmanResolver {
    /// Finds the earliest upcoming zman from `allItems` after `now`.
    /// Accurately flags whether the zman occurs tomorrow or on a later local day in `timeZone`.
    public static func resolve(
        allItems: [ZmanItem],
        now: Date,
        timeZone: TimeZone,
        locale: Locale = .autoupdatingCurrent
    ) -> NextZmanResult? {
        let sorted = allItems.sorted { $0.date < $1.date }
        guard let nextItem = sorted.first(where: { $0.date > now }) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        if calendar.isDate(nextItem.date, inSameDayAs: now) {
            return NextZmanResult(item: nextItem, isTomorrow: false, dayLabel: nil)
        }

        let isEnglish = (locale.language.languageCode?.identifier ?? (locale.identifier.hasPrefix("en") ? "en" : "he")) == "en"
        let tomorrowLabel = isEnglish ? "Tomorrow" : "מחר"

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(nextItem.date, inSameDayAs: tomorrow) {
            return NextZmanResult(item: nextItem, isTomorrow: true, dayLabel: tomorrowLabel)
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = locale
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: nextItem.date)
        return NextZmanResult(item: nextItem, isTomorrow: true, dayLabel: dayName)
    }
}
