import SwiftUI

/// Timed calendar events live directly below the next-zman card.
public struct SpecialDayTimesCard: View {
    let events: [JewishCalendarEvent]
    let date: Date
    let timeZone: TimeZone

    private var relevant: [JewishCalendarEvent] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return events.filter { event in
            guard let time = event.time else { return false }
            let isRelevantCategory = ["candles", "havdalah"].contains(event.category)
                || event.category == "zmanim" && (event.subcategory == "fast"
                    || event.title.lowercased().contains("fast"))
            guard isRelevantCategory else { return false }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                               to: calendar.startOfDay(for: time)).day ?? -1
            return (0...1).contains(days)
        }.sorted { ($0.time ?? .distantFuture) < ($1.time ?? .distantFuture) }
    }

    public var body: some View {
        if !relevant.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(relevant) { event in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: event))
                            .font(.title3)
                            .foregroundStyle(Color.zmanIndigo)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.displayTitle)
                                .font(.headline)
                            if !isToday(event.date) {
                                Text(dateLabel(event.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let time = event.time {
                            Text(clock(time))
                                .font(.title3.monospacedDigit().weight(.semibold))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .zmanCard()
        }
    }

    private func isToday(_ value: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.isDate(value, inSameDayAs: date)
    }

    private func icon(for event: JewishCalendarEvent) -> String {
        switch event.category {
        case "candles": return "flame.fill"
        case "havdalah": return "sparkles"
        default: return "clock"
        }
    }

    private func clock(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: value)
    }

    private func dateLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        return formatter.string(from: value)
    }
}