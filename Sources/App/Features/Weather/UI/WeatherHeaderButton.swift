import SwiftUI
import OneBusAwayWeatherCore
import OneBusAwayWeatherUI

public struct WeatherHeaderButton: View {
    public let display: WeatherDisplay?
    public let textColor: Color
    public let action: () -> Void

    public init(
        display: WeatherDisplay?,
        textColor: Color,
        action: @escaping () -> Void
    ) {
        self.display = display
        self.textColor = textColor
        self.action = action
    }

    public var body: some View {
        if let display {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: WeatherFormatter.systemImageName(for: display.header.iconName))
                        .font(.caption)
                    Text(display.buttonTitle)
                        .font(.caption.bold())
                    Text(display.header.conditionSummary)
                        .font(.caption)
                }
                .foregroundStyle(textColor.opacity(0.90))
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(
                format: NSLocalizedString("weather.header_a11y_format", comment: ""),
                display.buttonTitle, display.header.conditionSummary
            ))
            .accessibilityHint(Text("weather.header_a11y_hint"))
            .accessibilityAddTraits(.isButton)
        }
    }
}
