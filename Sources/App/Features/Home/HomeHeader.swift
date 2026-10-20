import SwiftUI
import OneBusAwayWeatherUI

public struct HomeHeader: View {
    public let date: Date
    public let timeZone: TimeZone
    public let cityName: String
    public let display: WeatherDisplay?
    public let isLoading: Bool
    public let textColor: Color
    public let onWeatherTap: () -> Void

    public init(
        date: Date,
        timeZone: TimeZone,
        cityName: String,
        display: WeatherDisplay?,
        isLoading: Bool,
        textColor: Color,
        onWeatherTap: @escaping () -> Void
    ) {
        self.date = date
        self.timeZone = timeZone
        self.cityName = cityName
        self.display = display
        self.isLoading = isLoading
        self.textColor = textColor
        self.onWeatherTap = onWeatherTap
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
            compactLayout
        }
    }

    private var wideLayout: some View {
        HStack(alignment: .center, spacing: 12) {
            dateLabels
            Spacer(minLength: 8)
            trailingContent
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            dateLabels
            HStack {
                Spacer()
                trailingContent
            }
        }
    }

    private var dateLabels: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(weekdayString(from: date))
                .font(.subheadline)
                .foregroundStyle(textColor.opacity(0.85))
            Text(hebrewDateString(from: date))
                .font(.title3.bold())
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        if isLoading && display == nil {
            ProgressView().tint(textColor)
        } else if display != nil {
            WeatherHeaderButton(
                cityName: cityName,
                display: display,
                textColor: textColor,
                action: onWeatherTap
            )
        } else {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                Text(cityName)
            }
            .font(.subheadline)
            .foregroundStyle(textColor.opacity(0.9))
            .lineLimit(1)
        }
    }

    private func weekdayString(from date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.timeZone = timeZone
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func hebrewDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .hebrew)
        formatter.timeZone = timeZone
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}
