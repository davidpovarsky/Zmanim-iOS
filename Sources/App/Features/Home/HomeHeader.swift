import SwiftUI

public struct HomeHeader: View {
    public let date: Date
    public let timeZone: TimeZone
    public let cityName: String
    public let presentation: WeatherPresentation?
    public let isLoading: Bool
    public let textColor: Color
    public let onWeatherTap: () -> Void

    public init(
        date: Date,
        timeZone: TimeZone,
        cityName: String,
        presentation: WeatherPresentation?,
        isLoading: Bool,
        textColor: Color,
        onWeatherTap: @escaping () -> Void
    ) {
        self.date = date
        self.timeZone = timeZone
        self.cityName = cityName
        self.presentation = presentation
        self.isLoading = isLoading
        self.textColor = textColor
        self.onWeatherTap = onWeatherTap
    }

    public var body: some View {
        HStack {
            // In RTL locale (Hebrew), leading is on the right
            VStack(alignment: .leading, spacing: 3) {
                Text(weekdayString(from: date))
                    .font(.subheadline)
                    .foregroundStyle(textColor.opacity(0.85))
                Text(hebrewDateString(from: date))
                    .font(.title3.bold())
                    .foregroundStyle(textColor)
            }

            Spacer()

            // In RTL locale (Hebrew), trailing is on the left (matches weather_button_marked.png)
            if isLoading && presentation == nil {
                ProgressView().tint(textColor)
            } else {
                WeatherHeaderButton(
                    cityName: cityName,
                    presentation: presentation,
                    textColor: textColor,
                    action: onWeatherTap
                )
            }
        }
    }

    private func weekdayString(from date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func hebrewDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .hebrew)
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}
