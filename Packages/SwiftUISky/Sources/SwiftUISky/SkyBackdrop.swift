import SwiftUI

/// The home-page composition: a dynamic sky band dissolving into a page background.
public struct SkyBackdrop: View {
    private let date: Date?
    private let actualSunrise: Date?
    private let actualSunset: Date?
    private let condition: SkyWeatherCondition
    private let cloudCover: Double
    private let pageColor: Color?
    private let isVisible: Bool
    private let isPaused: Bool
    private let motionTimeOverride: TimeInterval?
    private let customHeight: CGFloat?

    @Environment(\.colorScheme) private var colorScheme

    public init(
        date: Date? = nil,
        actualSunrise: Date? = nil,
        actualSunset: Date? = nil,
        condition: SkyWeatherCondition = .clear,
        cloudCover: Double = 0.2,
        pageColor: Color? = nil,
        isVisible: Bool = true,
        isPaused: Bool = false,
        motionTimeOverride: TimeInterval? = nil,
        customHeight: CGFloat? = nil
    ) {
        self.date = date
        self.actualSunrise = actualSunrise
        self.actualSunset = actualSunset
        self.condition = condition
        self.cloudCover = cloudCover
        self.pageColor = pageColor
        self.isVisible = isVisible
        self.isPaused = isPaused
        self.motionTimeOverride = motionTimeOverride
        self.customHeight = customHeight
    }

    public var body: some View {
        let page = pageColor ?? Self.defaultPageColor(for: colorScheme)
        ZStack(alignment: .top) {
            page.ignoresSafeArea()
            GeometryReader { proxy in
                let targetHeight = customHeight ?? min(max(proxy.size.width * 0.95, 360), 450)
                SkyView(
                    date: date,
                    actualSunrise: actualSunrise,
                    actualSunset: actualSunset,
                    condition: condition,
                    cloudCover: cloudCover,
                    isVisible: isVisible,
                    isPaused: isPaused,
                    motionTimeOverride: motionTimeOverride
                )
                .frame(height: targetHeight)
                .overlay {
                    // Continuous multi-stop dissolve into the page cream color
                    LinearGradient(
                        stops: [
                            .init(color: page.opacity(0.0), location: 0.18),
                            .init(color: page.opacity(0.12), location: 0.36),
                            .init(color: page.opacity(0.38), location: 0.54),
                            .init(color: page.opacity(0.72), location: 0.72),
                            .init(color: page.opacity(0.92), location: 0.88),
                            .init(color: page, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    public static func defaultPageColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(red: 0.972, green: 0.966, blue: 0.936)
    }

    public static func headerColor(
        at date: Date,
        actualSunrise: Date? = nil,
        actualSunset: Date? = nil,
        condition: SkyWeatherCondition = .clear,
        cloudCover: Double = 0.2,
        colorScheme: ColorScheme,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Color {
        let daylight = SkyDaylight(
            date: date,
            calendar: calendar,
            actualSunrise: actualSunrise,
            actualSunset: actualSunset
        )
        let palette = SkyPalette(
            daylight: daylight,
            condition: condition,
            cloudCover: cloudCover
        )
        let ink = SkyInk.resolve(
            headerLuminance: palette.headerLuminance,
            darkVeil: colorScheme == .dark ? 0.12 : 0.0
        )
        return ink == .light ? .white : Color(red: 0.105, green: 0.105, blue: 0.20)
    }
}
