import SwiftUI
import WidgetKit

public struct ZmanEntry: TimelineEntry, Sendable {
    public let date: Date
    public let snapshot: ZmanSnapshot?
    public let state: String?
    public let pageIndex: Int
    public let pageCount: Int
    public let expiresAt: Date?
    public let isGPS: Bool
    public let locationKey: String
    public let customCityName: String?
    public let isPlaceholder: Bool

    public init(
        date: Date,
        snapshot: ZmanSnapshot?,
        state: String? = nil,
        pageIndex: Int = 0,
        pageCount: Int = 1,
        expiresAt: Date? = nil,
        isGPS: Bool = false,
        locationKey: String = "default",
        customCityName: String? = nil,
        isPlaceholder: Bool = false
    ) {
        self.date = date
        self.snapshot = snapshot
        self.state = state
        self.pageIndex = pageIndex
        self.pageCount = pageCount
        self.expiresAt = expiresAt
        self.isGPS = isGPS
        self.locationKey = locationKey
        self.customCityName = customCityName
        self.isPlaceholder = isPlaceholder
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

    private var displayCityName: String {
        if let custom = entry.customCityName, !custom.isEmpty {
            return custom
        }
        if let name = entry.snapshot?.cityName, !name.isEmpty {
            return name
        }
        if entry.isGPS {
            return NSLocalizedString("location.current", comment: "")
        }
        return ""
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
                Text(entry.next?.displayTitle ?? NSLocalizedString("app_name", comment: "")).bold()
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
                Text(LocalizedStringKey("daily_zmanim")).font(.headline)
                Spacer()
                Image(systemName: entry.next?.icon ?? "sun.max.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            Spacer()
            if entry.isPlaceholder {
                placeholderSmall
            } else if let next = entry.next {
                Text(next.displayTitle).font(.headline)
                Text(nextTime).font(.title.monospacedDigit().bold())
            } else if let state = entry.state {
                Text(state).font(.caption).foregroundStyle(.secondary)
            } else {
                Text(LocalizedStringKey("widget.no_data")).font(.headline)
            }
            Spacer()
            HStack(spacing: 4) {
                if entry.isGPS {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(displayCityName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
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
                HStack(spacing: 4) {
                    if entry.isGPS {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(!displayCityName.isEmpty ? displayCityName : NSLocalizedString("daily_zmanim", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if entry.isPlaceholder {
                    placeholderMedium
                } else if let next = entry.next {
                    Text(next.displayTitle).font(.title3.bold())
                    Text(nextTime).font(.title.monospacedDigit().bold())
                    Text(next.date, style: .relative).font(.caption).foregroundStyle(.orange)
                } else {
                    Text(entry.state ?? NSLocalizedString("widget.no_data", comment: "")).font(.title3.bold())
                }
            }
            Spacer()
            if let snapshot = entry.snapshot {
                SolarMini(snapshot: snapshot, now: entry.date).frame(width: 150, height: 90)
            } else if entry.isPlaceholder {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 150, height: 90)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("widget.no_data", comment: ""),
                    systemImage: "location.slash",
                    description: Text(entry.state ?? NSLocalizedString("widget.open_app_to_refresh", comment: ""))
                )
                .frame(width: 150, height: 90)
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LocalizedStringKey("daily_zmanim")).font(.title2.bold())
                Spacer()
                HStack(spacing: 4) {
                    if entry.isGPS {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(displayCityName).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            if entry.isPlaceholder {
                placeholderLarge
            } else if let snapshot = entry.snapshot {
                SolarMini(snapshot: snapshot, now: entry.date).frame(height: 85)

                let pager = UpcomingZmanPager(
                    allItems: snapshot.items,
                    referenceDate: entry.date,
                    timeZone: snapshot.timeZone
                )
                let itemsToShow = pager.items(for: entry.pageIndex)

                VStack(spacing: 6) {
                    ForEach(itemsToShow) { upcoming in
                        HStack {
                            Image(systemName: upcoming.item.icon)
                                .font(.system(size: 15))
                                .frame(width: 25)
                                .foregroundStyle(upcoming.item.date > entry.date ? Color.primary : Color.secondary)
                            Text(upcoming.item.displayTitle)
                                .font(.subheadline)
                                .foregroundStyle(upcoming.item.date > entry.date ? Color.primary : Color.secondary)
                            if let label = upcoming.dayLabel {
                                Text(label)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.18))
                                    .foregroundStyle(Color.orange)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Text(time(upcoming.item.date))
                                .monospacedDigit()
                                .font(.subheadline.bold())
                                .foregroundStyle(upcoming.item.date > entry.date ? Color.primary : Color.secondary)
                        }
                    }
                }

                Spacer(minLength: 4)

                // Interactive cyclic paging controls (chevron down / chevron up)
                if pager.pageCount > 1 {
                    HStack {
                        Spacer()
                        Button(intent: PreviousWidgetPageIntent(locationKey: entry.locationKey)) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 44, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(NSLocalizedString("widget.a11y.previous_page", comment: ""))

                        Button(intent: NextWidgetPageIntent(locationKey: entry.locationKey)) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 44, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(NSLocalizedString("widget.a11y.next_page", comment: ""))

                        Spacer()
                    }
                }
            } else {
                ContentUnavailableView(
                    NSLocalizedString("widget.no_data", comment: ""),
                    systemImage: "location.slash",
                    description: Text(entry.state ?? NSLocalizedString("widget.open_app_to_refresh", comment: ""))
                )
            }

            if let state = entry.state, entry.snapshot != nil {
                Text(state).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var placeholderSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2)).frame(width: 70, height: 16)
            RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.25)).frame(width: 50, height: 24)
        }
        .redacted(reason: .placeholder)
    }

    private var placeholderMedium: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2)).frame(width: 100, height: 18)
            RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.25)).frame(width: 70, height: 26)
        }
        .redacted(reason: .placeholder)
    }

    private var placeholderLarge: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.15)).frame(height: 75)
            ForEach(0..<5) { _ in
                HStack {
                    Circle().fill(Color.secondary.opacity(0.2)).frame(width: 16, height: 16)
                    RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2)).frame(width: 90, height: 14)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2)).frame(width: 40, height: 14)
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    private var inlineText: String {
        if let next = entry.next {
            return "\(next.displayTitle) \(nextTime)"
        }
        return NSLocalizedString("app_name", comment: "")
    }

    private var nextTime: String {
        guard let next = entry.next else { return "--:--" }
        return time(next.date)
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = entry.snapshot?.timeZone ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var progress: Double {
        guard let snapshot = entry.snapshot,
              let sunrise = snapshot.items.first(where: { $0.key == "sunrise" })?.date,
              let sunset = snapshot.items.first(where: { $0.key == "sunset" })?.date,
              sunset > sunrise else {
            return 0
        }
        let total = sunset.timeIntervalSince(sunrise)
        let elapsed = entry.date.timeIntervalSince(sunrise)
        return min(max(elapsed / total, 0), 1)
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
                arcHeight: geometry.size.height - 24,
                isRTL: isRTL
            )
            let p = phase.progress

            ZStack {
                arc.fullPath()
                    .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                if phase.isDaylight && p > 0 {
                    arc.completedPath(progress: p)
                        .stroke(
                            LinearGradient(
                                colors: isRTL ? [Color.orange, Color.yellow] : [Color.yellow, Color.orange],
                                startPoint: isRTL ? .trailing : .leading,
                                endPoint: isRTL ? .leading : .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )

                    let sunPoint = arc.point(at: p)
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                        )
                        .shadow(color: Color.orange.opacity(0.35), radius: 4)
                        .position(sunPoint)
                }
            }
        }
    }

    private var isRTL: Bool {
        let lang = Locale.autoupdatingCurrent.language.languageCode?.identifier ?? ""
        return lang == "he" || Locale.autoupdatingCurrent.identifier.hasPrefix("he")
    }

    private var phase: SolarPhase {
        guard let snapshot else { return .unavailable }
        let tz = snapshot.timeZone
        guard let sunrise = ZmanDayResolver.sunrise(from: snapshot.items, date: now, timeZone: tz),
              let sunset = ZmanDayResolver.sunset(from: snapshot.items, date: now, timeZone: tz) else {
            return .unavailable
        }
        return SolarPhase.resolve(now: now, sunrise: sunrise, sunset: sunset)
    }
}
