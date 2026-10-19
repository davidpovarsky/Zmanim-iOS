import SwiftUI

public struct NextZmanCard: View {
    public let result: NextZmanResult?
    public let isLoading: Bool
    public let errorMessage: String?
    public let timeZone: TimeZone

    public init(
        result: NextZmanResult?,
        isLoading: Bool,
        errorMessage: String?,
        timeZone: TimeZone
    ) {
        self.result = result
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.timeZone = timeZone
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
                        Text("הזמן הבא")
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

                    Text(item.hebrewTitle)
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(item.date))
                        .font(.title2.monospacedDigit().bold())
                    Text(item.date, style: .relative)
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
            Text(errorMessage ?? "אין נתוני זמנים זמינים")
                .frame(maxWidth: .infinity)
                .padding(22)
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
