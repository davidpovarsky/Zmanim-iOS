import Foundation

public struct WeatherPresentation: Equatable, Sendable {
    public struct Header: Equatable, Sendable {
        public let iconName: String
        public let conditionSummary: String
        public let regionName: String
        public let chanceOfRainText: String?
        public let currentTemp: String
        public let highLowText: String?

        public init(
            iconName: String,
            conditionSummary: String,
            regionName: String,
            chanceOfRainText: String?,
            currentTemp: String,
            highLowText: String?
        ) {
            self.iconName = iconName
            self.conditionSummary = conditionSummary
            self.regionName = regionName
            self.chanceOfRainText = chanceOfRainText
            self.currentTemp = currentTemp
            self.highLowText = highLowText
        }
    }

    public struct Stats: Equatable, Sendable {
        public let windText: String
        public let precipText: String?
        public let feelsLikeText: String?

        public init(windText: String, precipText: String?, feelsLikeText: String?) {
            self.windText = windText
            self.precipText = precipText
            self.feelsLikeText = feelsLikeText
        }
    }

    public struct HourlyItem: Identifiable, Equatable, Sendable {
        public let id: Date
        public let timeLabel: String
        public let iconName: String
        public let temp: String
        public let isNow: Bool

        public init(id: Date, timeLabel: String, iconName: String, temp: String, isNow: Bool) {
            self.id = id
            self.timeLabel = timeLabel
            self.iconName = iconName
            self.temp = temp
            self.isNow = isNow
        }
    }

    public let buttonTitle: String
    public let header: Header
    public let stats: Stats
    public let hourly: [HourlyItem]
    public let attribution: String

    public init?(
        snapshot: WeatherSnapshot,
        cityName: String,
        timeZone: TimeZone,
        now: Date = Date()
    ) {
        guard !snapshot.hours.isEmpty else { return nil }

        // Strictly ensure we have a valid hourly sample around now (within at most 2 hours)
        guard let current = snapshot.hours.first(where: { abs($0.time.timeIntervalSince(now)) <= 3600 })
            ?? snapshot.hours.last(where: { $0.time <= now && now.timeIntervalSince($0.time) <= 7200 }) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let currentHourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now.addingTimeInterval(-1800)
        let upcoming = snapshot.hours
            .filter { $0.time >= currentHourStart }
            .sorted { $0.time < $1.time }

        var seen = Set<Date>()
        let deduped = upcoming.filter { seen.insert($0.time).inserted }
        let shown = Array(deduped.prefix(24))
        guard !shown.isEmpty else { return nil }

        let curRounded = Int(current.temperatureCelsius.rounded())
        let low = shown.map(\.temperatureCelsius).min() ?? current.temperatureCelsius
        let high = shown.map(\.temperatureCelsius).max() ?? current.temperatureCelsius
        let lowRounded = Int(low.rounded())
        let highRounded = Int(high.rounded())

        self.buttonTitle = "\(curRounded)°"

        let chanceText: String?
        if let chance = current.precipitationChancePercent {
            chanceText = "סיכוי למשקעים: \(Int(chance.rounded()))%"
        } else {
            chanceText = nil
        }

        let condition = METSymbolMapper.conditionText(for: current.symbolCode)
        let icon = METSymbolMapper.iconKey(from: current.symbolCode)

        self.header = Header(
            iconName: icon,
            conditionSummary: condition,
            regionName: cityName,
            chanceOfRainText: chanceText,
            currentTemp: "\(curRounded)°",
            highLowText: "ג: \(highRounded)°  נ: \(lowRounded)°"
        )

        let windString: String
        if let wind = current.windMetersPerSecond {
            windString = "\(Int((wind * 3.6).rounded())) קמ״ש"
        } else {
            windString = "—"
        }

        let precipString: String?
        if let chance = current.precipitationChancePercent {
            precipString = "\(Int(chance.rounded()))%"
        } else {
            precipString = nil
        }

        self.stats = Stats(
            windText: windString,
            precipText: precipString,
            feelsLikeText: nil // Not provided by MET Norway Locationforecast 2.0; do not fabricate
        )

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"

        self.hourly = shown.enumerated().map { index, hour in
            let isCurrent = (index == 0)
            let label = isCurrent ? "עכשיו" : timeFormatter.string(from: hour.time)
            let hourIcon = METSymbolMapper.iconKey(from: hour.symbolCode)
            let hourTemp = "\(Int(hour.temperatureCelsius.rounded()))°"
            return HourlyItem(
                id: hour.time,
                timeLabel: label,
                iconName: hourIcon,
                temp: hourTemp,
                isNow: isCurrent
            )
        }

        self.attribution = WeatherSnapshot.attribution
    }
}
