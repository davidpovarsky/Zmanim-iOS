import Foundation

public struct WeatherHour: Sendable, Equatable, Codable {
    public let time: Date
    public let temperatureCelsius: Double
    public let windMetersPerSecond: Double?
    public let precipitationChancePercent: Double?
    public let cloudAreaFractionPercent: Double?
    public let symbolCode: String
    public let iconKey: String

    public init(
        time: Date,
        temperatureCelsius: Double,
        windMetersPerSecond: Double? = nil,
        precipitationChancePercent: Double? = nil,
        cloudAreaFractionPercent: Double? = nil,
        symbolCode: String,
        iconKey: String
    ) {
        self.time = time
        self.temperatureCelsius = temperatureCelsius
        self.windMetersPerSecond = windMetersPerSecond
        self.precipitationChancePercent = precipitationChancePercent
        self.cloudAreaFractionPercent = cloudAreaFractionPercent
        self.symbolCode = symbolCode
        self.iconKey = iconKey
    }
}
