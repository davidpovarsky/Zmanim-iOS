import Foundation

public struct METLocationForecastDTO: Decodable, Sendable {
    public let properties: Properties

    public init(properties: Properties) {
        self.properties = properties
    }

    public struct Properties: Decodable, Sendable {
        public let timeseries: [TimeEntry]

        public init(timeseries: [TimeEntry]) {
            self.timeseries = timeseries
        }
    }

    public struct TimeEntry: Decodable, Sendable {
        public let time: String
        public let data: WeatherData

        public init(time: String, data: WeatherData) {
            self.time = time
            self.data = data
        }
    }

    public struct WeatherData: Decodable, Sendable {
        public let instant: Instant
        public let next1Hours: PeriodData?
        public let next6Hours: PeriodData?
        public let next12Hours: PeriodData?

        public init(
            instant: Instant,
            next1Hours: PeriodData? = nil,
            next6Hours: PeriodData? = nil,
            next12Hours: PeriodData? = nil
        ) {
            self.instant = instant
            self.next1Hours = next1Hours
            self.next6Hours = next6Hours
            self.next12Hours = next12Hours
        }

        private enum CodingKeys: String, CodingKey {
            case instant
            case next1Hours = "next_1_hours"
            case next6Hours = "next_6_hours"
            case next12Hours = "next_12_hours"
        }
    }

    public struct Instant: Decodable, Sendable {
        public let details: InstantDetails

        public init(details: InstantDetails) {
            self.details = details
        }
    }

    public struct InstantDetails: Decodable, Sendable {
        public let airTemperature: Double
        public let windSpeed: Double?
        public let cloudAreaFraction: Double?

        public init(airTemperature: Double, windSpeed: Double? = nil, cloudAreaFraction: Double? = nil) {
            self.airTemperature = airTemperature
            self.windSpeed = windSpeed
            self.cloudAreaFraction = cloudAreaFraction
        }

        private enum CodingKeys: String, CodingKey {
            case airTemperature = "air_temperature"
            case windSpeed = "wind_speed"
            case cloudAreaFraction = "cloud_area_fraction"
        }
    }

    public struct PeriodData: Decodable, Sendable {
        public let summary: Summary?
        public let details: PeriodDetails?

        public init(summary: Summary? = nil, details: PeriodDetails? = nil) {
            self.summary = summary
            self.details = details
        }
    }

    public struct Summary: Decodable, Sendable {
        public let symbolCode: String

        public init(symbolCode: String) {
            self.symbolCode = symbolCode
        }

        private enum CodingKeys: String, CodingKey {
            case symbolCode = "symbol_code"
        }
    }

    public struct PeriodDetails: Decodable, Sendable {
        public let probabilityOfPrecipitation: Double?

        public init(probabilityOfPrecipitation: Double? = nil) {
            self.probabilityOfPrecipitation = probabilityOfPrecipitation
        }

        private enum CodingKeys: String, CodingKey {
            case probabilityOfPrecipitation = "probability_of_precipitation"
        }
    }
}
