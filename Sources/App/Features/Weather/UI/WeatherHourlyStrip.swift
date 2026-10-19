import SwiftUI

public struct WeatherHourlyStrip: View {
    public let entries: [WeatherPresentation.HourlyItem]

    public init(entries: [WeatherPresentation.HourlyItem]) {
        self.entries = entries
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 18) {
                ForEach(entries) { entry in
                    VStack(spacing: 6) {
                        Text(entry.timeLabel)
                            .font(.caption)
                            .fontWeight(entry.isNow ? .bold : .regular)
                            .foregroundStyle(entry.isNow ? Color.primary : Color.secondary)

                        Image(systemName: METSymbolMapper.systemImageName(for: entry.iconName))
                            .font(.system(size: 22))
                            .foregroundStyle(entry.isNow ? Color.zmanOrange : Color.secondary)

                        Text(entry.temp)
                            .font(.subheadline)
                            .fontWeight(entry.isNow ? .bold : .regular)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(entry.timeLabel), \(entry.temp)")
                }
            }
            .padding(.horizontal, 16)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
