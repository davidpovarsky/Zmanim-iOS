import SwiftUI
import SwiftUISky
import UserNotifications

/// The same SkyBackdrop and SolarArcGeometry used by the main app.
struct NotificationSolarView: View {
    let title: String
    let icon: String
    let target: Date?
    let sunrise: Date?
    let sunset: Date?
    let city: String
    let sky: NotificationSkyState?
    let notificationID: String

    @Environment(\.layoutDirection) private var direction

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { timeline in
            let now = timeline.date
            let phase = SolarPhase.resolve(now: now, sunrise: sunrise, sunset: sunset)
            ZStack {
                SkyBackdrop(
                    date: now,
                    actualSunrise: sunrise,
                    actualSunset: sunset,
                    condition: skyCondition,
                    cloudCover: sky?.cloudCover ?? 0.2,
                    pageColor: Color(red: 0.972, green: 0.966, blue: 0.936),
                    customHeight: 310
                )
                VStack(spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.headline)
                            if let target {
                                Text(target, format: .dateTime.hour().minute())
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                        Spacer()
                        if let target {
                            Text(remaining(until: target, now: now))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    GeometryReader { geometry in
                        let arc = SolarArcGeometry(
                            size: geometry.size,
                            margin: max(16, min(geometry.size.width * 0.08, 32)),
                            base: geometry.size.height - 24,
                            arcHeight: max(35, min(geometry.size.height * 0.65, 80)),
                            isRTL: direction == .rightToLeft
                        )
                        ZStack {
                            arc.fullPath()
                                .stroke(.primary.opacity(0.16), lineWidth: 2)
                            if case let .daylight(progress) = phase {
                                arc.completedPath(progress: progress)
                                    .stroke(LinearGradient(colors: [.yellow, .orange],
                                                           startPoint: .leading, endPoint: .trailing),
                                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                Image(systemName: "sun.max.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(.orange))
                                    .position(arc.point(at: progress))
                            }
                            if let sunrise {
                                endpoint("זריחה", sunrise)
                                    .position(x: arc.startPoint.x + (direction == .rightToLeft ? -20 : 20),
                                              y: arc.base + 16)
                            }
                            if let sunset {
                                endpoint("שקיעה", sunset)
                                    .position(x: arc.endPoint.x + (direction == .rightToLeft ? 20 : -20),
                                              y: arc.base + 16)
                            }
                        }
                    }
                    .frame(height: 105)
                    HStack {
                        Spacer()
                        Text(now, format: .dateTime.hour().minute())
                            .font(.title2.monospacedDigit())
                        if !city.isEmpty {
                            Text(city).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(16)
            }
        }
    }

    private var skyCondition: SkyWeatherCondition {
        guard let sky else { return .clear }
        switch sky.condition {
        case "partlyCloudy": return .partlyCloudy
        case "overcast": return .overcast
        case "rain": return .rain
        case "snow": return .snow
        case "fog": return .fog
        case "thunderstorm": return .thunderstorm
        default: return .clear
        }
    }

    private func endpoint(_ title: String, _ time: Date) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 10))
            Text(time, format: .dateTime.hour().minute())
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(.secondary)
    }

    private func remaining(until target: Date, now: Date) -> String {
        let seconds = target.timeIntervalSince(now)
        if seconds <= 0 { return "הזמן עבר" }
        let minutes = Int(ceil(seconds / 60))
        return minutes >= 60 ? "בעוד " + String(minutes / 60) + " שעות ו-" + String(minutes % 60) + " דקות"
            : "בעוד " + String(minutes) + " דקות"
    }
}