import SwiftUI
import WidgetKit

public struct ZmanEntry: TimelineEntry, Sendable {
    public let date: Date
    public let snapshot: ZmanSnapshot?
    public let state: String?
    public let pageIndex: Int
    public let pageCount: Int
    public let expiresAt: Date?

    public init(
        date: Date,
        snapshot: ZmanSnapshot?,
        state: String?,
        pageIndex: Int = 0,
        pageCount: Int = 1,
        expiresAt: Date? = nil
    ) {
        self.date = date
        self.snapshot = snapshot
        self.state = state
        self.pageIndex = pageIndex
        self.pageCount = pageCount
        self.expiresAt = expiresAt
    }

    public var next: ZmanItem? {
        guard let snapshot else { return nil }
        return NextZmanResolver.resolve(
            allItems: snapshot.items,
            now: date,
            timeZone: snapshot.timeZone
        )?.item
    }
}

public struct ZmanWidgetView: View {
    @Environment(\.widgetFamily) private var envFamily
    public let entry: ZmanEntry
    public var explicitFamily: WidgetFamily? = nil

    public init(entry: ZmanEntry, explicitFamily: WidgetFamily? = nil) {
        self.entry = entry
        self.explicitFamily = explicitFamily
    }

    private var activeFamily: WidgetFamily {
        explicitFamily ?? envFamily
    }

    public var body: some View {
        switch activeFamily {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryCircular:
            Gauge(value: progress) { Image(systemName: "sun.max.fill") }
                .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text(entry.next?.displayTitle ?? NSLocalizedString("app_name", value: "זמנים", comment: "")).bold()
                Text(nextTime).monospacedDigit()
                if let next = entry.next { Text(next.date, style: .relative).font(.caption2) }
            }
        case .systemSmall:
            small
        case .systemMedium:
            medium
        default:
            large
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("daily_zmanim").font(.headline)
                Spacer()
                Image(systemName: entry.next?.icon ?? "sun.max.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            Spacer()
            if let next = entry.next {
                Text(next.displayTitle).font(.headline)
                Text(nextTime).font(.title.monospacedDigit().bold())
            } else if let state = entry.state {
                Text(state).font(.caption).foregroundStyle(.secondary)
                Text(nextTime).font(.title2.monospacedDigit())
            } else {
                Text("widget.no_data").font(.headline)
                Text("--:--").font(.title.monospacedDigit())
            }
            Spacer()
            HStack {
                Text(entry.snapshot?.cityName ?? "").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button(intent: ToggleQuickReminderIntent()) {
                    Image(systemName: AppGroupStore.quickReminderEnabled ? "bell.fill" : "bell")
                }
                .font(.caption)
            }
        }
    }

    private var medium: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.snapshot?.cityName.isEmpty == false ? entry.snapshot!.cityName : NSLocalizedString("daily_zmanim", value: "זמני היום", comment: "")).font(.caption).foregroundStyle(.secondary)
                if let next = entry.next {
                    Text(next.displayTitle).font(.title3.bold())
                    Text(nextTime).font(.title.monospacedDigit().bold())
                    Text(next.date, style: .relative).font(.caption).foregroundStyle(.orange)
                } else {
                    Text(entry.state ?? NSLocalizedString("widget.no_data", value: "אין נתונים", comment: "")).font(.title3.bold())
                    Text(nextTime).font(.title.monospacedDigit().bold())
                }
            }
            Spacer()
            if let snapshot = entry.snapshot {
                SolarMini(snapshot: snapshot, now: entry.date).frame(width: 150, height: 90)
            } else {
                ContentUnavailableView(String(localized: "widget.no_data"), systemImage: "location.slash", description: Text(entry.state ?? NSLocalizedString("widget.open_app_to_refresh", value: "פתח את האפליקציה לרענון", comment: "")))
                    .frame(width: 150, height: 90)
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("daily_zmanim").font(.title2.bold())
                Spacer()
                Text(entry.snapshot?.cityName ?? "").foregroundStyle(.secondary)
            }

            if let snapshot = entry.snapshot {
                SolarMini(snapshot: snapshot, now: entry.date).frame(height: 85)

                let selector = WidgetDaySelector(
                    allItems: snapshot.items,
                    referenceDate: entry.date,
                    timeZone: snapshot.timeZone
                )
                let itemsToShow = selector.items(for: entry.pageIndex)

                VStack(spacing: 6) {
                    ForEach(itemsToShow) { item in
                        HStack {
                            Image(systemName: item.icon)
                                .font(.system(size: 15))
                                .frame(width: 25)
                                .foregroundStyle(item.date > entry.date ? Color.primary : Color.secondary)
                            Text(item.displayTitle)
                                .font(.subheadline)
                                .foregroundStyle(item.date > entry.date ? Color.primary : Color.secondary)
                            Spacer()
                            Text(time(item.date))
                                .monospacedDigit()
                                .font(.subheadline.bold())
                                .foregroundStyle(item.date > entry.date ? Color.primary : Color.secondary)
                        }
                    }
                }

                Spacer(minLength: 4)

                // Interactive paging controls (chevron down / chevron up) as marked in reference image
                if selector.pageCount > 1 {
                    HStack {
                        Spacer()
                        if entry.pageIndex > 0 {
                            Button(intent: PreviousWidgetPageIntent()) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.secondary)
                                    .frame(width: 44, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "widget.a11y.previous_page"))
                        }

                        Button(intent: NextWidgetPageIntent()) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 44, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "widget.a11y.next_page"))

                        Spacer()
                    }
                }
            } else {
                ContentUnavailableView(String(localized: "no_zmanim_data"), systemImage: "location.slash", description: Text(entry.state ?? NSLocalizedString("widget.open_app_to_refresh", value: "פתח את האפליקציה לרענון", comment: "")))
            }

            if let state = entry.state, entry.snapshot != nil {
                Text(state).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var inlineText: String { "\(entry.next?.displayTitle ?? NSLocalizedString("app_name", value: "זמנים", comment: "")) \(nextTime)" }
    private var nextTime: String { entry.next.map { time($0.date) } ?? "--:--" }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = entry.snapshot?.timeZone ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var progress: Double {
        guard let snapshot = entry.snapshot else { return 0 }
        let tz = snapshot.timeZone
        guard let sunrise = ZmanDayResolver.sunrise(from: snapshot.items, date: entry.date, timeZone: tz),
              let sunset = ZmanDayResolver.sunset(from: snapshot.items, date: entry.date, timeZone: tz),
              sunset > sunrise else { return 0 }
        return min(max(entry.date.timeIntervalSince(sunrise) / sunset.timeIntervalSince(sunrise), 0), 1)
    }
}

public struct SolarMini: View {
    public let snapshot: ZmanSnapshot?
    public let now: Date

    public init(snapshot: ZmanSnapshot?, now: Date) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        GeometryReader { geometry in
            let arc = SolarArcGeometry(
                size: geometry.size,
                margin: 10,
                base: geometry.size.height - 12,
                arcHeight: geometry.size.height - 24
            )
            let p = progress

            ZStack {
                arc.fullPath()
                    .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                if p > 0 {
                    arc.completedPath(progress: p)
                        .stroke(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                }

                let sunPoint = arc.point(at: p)
                Circle()
                    .fill(Color.orange)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    )
                    .shadow(color: Color.orange.opacity(0.35), radius: 4)
                    .position(sunPoint)
            }
        }
    }

    private var progress: Double {
        guard let snapshot else { return 0 }
        let tz = snapshot.timeZone
        guard let sunrise = ZmanDayResolver.sunrise(from: snapshot.items, date: now, timeZone: tz),
              let sunset = ZmanDayResolver.sunset(from: snapshot.items, date: now, timeZone: tz) else {
            return 0
        }
        return SolarArcGeometry.progress(now: now, sunrise: sunrise, sunset: sunset)
    }
}
