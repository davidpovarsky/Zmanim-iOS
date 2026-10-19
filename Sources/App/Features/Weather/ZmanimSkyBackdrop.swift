import SwiftUI
import SwiftUISky

public struct ZmanimSkyBackdrop: View {
    public let date: Date
    public let timeZone: TimeZone
    public let sunrise: Date?
    public let sunset: Date?
    public let condition: WeatherCondition?
    public let cloudCover: Double
    public let isPaused: Bool
    public let motionTimeOverride: TimeInterval?

    @Environment(\.colorScheme) private var colorScheme

    public init(
        date: Date = Date(),
        timeZone: TimeZone = .current,
        sunrise: Date? = nil,
        sunset: Date? = nil,
        condition: WeatherCondition? = nil,
        cloudCover: Double = 0.20,
        isPaused: Bool = false,
        motionTimeOverride: TimeInterval? = nil
    ) {
        self.date = date
        self.timeZone = timeZone
        self.sunrise = sunrise
        self.sunset = sunset
        self.condition = condition
        self.cloudCover = cloudCover
        self.isPaused = isPaused
        self.motionTimeOverride = motionTimeOverride
    }

    public var body: some View {
        if let condition {
            GeometryReader { proxy in
                let isLandscape = proxy.size.width > proxy.size.height
                let backdropHeight: CGFloat = isLandscape
                    ? max(340, proxy.size.height * 0.70)
                    : min(max(proxy.safeAreaInsets.top + 330, 380), 460)

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone

                SkyBackdrop(
                    date: date,
                    actualSunrise: sunrise,
                    actualSunset: sunset,
                    condition: condition.skyCondition,
                    cloudCover: cloudCover,
                    pageColor: Color.zmanBackground,
                    isVisible: true,
                    isPaused: isPaused,
                    motionTimeOverride: motionTimeOverride,
                    customHeight: backdropHeight,
                    calendar: calendar
                )
            }
            .ignoresSafeArea(.all, edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            // Strictly no fake weather backdrop when condition is unavailable
            EmptyView()
        }
    }

    /// Determines readable header foreground color matching the background sky luminance.
    public static func headerColor(
        for date: Date,
        timeZone: TimeZone = .current,
        sunrise: Date?,
        sunset: Date?,
        condition: WeatherCondition?,
        cloudCover: Double,
        colorScheme: ColorScheme
    ) -> Color {
        guard let condition else {
            return colorScheme == .dark ? Color.white : Color.zmanInk
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        return SkyBackdrop.headerColor(
            at: date,
            actualSunrise: sunrise,
            actualSunset: sunset,
            condition: condition.skyCondition,
            cloudCover: cloudCover,
            colorScheme: colorScheme,
            calendar: calendar
        )
    }
}

extension WeatherCondition {
    public var skyCondition: SkyWeatherCondition {
        switch self {
        case .clearDay, .clearNight, .sunrise, .sunset:
            return .clear
        case .partlyCloudyDay:
            return .partlyCloudy
        case .overcastDay, .cloudyNight:
            return .overcast
        case .rain:
            return .rain
        case .snow:
            return .snow
        case .fog:
            return .fog
        case .thunderstorm:
            return .thunderstorm
        }
    }
}
