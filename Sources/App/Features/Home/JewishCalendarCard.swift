import SwiftUI

public struct JewishCalendarCard: View {
    let events: [JewishCalendarEvent]
    let date: Date
    let timeZone: TimeZone

    public var body: some View {
        let relevant = visibleEvents
        if !relevant.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("הלוח העברי", systemImage: "calendar")
                    .font(.headline)
                ForEach(relevant) { event in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: icon(for: event.category))
                            .frame(width: 20)
                        Text(event.displayTitle)
                            .font(.subheadline)
                        Spacer(minLength: 4)
                        if let time = event.time {
                            Text(formattedDate(time, pattern: "HH:mm"))
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                }
                if events.count > relevant.count {
                    DisclosureGroup("האירועים הקרובים") {
                        ForEach(events.filter { $0.date >= date }.prefix(35)) { event in
                            HStack(spacing: 8) {
                                Text(event.displayTitle).lineLimit(2)
                                Spacer()
                                Text(formattedDate(event.date, pattern: "d MMM"))
                                    .font(.caption.monospacedDigit())
                            }
                            .font(.subheadline)
                            .padding(.vertical, 3)
                        }
                    }
                    .font(.subheadline)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .contain)
        }
    }

    private func formattedDate(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    private var visibleEvents: [JewishCalendarEvent] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return Array(events.filter { event in
            let eventDay = calendar.startOfDay(for: event.date)
            return eventDay == today || (eventDay == tomorrow && (event.category == "candles" || event.category == "havdalah"))
        }.prefix(8))
    }

    private func icon(for category: String) -> String {
        switch category {
        case "candles": "flame.fill"
        case "havdalah": "sparkles"
        case "parashat": "book.closed.fill"
        case "roshchodesh": "moon.stars.fill"
        case "omer": "number"
        case "holiday", "major", "minor", "fast": "calendar.badge.clock"
        default: "calendar"
        }
    }
}
