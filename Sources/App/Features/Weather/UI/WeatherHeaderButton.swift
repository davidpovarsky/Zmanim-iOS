import SwiftUI

public struct WeatherHeaderButton: View {
    public let cityName: String
    public let presentation: WeatherPresentation?
    public let textColor: Color
    public let action: () -> Void

    public init(
        cityName: String,
        presentation: WeatherPresentation?,
        textColor: Color,
        action: @escaping () -> Void
    ) {
        self.cityName = cityName
        self.presentation = presentation
        self.textColor = textColor
        self.action = action
    }

    public var body: some View {
        if let presentation {
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
                        Image(systemName: METSymbolMapper.systemImageName(for: presentation.header.iconName))
                            .font(.caption)
                        Text(presentation.buttonTitle)
                            .font(.caption.bold())
                        Text(presentation.header.conditionSummary)
                            .font(.caption)
                    }
                    .foregroundStyle(textColor.opacity(0.90))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("תחזית מזג אוויר עבור \(cityName): \(presentation.buttonTitle), \(presentation.header.conditionSummary)")
            .accessibilityHint("הקש לפתיחת כרטיס תחזית מפורט")
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
