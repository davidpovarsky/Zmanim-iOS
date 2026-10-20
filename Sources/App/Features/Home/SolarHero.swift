import SwiftUI

public struct SolarHero: View {
    public let now: Date
    public let items: [ZmanItem]
    public let city: String
    public let timeZone: TimeZone
    @Environment(\.layoutDirection) private var layoutDirection

    public init(
        now: Date,
        items: [ZmanItem],
        city: String,
        timeZone: TimeZone
    ) {
        self.now = now
        self.items = items
        self.city = city
        self.timeZone = timeZone
    }

    private var sunrise: Date? { items.first { $0.key == "sunrise" }?.date }
    private var sunset: Date? { items.first { $0.key == "sunset" }?.date }
    private var phase: SolarPhase { SolarPhase.resolve(now: now, sunrise: sunrise, sunset: sunset) }
    private var isRTL: Bool { layoutDirection == .rightToLeft }

    public var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let arc = SolarArcGeometry(
                    size: geometry.size,
                    margin: max(16, min(geometry.size.width * 0.08, 32)),
                    base: geometry.size.height - 24,
                    arcHeight: max(35, min(geometry.size.height * 0.65, 80)),
                    isRTL: isRTL
                )

                ZStack {
                    // Passive horizon line
                    arc.fullPath()
                        .stroke(
                            Color.zmanInk.opacity(0.14),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )

                    // Active progress path (strictly daytime only)
                    if case let .daylight(progress) = phase, progress > 0 {
                        arc.completedPath(progress: progress)
                            .stroke(
                                LinearGradient(
                                    colors: isRTL
                                        ? [Color.zmanOrange, Color.yellow]
                                        : [Color.yellow, Color.zmanOrange],
                                    startPoint: isRTL ? .trailing : .leading,
                                    endPoint: isRTL ? .leading : .trailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )

                        // Sun marker positioned exactly at the tip of the completed arc
                        Circle()
                            .fill(Color.zmanOrange)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "sun.max.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: Color.orange.opacity(0.4), radius: 6)
                            .position(arc.point(at: progress))
                    }

                    // Sunrise and Sunset labels positioned at the curve endpoints
                    if let sunrise {
                        label(NSLocalizedString("sunrise", comment: ""), sunrise)
                            .position(x: arc.startPoint.x + (isRTL ? -20 : 20), y: arc.base + 16)
                    }
                    if let sunset {
                        label(NSLocalizedString("sunset", comment: ""), sunset)
                            .position(x: arc.endPoint.x + (isRTL ? 20 : -20), y: arc.base + 16)
                    }
                }
            }
            .frame(height: 140)

            Text(time(now))
                .font(.system(size: 42, weight: .regular, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)

            if !city.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                    Text(city)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }

    private func label(_ text: String, _ date: Date) -> some View {
        VStack(spacing: 1) {
            Text(text).font(.caption2)
            Text(time(date)).font(.caption.monospacedDigit().bold())
        }
        .foregroundStyle(.secondary)
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
