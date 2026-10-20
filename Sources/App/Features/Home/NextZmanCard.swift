import SwiftUI

public struct NextZmanCard: View {
    public let result: NextZmanResult?
    public let isLoading: Bool
    public let errorMessage: String?
    public let timeZone: TimeZone
    public let now: Date

    public init(
        result: NextZmanResult?,
        isLoading: Bool,
        errorMessage: String?,
        timeZone: TimeZone,
        now: Date = Date()
    ) {
        self.result = result
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.timeZone = timeZone
        self.now = now
    }

    public var body: some View {
        if let result {
            let item = result.item
            HStack(spacing: 14) {
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundStyle(Color.zmanOrange)
                    .frame(width: 48, height: 48)
                    .background(Color.zmanOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("next_zman")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let dayLabel = result.dayLabel {
                            Text(dayLabel)
                                .font(.caption2.bold())
                                .foregroundStyle(Color.zmanOrange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.zmanOrange.opacity(0.15), in: Capsule())
                        }
                    }

                    Text(item.displayTitle)
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(item.date))
                        .font(.title2.monospacedDigit().bold())
                    Text(formatRemaining(to: item.date, from: now))
                        .font(.caption)
                        .foregroundStyle(Color.zmanOrange)
                }
            }
            .padding(18)
            .zmanCard()
        } else if isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .padding(20)
                Spacer()
            }
            .zmanCard()
        } else {
            Text(errorMessage ?? NSLocalizedString("no_zmanim_data", comment: ""))
                .frame(maxWidth: .infinity)
                .padding(22)
                .zmanCard()
        }
    }

    private func formatRemaining(to target: Date, from current: Date) -> String {
        let diff = target.timeIntervalSince(current)
        guard diff > 0 else { return NSLocalizedString("remaining.now", value: "עכשיו", comment: "") }
        let totalMinutes = Int(ceil(diff / 60.0))
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours == 0 {
            return String(format: NSLocalizedString("remaining.minutes_format", value: "בעוד %d דק׳", comment: ""), mins)
        } else if mins == 0 {
            return String(format: NSLocalizedString("remaining.hours_format", value: "בעוד %d שעות", comment: ""), hours)
        } else {
            return String(format: NSLocalizedString("remaining.hours_minutes_format", value: "בעוד %1$d שעות ו-%2$d דק׳", comment: ""), hours, mins)
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
