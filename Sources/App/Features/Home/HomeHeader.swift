import SwiftUI
import OneBusAwayWeatherUI

public struct HomeHeader: View {
    public let date: Date
    public let timeZone: TimeZone
    public let cityName: String
    public let isGPSActive: Bool
    public let activeChoice: LocationChoice
    public let defaultChoice: LocationChoice
    public let savedCities: [SavedCity]
    public let display: WeatherDisplay?
    public let isLoading: Bool
    public let textColor: Color
    public let onSelectChoice: (LocationChoice) -> Void
    public let onAddCityTap: () -> Void
    public let onWeatherTap: () -> Void

    public init(
        date: Date,
        timeZone: TimeZone,
        cityName: String,
        isGPSActive: Bool = true,
        activeChoice: LocationChoice = .current,
        defaultChoice: LocationChoice = .current,
        savedCities: [SavedCity] = [],
        display: WeatherDisplay?,
        isLoading: Bool,
        textColor: Color,
        onSelectChoice: @escaping (LocationChoice) -> Void = { _ in },
        onAddCityTap: @escaping () -> Void = {},
        onWeatherTap: @escaping () -> Void
    ) {
        self.date = date
        self.timeZone = timeZone
        self.cityName = cityName
        self.isGPSActive = isGPSActive
        self.activeChoice = activeChoice
        self.defaultChoice = defaultChoice
        self.savedCities = savedCities
        self.display = display
        self.isLoading = isLoading
        self.textColor = textColor
        self.onSelectChoice = onSelectChoice
        self.onAddCityTap = onAddCityTap
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
            trailingControls
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            dateLabels
            HStack {
                Spacer()
                trailingControls
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
    private var trailingControls: some View {
        HStack(spacing: 6) {
            HomeLocationMenu(
                currentCityName: cityName,
                isGPSActive: isGPSActive,
                activeChoice: activeChoice,
                defaultChoice: defaultChoice,
                savedCities: savedCities,
                textColor: textColor,
                onSelectChoice: onSelectChoice,
                onAddCityTap: onAddCityTap
            )

            if let display {
                Text("·")
                    .foregroundStyle(textColor.opacity(0.60))

                WeatherHeaderButton(
                    display: display,
                    textColor: textColor,
                    action: onWeatherTap
                )
            } else if isLoading {
                ProgressView().tint(textColor)
            }
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
        var cal = Calendar(identifier: .hebrew)
        cal.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
