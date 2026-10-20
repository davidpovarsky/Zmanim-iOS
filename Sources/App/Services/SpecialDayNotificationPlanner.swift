import Foundation

public struct ScheduledSpecialNotification: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let body: String
    public let fireDate: Date
    public let icon: String

    public init(id: String, title: String, body: String, fireDate: Date, icon: String) {
        self.id = id
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.icon = icon
    }
}

public enum SpecialDayNotificationPlanner {
    /// Pure, verified planning of special days notifications (Shabbat & Holidays).
    /// Does not guess or fabricate halachic times.
    public static func plan(
        settings: UserSettings,
        items: [ZmanItem],
        timeZone: TimeZone,
        now: Date
    ) -> [ScheduledSpecialNotification] {
        guard settings.specialDaysMasterEnabled else { return [] }

        var results: [ScheduledSpecialNotification] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"

        // MARK: - 1. Shabbat Notifications
        if settings.shabbatEnabled {
            // Candle lighting (Erev Shabbat / Friday)
            let candleItems = items.filter { item in
                item.key == "candleLighting" && item.date > now.addingTimeInterval(2)
            }

            for item in candleItems {
                let weekday = calendar.component(.weekday, from: item.date)
                // In Jewish calendar, Friday is weekday 6
                if weekday == 6 {
                    let formattedTime = timeFormatter.string(from: item.date)
                    let body = String(
                        format: NSLocalizedString("notification.shabbat_candle_body", value: "כניסת שבת בשעה %@", comment: ""),
                        formattedTime
                    )
                    results.append(ScheduledSpecialNotification(
                        id: "zmanim.special.shabbat.candle.\(Int(item.date.timeIntervalSince1970))",
                        title: NSLocalizedString("settings.shabbat", value: "כניסת שבת", comment: ""),
                        body: body,
                        fireDate: item.date,
                        icon: "flame.fill"
                    ))
                }
            }

            // Havdalah / Shabbat Exit (Saturday evening)
            let saturdayItems = items.filter { item in
                let weekday = calendar.component(.weekday, from: item.date)
                return weekday == 7 && item.date > now.addingTimeInterval(2)
            }

            // Use verified tzeit7083deg as standard Motzei Shabbat
            let havdalahCandidates = saturdayItems.filter { $0.key == "tzeit7083deg" }
            for item in havdalahCandidates {
                let formattedTime = timeFormatter.string(from: item.date)
                let body = String(
                    format: NSLocalizedString("notification.shabbat_exit_body", value: "צאת שבת בשעה %@", comment: ""),
                    formattedTime
                )
                results.append(ScheduledSpecialNotification(
                    id: "zmanim.special.shabbat.havdalah.\(Int(item.date.timeIntervalSince1970))",
                    title: NSLocalizedString("notification.shabbat_exit", value: "מוצאי שבת", comment: ""),
                    body: body,
                    fireDate: item.date,
                    icon: "sparkles"
                ))
            }
        }

        // MARK: - 2. Holiday Notifications
        if settings.holidayEnabled {
            // Holiday candle lighting (weekday other than Friday)
            let holidayCandleItems = items.filter { item in
                let weekday = calendar.component(.weekday, from: item.date)
                return item.key == "candleLighting" && weekday != 6 && item.date > now.addingTimeInterval(2)
            }

            for item in holidayCandleItems {
                let formattedTime = timeFormatter.string(from: item.date)
                let body = String(
                    format: NSLocalizedString("notification.holiday_candle_body", value: "כניסת החג בשעה %@", comment: ""),
                    formattedTime
                )
                results.append(ScheduledSpecialNotification(
                    id: "zmanim.special.holiday.candle.\(Int(item.date.timeIntervalSince1970))",
                    title: NSLocalizedString("settings.holidays_fasts", value: "כניסת החג", comment: ""),
                    body: body,
                    fireDate: item.date,
                    icon: "flame.fill"
                ))
            }
        }

        return results.sorted { $0.fireDate < $1.fireDate }
    }
}
