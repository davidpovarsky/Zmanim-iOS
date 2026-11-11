import SwiftUI

public struct JewishCalendarCard: View {
    let events: [JewishCalendarEvent]
    let date: Date
    let timeZone: TimeZone

    @State private var showUpcoming = false

    public var body: some View {
        let relevant = visibleEvents
        if !relevant.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.zmanIndigo)
                    Text("הלוח העברי")
                        .font(.title3.bold())
                    Spacer()
                }

                VStack(spacing: 0) {
                    ForEach(relevant.prefix(2)) { event in
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: event.category))
                                .foregroundStyle(Color.zmanIndigo)
                                .frame(width: 28)
                            Text(event.displayTitle)
                                .font(.body.weight(.medium))
                            Spacer()
                            if let time = event.time {
                                Text(formattedDate(time, pattern: "HH:mm"))
                                    .monospacedDigit()
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    if events.count > 2 {
                        Button {
                            showUpcoming = true
                        } label: {
                            HStack {
                                Text("האירועים הקרובים")
                                Spacer()
                                Image(systemName: "chevron.left")
                            }
                            .foregroundStyle(Color.zmanIndigo)
                            .padding(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .zmanCard()
            }
            .sheet(isPresented: $showUpcoming) {
                NavigationStack {
                    List(events.filter { $0.date >= Calendar.current.startOfDay(for: date) }) { event in
                        HStack {
                            Text(event.displayTitle)
                            Spacer()
                            Text(formattedDate(event.date, pattern: "d MMM"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("הלוח העברי")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("סגור") { showUpcoming = false }
                        }
                    }
                }
            }
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
