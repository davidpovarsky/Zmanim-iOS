import SwiftUI

/// A procedural, animated sky that fills its proposed size.
public struct SkyView: View {
    private let date: Date?
    private let actualSunrise: Date?
    private let actualSunset: Date?
    private let condition: SkyWeatherCondition
    private let cloudCover: Double
    private let isVisible: Bool
    private let isPaused: Bool
    private let motionTimeOverride: TimeInterval?

    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = SkyMotionClock()
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var prefersReducedResources = false

    public init(
        date: Date? = nil,
        actualSunrise: Date? = nil,
        actualSunset: Date? = nil,
        condition: SkyWeatherCondition = .clear,
        cloudCover: Double = 0.2,
        isVisible: Bool = true,
        isPaused: Bool = false,
        motionTimeOverride: TimeInterval? = nil
    ) {
        self.date = date
        self.actualSunrise = actualSunrise
        self.actualSunset = actualSunset
        self.condition = condition
        self.cloudCover = cloudCover
        self.isVisible = isVisible
        self.isPaused = isPaused
        self.motionTimeOverride = motionTimeOverride
    }

    private var policy: SkyMotionPolicy {
        SkyMotionPolicy(
            reduceMotion: reduceMotion || motionTimeOverride != nil,
            isVisible: isVisible,
            isSceneActive: scenePhase == .active,
            isLowPowerModeEnabled: isLowPowerModeEnabled || prefersReducedResources,
            isFrozen: isPaused || motionTimeOverride != nil
        )
    }

    public var body: some View {
        let policy = policy
        TimelineView(.periodic(from: .now, by: 60)) { light in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !policy.isAnimating)) { motion in
                let currentMotionTime: TimeInterval = motionTimeOverride ?? (reduceMotion ? 0 : clock.time(at: motion.date))

                let scene = SkyScene(
                    date: date ?? light.date,
                    calendar: calendar,
                    actualSunrise: actualSunrise,
                    actualSunset: actualSunset,
                    condition: condition,
                    cloudCover: cloudCover,
                    motionTime: currentMotionTime,
                    allowsMeteor: policy.allowsMeteor
                )

                Canvas { context, size in
                    SkyRenderer.draw(scene, in: &context, size: size)
                } symbols: {
                    SkySpriteSymbols(palette: scene.palette)
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: policy.isAnimating, initial: true) { _, value in
            clock.setAnimating(value, at: .now)
        }
        .onAppear {
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            clock.setAnimating(policy.isAnimating, at: .now)
        }
        .onDisappear { clock.setAnimating(false, at: .now) }
        .onReceive(
            NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
                .receive(on: DispatchQueue.main)
        ) { _ in
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onSystemPrefersReducedResourceUsageChange { prefersReducedResources = $0 }
    }
}
