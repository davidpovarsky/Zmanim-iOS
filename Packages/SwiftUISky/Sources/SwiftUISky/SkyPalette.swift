import Foundation

public enum SkyWeatherCondition: String, Sendable, CaseIterable {
    case clear
    case partlyCloudy
    case overcast
    case rain
    case snow
    case fog
    case thunderstorm
}

/// Plain sRGB triple so the palette stays testable without SwiftUI.
public struct SkyRGB: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Perceptual weighting of sRGB channels; good enough for choosing ink.
    public var luminance: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    public static func mix(_ from: SkyRGB, _ to: SkyRGB, _ amount: Double) -> SkyRGB {
        let t = SkyMath.clamp(amount, 0, 1)
        return SkyRGB(
            red: from.red + (to.red - from.red) * t,
            green: from.green + (to.green - from.green) * t,
            blue: from.blue + (to.blue - from.blue) * t
        )
    }
}

/// Colors for one moment of the day, with weather condition and cloud cover adjustments.
public struct SkyPalette: Equatable, Sendable {
    public let skyTop: SkyRGB
    public let skyUpper: SkyRGB
    public let skyGlow: SkyRGB
    public let skyBase: SkyRGB
    public let horizonGlow: SkyRGB
    public let horizonGlowOpacity: Double
    public let cloudBody: SkyRGB
    public let cloudShade: SkyRGB
    public let cloudOpacity: Double
    public let wisp: SkyRGB
    public let wispOpacity: Double
    public let starOpacity: Double
    public let headerLuminance: Double

    private struct Moment {
        let skyTop: SkyRGB
        let skyUpper: SkyRGB
        let skyGlow: SkyRGB
        let skyBase: SkyRGB
        let horizonGlow: SkyRGB
        let horizonGlowOpacity: Double
        let cloudBody: SkyRGB
        let cloudShade: SkyRGB
        let cloudOpacity: Double
        let wisp: SkyRGB
        let wispOpacity: Double

        static func mix(_ a: Moment, _ b: Moment, _ t: Double) -> Moment {
            Moment(
                skyTop: .mix(a.skyTop, b.skyTop, t),
                skyUpper: .mix(a.skyUpper, b.skyUpper, t),
                skyGlow: .mix(a.skyGlow, b.skyGlow, t),
                skyBase: .mix(a.skyBase, b.skyBase, t),
                horizonGlow: .mix(a.horizonGlow, b.horizonGlow, t),
                horizonGlowOpacity: a.horizonGlowOpacity + (b.horizonGlowOpacity - a.horizonGlowOpacity) * t,
                cloudBody: .mix(a.cloudBody, b.cloudBody, t),
                cloudShade: .mix(a.cloudShade, b.cloudShade, t),
                cloudOpacity: a.cloudOpacity + (b.cloudOpacity - a.cloudOpacity) * t,
                wisp: .mix(a.wisp, b.wisp, t),
                wispOpacity: a.wispOpacity + (b.wispOpacity - a.wispOpacity) * t
            )
        }
    }

    private static let day = Moment(
        skyTop: SkyRGB(red: 0.52, green: 0.67, blue: 0.92),
        skyUpper: SkyRGB(red: 0.72, green: 0.81, blue: 0.96),
        skyGlow: SkyRGB(red: 0.90, green: 0.93, blue: 0.98),
        skyBase: SkyRGB(red: 0.97, green: 0.97, blue: 0.98),
        horizonGlow: SkyRGB(red: 1, green: 1, blue: 1),
        horizonGlowOpacity: 0.35,
        cloudBody: SkyRGB(red: 1, green: 1, blue: 1),
        cloudShade: SkyRGB(red: 0.70, green: 0.74, blue: 0.92),
        cloudOpacity: 0.9,
        wisp: SkyRGB(red: 0.80, green: 0.85, blue: 0.97),
        wispOpacity: 0.35
    )

    private static let dawn = Moment(
        skyTop: SkyRGB(red: 0.93, green: 0.72, blue: 0.82),
        skyUpper: SkyRGB(red: 0.96, green: 0.80, blue: 0.81),
        skyGlow: SkyRGB(red: 0.99, green: 0.91, blue: 0.78),
        skyBase: SkyRGB(red: 0.99, green: 0.96, blue: 0.92),
        horizonGlow: SkyRGB(red: 1, green: 0.92, blue: 0.70),
        horizonGlowOpacity: 1,
        cloudBody: SkyRGB(red: 0.99, green: 0.90, blue: 0.91),
        cloudShade: SkyRGB(red: 0.90, green: 0.64, blue: 0.75),
        cloudOpacity: 0.85,
        wisp: SkyRGB(red: 0.91, green: 0.64, blue: 0.74),
        wispOpacity: 0.9
    )

    private static let dusk = Moment(
        skyTop: SkyRGB(red: 0.80, green: 0.60, blue: 0.80),
        skyUpper: SkyRGB(red: 0.95, green: 0.72, blue: 0.74),
        skyGlow: SkyRGB(red: 0.99, green: 0.85, blue: 0.65),
        skyBase: SkyRGB(red: 0.99, green: 0.95, blue: 0.90),
        horizonGlow: SkyRGB(red: 1, green: 0.84, blue: 0.55),
        horizonGlowOpacity: 1,
        cloudBody: SkyRGB(red: 0.99, green: 0.86, blue: 0.85),
        cloudShade: SkyRGB(red: 0.84, green: 0.54, blue: 0.70),
        cloudOpacity: 0.85,
        wisp: SkyRGB(red: 0.86, green: 0.56, blue: 0.70),
        wispOpacity: 0.9
    )

    private static let night = Moment(
        skyTop: SkyRGB(red: 0.12, green: 0.15, blue: 0.32),
        skyUpper: SkyRGB(red: 0.22, green: 0.23, blue: 0.44),
        skyGlow: SkyRGB(red: 0.38, green: 0.34, blue: 0.52),
        skyBase: SkyRGB(red: 0.48, green: 0.42, blue: 0.56),
        horizonGlow: SkyRGB(red: 0.55, green: 0.42, blue: 0.58),
        horizonGlowOpacity: 0.25,
        cloudBody: SkyRGB(red: 0.42, green: 0.42, blue: 0.68),
        cloudShade: SkyRGB(red: 0.18, green: 0.18, blue: 0.36),
        cloudOpacity: 0.35,
        wisp: SkyRGB(red: 0.52, green: 0.46, blue: 0.68),
        wispOpacity: 0.45
    )

    public init(
        daylight: SkyDaylight,
        condition: SkyWeatherCondition = .clear,
        cloudCover: Double = 0.2
    ) {
        let season = daylight.season
        let twilightMoment = daylight.isEvening ? Self.dusk : Self.dawn
        let base = Moment.mix(Self.night, Self.day, daylight.daylight)
        let moment = Moment.mix(base, twilightMoment, daylight.twilight * 0.92)

        let cast = season.tintStrength * (0.25 + 0.75 * daylight.daylight)
        var rawTop = SkyRGB.mix(moment.skyTop, season.tint, cast)
        var rawUpper = SkyRGB.mix(moment.skyUpper, season.tint, cast)
        var rawGlow = SkyRGB.mix(moment.skyGlow, season.tint, cast * 0.5)
        var rawBase = moment.skyBase
        var rawHorizonGlow = moment.horizonGlow
        var rawHorizonGlowOpacity = SkyMath.clamp(
            moment.horizonGlowOpacity * (1 + (season.twilightWarmth - 1) * daylight.twilight),
            0,
            1
        )
        var rawCloudBody = SkyRGB.mix(moment.cloudBody, season.tint, cast * 0.25)
        var rawCloudShade = SkyRGB.mix(moment.cloudShade, season.tint, cast * 0.5)
        var rawCloudOpacity = moment.cloudOpacity
        var rawWisp = moment.wisp
        var rawWispOpacity = SkyMath.clamp(moment.wispOpacity * (0.6 + 0.4 * season.twilightWarmth), 0, 1)

        // Weather condition tint & mood overlays
        switch condition {
        case .clear:
            rawCloudOpacity *= 0.35
            rawWispOpacity *= 0.40
        case .partlyCloudy:
            rawCloudOpacity = min(1.0, rawCloudOpacity * (0.6 + 0.4 * cloudCover))
        case .overcast:
            let overcastTint = SkyRGB(red: 0.62, green: 0.67, blue: 0.74)
            rawTop = .mix(rawTop, overcastTint, 0.55)
            rawUpper = .mix(rawUpper, overcastTint, 0.60)
            rawGlow = .mix(rawGlow, overcastTint, 0.50)
            rawCloudBody = SkyRGB(red: 0.88, green: 0.90, blue: 0.93)
            rawCloudShade = SkyRGB(red: 0.58, green: 0.62, blue: 0.68)
            rawCloudOpacity = 0.95
            rawHorizonGlowOpacity *= 0.3
        case .rain:
            let rainTint = SkyRGB(red: 0.42, green: 0.48, blue: 0.58)
            rawTop = .mix(rawTop, rainTint, 0.65)
            rawUpper = .mix(rawUpper, rainTint, 0.68)
            rawGlow = .mix(rawGlow, rainTint, 0.60)
            rawCloudBody = SkyRGB(red: 0.72, green: 0.76, blue: 0.82)
            rawCloudShade = SkyRGB(red: 0.40, green: 0.45, blue: 0.54)
            rawCloudOpacity = 0.98
            rawHorizonGlowOpacity *= 0.2
        case .snow:
            let snowTint = SkyRGB(red: 0.72, green: 0.76, blue: 0.84)
            rawTop = .mix(rawTop, snowTint, 0.50)
            rawUpper = .mix(rawUpper, snowTint, 0.55)
            rawGlow = .mix(rawGlow, snowTint, 0.45)
            rawCloudBody = SkyRGB(red: 0.94, green: 0.96, blue: 0.98)
            rawCloudShade = SkyRGB(red: 0.68, green: 0.72, blue: 0.78)
            rawCloudOpacity = 0.90
            rawHorizonGlowOpacity *= 0.4
        case .fog:
            let fogTint = SkyRGB(red: 0.80, green: 0.82, blue: 0.86)
            rawTop = .mix(rawTop, fogTint, 0.70)
            rawUpper = .mix(rawUpper, fogTint, 0.75)
            rawGlow = .mix(rawGlow, fogTint, 0.70)
            rawCloudOpacity = 0.80
            rawHorizonGlowOpacity *= 0.25
        case .thunderstorm:
            let stormTint = SkyRGB(red: 0.24, green: 0.26, blue: 0.38)
            rawTop = .mix(rawTop, stormTint, 0.80)
            rawUpper = .mix(rawUpper, stormTint, 0.80)
            rawGlow = .mix(rawGlow, stormTint, 0.75)
            rawCloudBody = SkyRGB(red: 0.50, green: 0.52, blue: 0.62)
            rawCloudShade = SkyRGB(red: 0.22, green: 0.24, blue: 0.34)
            rawCloudOpacity = 1.0
            rawHorizonGlowOpacity *= 0.1
        }

        skyTop = rawTop
        skyUpper = rawUpper
        skyGlow = rawGlow
        skyBase = rawBase
        horizonGlow = rawHorizonGlow
        horizonGlowOpacity = rawHorizonGlowOpacity
        cloudBody = rawCloudBody
        cloudShade = rawCloudShade
        cloudOpacity = rawCloudOpacity
        wisp = rawWisp
        wispOpacity = rawWispOpacity

        // Stars are dimmed by cloud cover, rain, overcast, fog
        let clearSkyFactor = max(0.0, 1.0 - cloudCover * 1.2)
        let weatherDimming: Double
        switch condition {
        case .clear: weatherDimming = 1.0
        case .partlyCloudy: weatherDimming = 0.65
        case .overcast, .rain, .thunderstorm, .snow, .fog: weatherDimming = 0.15
        }
        starOpacity = SkyMath.smoothstep(0.05, 0.6, daylight.nightWeight) * clearSkyFactor * weatherDimming

        let headerSky = SkyRGB.mix(skyUpper, skyGlow, 0.35)
        let headerCloud = SkyRGB.mix(cloudShade, cloudBody, 0.7)
        headerLuminance = SkyRGB.mix(headerSky, headerCloud, cloudOpacity * 0.55).luminance
    }
}

public enum SkyInk: Equatable, Sendable {
    case dark
    case light

    public static let threshold = 0.5

    public static func resolve(headerLuminance: Double, darkVeil: Double) -> SkyInk {
        let veiled = headerLuminance * (1 - darkVeil) + 0.07 * darkVeil
        return veiled >= threshold ? .dark : .light
    }
}
