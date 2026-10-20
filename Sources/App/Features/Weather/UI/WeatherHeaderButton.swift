import SwiftUI
import OneBusAwayWeatherCore
import OneBusAwayWeatherUI

public struct WeatherHeaderButton: View {
    public let cityName: String
    public let display: WeatherDisplay?
    public let textColor: Color
    public let action: () -> Void

    public init(
        cityName: String,
        display: WeatherDisplay?,
        textColor: Color,
        action: @escaping () -> Void
    ) {
        self.cityName = cityName
        self.display = display
        self.textColor = textColor
        self.action = action
    }

    public var body: some View {
        if let display {
            Button(action: action) {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                        Text(cityName)
                    }
                    .font(.subheadline)
                    .foregroundStyle(textColor.opacity(0.90))

                    Text("·")
                        .foregroundStyle(textColor.opacity(0.60))

                    HStack(spacing: 4) {
                        Image(systemName: WeatherFormatter.systemImageName(for: display.header.iconName))
                            .font(.caption)
                        Text(display.buttonTitle)
                            .font(.caption.bold())
                        Text(display.header.conditionSummary)
                            .font(.caption)
                    }
                    .foregroundStyle(textColor.opacity(0.90))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(
                format: NSLocalizedString("weather.header_a11y_format", value: "תחזית מזג אוויר עבור %1$@: %2$@, %3$@", comment: ""),
                cityName, display.buttonTitle, display.header.conditionSummary
            ))
            .accessibilityHint(Text("weather.header_a11y_hint"))
            .accessibilityAddTraits(.isButton)
        } else {
            // When weather is unavailable: location only, no fake weather text or button
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                Text(cityName)
            }
            .font(.subheadline)
            .foregroundStyle(textColor.opacity(0.85))
        }
    }
}
