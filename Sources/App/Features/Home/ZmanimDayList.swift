import SwiftUI

public struct ZmanimDayList: View {
    public let items: [ZmanItem]
    public let now: Date
    public let timeZone: TimeZone

    public init(items: [ZmanItem], now: Date, timeZone: TimeZone) {
        self.items = items
        self.now = now
        self.timeZone = timeZone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("זמני היום").font(.title3.bold())

            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack {
                        Image(systemName: item.icon)
                            .foregroundStyle(item.date > now ? Color.zmanIndigo : Color.secondary)
                            .frame(width: 28)

                        VStack(alignment: .leading) {
                            Text(item.hebrewTitle).font(.body.weight(.medium))
                            Text(item.englishTitle).font(.caption2).foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(formatTime(item.date))
                            .monospacedDigit()
                            .font(.body.weight(.semibold))
                    }
                    .opacity(item.date < now ? 0.48 : 1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if item.id != items.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .zmanCard()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
