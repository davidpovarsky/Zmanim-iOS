import SwiftUI

public struct WeatherStatsRow: View {
    public let stats: WeatherPresentation.Stats

    public init(stats: WeatherPresentation.Stats) {
        self.stats = stats
    }

    public var body: some View {
        HStack {
            statItem(
                systemImage: "wind",
                tint: .secondary,
                value: stats.windText,
                label: "מהירות רוח"
            )

            Spacer()

            if let precip = stats.precipText {
                statItem(
                    systemImage: "drop.fill",
                    tint: .blue,
                    value: precip,
                    label: "סיכוי למשקעים"
                )
                Spacer()
            }

            statItem(
                systemImage: "thermometer.medium",
                tint: .orange,
                value: stats.feelsLikeText ?? "לא זמין",
                label: "מרגיש כמו"
            )
        }
    }

    private func statItem(
        systemImage: String,
        tint: Color,
        value: String,
        label: String
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
