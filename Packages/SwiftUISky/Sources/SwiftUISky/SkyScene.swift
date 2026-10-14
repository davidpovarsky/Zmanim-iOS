import Foundation

/// One frame of the sky in unit coordinates.
public struct SkyScene: Sendable {
    public struct Cloud: Equatable, Sendable {
        public var variant: Int
        public var x: Double
        public var y: Double
        public var width: Double
        public var opacity: Double
    }

    public struct Wisp: Equatable, Sendable {
        public var variant: Int
        public var x: Double
        public var y: Double
        public var width: Double
        public var opacity: Double
    }

    public struct Star: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var radius: Double
        public var opacity: Double
    }

    public struct Meteor: Equatable, Sendable {
        public var headX: Double
        public var headY: Double
        public var tailX: Double
        public var tailY: Double
        public var opacity: Double
    }

    public struct HorizonGlow: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var radius: Double
        public var opacity: Double
    }

    public struct RainStreak: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var length: Double
        public var opacity: Double
    }

    public struct SnowFlake: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var radius: Double
        public var opacity: Double
    }

    public static let cloudVariantCount = 4
    public static let wispVariantCount = 3

    public let daylight: SkyDaylight
    public let palette: SkyPalette
    public let condition: SkyWeatherCondition
    public let horizonGlow: HorizonGlow
    public let clouds: [Cloud]
    public let wisps: [Wisp]
    public let stars: [Star]
    public let meteor: Meteor?
    public let rainStreaks: [RainStreak]
    public let snowFlakes: [SnowFlake]

    public init(
        date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        actualSunrise: Date? = nil,
        actualSunset: Date? = nil,
        condition: SkyWeatherCondition = .clear,
        cloudCover: Double = 0.2,
        motionTime: TimeInterval,
        allowsMeteor: Bool
    ) {
        let daylight = SkyDaylight(
            date: date,
            calendar: calendar,
            actualSunrise: actualSunrise,
            actualSunset: actualSunset
        )
        self.daylight = daylight
        self.condition = condition
        self.palette = SkyPalette(
            daylight: daylight,
            condition: condition,
            cloudCover: cloudCover
        )

        let glowX = daylight.sunProgress.map { 0.18 + 0.64 * $0 } ?? 0.5
        self.horizonGlow = HorizonGlow(
            x: glowX,
            y: 0.42,
            radius: 0.58,
            opacity: palette.horizonGlowOpacity
        )

        self.clouds = SkyCloudField.clouds(
            season: daylight.season,
            condition: condition,
            cloudCover: cloudCover,
            motionTime: motionTime
        )
        self.wisps = SkyCloudField.wisps(
            season: daylight.season,
            condition: condition,
            motionTime: motionTime
        )
        self.stars = SkyStarField.stars(
            motionTime: motionTime,
            opacityScale: palette.starOpacity
        )
        self.meteor = (allowsMeteor && condition == .clear)
            ? SkyMeteorSchedule.meteor(motionTime: motionTime, nightWeight: daylight.nightWeight)
            : nil

        if condition == .rain || condition == .thunderstorm {
            self.rainStreaks = Self.generateRain(motionTime: motionTime)
        } else {
            self.rainStreaks = []
        }

        if condition == .snow {
            self.snowFlakes = Self.generateSnow(motionTime: motionTime)
        } else {
            self.snowFlakes = []
        }
    }

    private static func generateRain(motionTime: TimeInterval) -> [RainStreak] {
        let count = 42
        return (0..<count).map { i in
            let seed = SkyNoise.seed(13, i)
            let speed = 0.8 + 0.4 * SkyNoise.value(seed, 0)
            let startX = SkyNoise.value(seed, 1)
            let startY = SkyNoise.value(seed, 2)
            let travelY = (startY + speed * motionTime).truncatingRemainder(dividingBy: 1.2) - 0.1
            let length = 0.04 + 0.03 * SkyNoise.value(seed, 3)
            let opacity = 0.25 + 0.35 * SkyNoise.value(seed, 4)
            return RainStreak(x: startX, y: travelY, length: length, opacity: opacity)
        }
    }

    private static func generateSnow(motionTime: TimeInterval) -> [SnowFlake] {
        let count = 32
        return (0..<count).map { i in
            let seed = SkyNoise.seed(15, i)
            let speed = 0.14 + 0.10 * SkyNoise.value(seed, 0)
            let startX = SkyNoise.value(seed, 1)
            let startY = SkyNoise.value(seed, 2)
            let travelY = (startY + speed * motionTime).truncatingRemainder(dividingBy: 1.1) - 0.05
            let sway = 0.02 * sin(motionTime * 1.5 + SkyNoise.value(seed, 3) * 2 * .pi)
            let radius = 1.0 + 1.8 * SkyNoise.value(seed, 4)
            let opacity = 0.35 + 0.40 * SkyNoise.value(seed, 5)
            return SnowFlake(x: startX + sway, y: travelY, radius: radius, opacity: opacity)
        }
    }
}

public enum SkyCloudField {
    private struct Layer {
        let baseCount: Int
        let minWidth: Double
        let maxWidth: Double
        let speed: Double
        let opacity: Double
        let minY: Double
        let maxY: Double
    }

    private static let cloudLayers: [Layer] = [
        Layer(baseCount: 2, minWidth: 0.30, maxWidth: 0.44, speed: 0.0022, opacity: 0.45, minY: 0.03, maxY: 0.12),
        Layer(baseCount: 2, minWidth: 0.50, maxWidth: 0.72, speed: 0.0040, opacity: 0.90, minY: 0.16, maxY: 0.30),
        Layer(baseCount: 3, minWidth: 0.85, maxWidth: 1.20, speed: 0.0030, opacity: 0.96, minY: 0.44, maxY: 0.62),
    ]

    private static let wispLayer = Layer(
        baseCount: 5, minWidth: 0.55, maxWidth: 0.95, speed: 0.0060, opacity: 0.7, minY: 0.04, maxY: 0.40
    )

    static func clouds(
        season: SkySeason,
        condition: SkyWeatherCondition,
        cloudCover: Double,
        motionTime: TimeInterval
    ) -> [SkyScene.Cloud] {
        var result: [SkyScene.Cloud] = []
        let conditionMultiplier: Double
        switch condition {
        case .clear: conditionMultiplier = 0.4
        case .partlyCloudy: conditionMultiplier = 0.75 + 0.25 * cloudCover
        case .overcast, .rain, .thunderstorm: conditionMultiplier = 1.25
        case .snow, .fog: conditionMultiplier = 1.0
        }

        for (layerIndex, layer) in cloudLayers.enumerated() {
            let count = max(1, Int((Double(layer.baseCount) * season.cloudCoverage * conditionMultiplier).rounded()))
            for index in 0 ..< count {
                let seed = SkyNoise.seed(layerIndex, index)
                let placement = place(layer: layer, seed: seed, index: index, count: count, motionTime: motionTime)
                result.append(
                    SkyScene.Cloud(
                        variant: Int(SkyNoise.value(seed, 6) * Double(SkyScene.cloudVariantCount)),
                        x: placement.x,
                        y: placement.y,
                        width: placement.width * season.cloudScale,
                        opacity: layer.opacity * (0.85 + 0.15 * SkyNoise.value(seed, 4))
                    )
                )
            }
        }
        return result
    }

    static func wisps(
        season: SkySeason,
        condition: SkyWeatherCondition,
        motionTime: TimeInterval
    ) -> [SkyScene.Wisp] {
        guard condition != .rain && condition != .thunderstorm else { return [] }
        let count = season.wispCount
        return (0 ..< count).map { index in
            let seed = SkyNoise.seed(5, index)
            let placement = place(
                layer: wispLayer, seed: seed, index: index, count: count, motionTime: motionTime
            )
            return SkyScene.Wisp(
                variant: Int(SkyNoise.value(seed, 6) * Double(SkyScene.wispVariantCount)),
                x: placement.x,
                y: placement.y,
                width: placement.width,
                opacity: wispLayer.opacity * (0.7 + 0.3 * SkyNoise.value(seed, 4))
            )
        }
    }

    private static func place(
        layer: Layer,
        seed: UInt64,
        index: Int,
        count: Int,
        motionTime: TimeInterval
    ) -> (x: Double, y: Double, width: Double) {
        let width = layer.minWidth + (layer.maxWidth - layer.minWidth) * SkyNoise.value(seed, 0)
        let wrap = 1 + width
        let baseX = (Double(index) + SkyNoise.value(seed, 1) * 0.8) / Double(count) * wrap
        let travel = (baseX - layer.speed * motionTime).truncatingRemainder(dividingBy: wrap)
        let x = (travel < 0 ? travel + wrap : travel) - width / 2
        let bobPhase = SkyNoise.value(seed, 2) * 2 * .pi
        let y = layer.minY
            + (layer.maxY - layer.minY) * SkyNoise.value(seed, 3)
            + 0.004 * sin(motionTime * 0.12 + bobPhase)
        return (x, y, width)
    }
}

public enum SkyStarField {
    public static let count = 64

    public static func stars(motionTime: TimeInterval, opacityScale: Double) -> [SkyScene.Star] {
        guard opacityScale > 0.001 else { return [] }
        return (0 ..< count).map { index in
            let seed = SkyNoise.seed(7, index)
            let base = 0.35 + 0.60 * SkyNoise.value(seed, 0)
            let twinkles = SkyNoise.value(seed, 1) < 0.45
            let flicker: Double
            if twinkles {
                let frequency = 0.8 + 1.4 * SkyNoise.value(seed, 2)
                let phase = SkyNoise.value(seed, 3) * 2 * .pi
                flicker = 0.72 + 0.28 * sin(motionTime * frequency + phase)
            } else {
                flicker = 1
            }
            return SkyScene.Star(
                x: SkyNoise.value(seed, 4),
                y: 0.02 + 0.60 * SkyNoise.value(seed, 5),
                radius: 0.6 + 1.0 * SkyNoise.value(seed, 6),
                opacity: base * flicker * opacityScale
            )
        }
    }
}

public enum SkyMeteorSchedule {
    public static let slotLength: TimeInterval = 40
    public static let duration: TimeInterval = 1.0
    public static let minimumNightWeight = 0.6

    public static func meteor(motionTime: TimeInterval, nightWeight: Double) -> SkyScene.Meteor? {
        guard nightWeight >= minimumNightWeight, motionTime >= 0 else { return nil }
        let slotIndex = Int(motionTime / slotLength)
        let seed = SkyNoise.seed(11, slotIndex)
        let offset = 4 + (slotLength - duration - 8) * SkyNoise.value(seed, 0)
        let elapsed = motionTime - Double(slotIndex) * slotLength - offset
        guard elapsed >= 0, elapsed <= duration else { return nil }

        let progress = elapsed / duration
        let startX = 0.15 + 0.60 * SkyNoise.value(seed, 1)
        let startY = 0.04 + 0.26 * SkyNoise.value(seed, 2)
        let angle = (28 + 12 * SkyNoise.value(seed, 3)) * Double.pi / 180
        let direction = SkyNoise.value(seed, 4) < 0.5 ? 1.0 : -1.0
        let dx = cos(angle) * direction
        let dy = sin(angle)
        let travel = 0.34 * progress
        let tail = 0.02 + 0.16 * sin(.pi * progress)
        let headX = startX + dx * travel
        let headY = startY + dy * travel
        return SkyScene.Meteor(
            headX: headX,
            headY: headY,
            tailX: headX - dx * tail,
            tailY: headY - dy * tail,
            opacity: sin(.pi * progress) * SkyMath.smoothstep(minimumNightWeight, 1, nightWeight)
        )
    }
}

public enum SkyNoise {
    public static func seed(_ group: Int, _ index: Int) -> UInt64 {
        UInt64(truncatingIfNeeded: group) &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(truncatingIfNeeded: index) &* 0xBF58_476D_1CE4_E5B9
    }

    public static func value(_ seed: UInt64, _ slot: Int) -> Double {
        var z = seed &+ UInt64(truncatingIfNeeded: slot) &* 0x94D0_49BB_1331_11EB
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}

public enum SkyMath {
    public static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    public static func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> Double {
        let t = clamp((value - edge0) / (edge1 - edge0), 0, 1)
        return t * t * (3 - 2 * t)
    }
}
