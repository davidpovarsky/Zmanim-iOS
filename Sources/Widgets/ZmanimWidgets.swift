import ActivityKit
import AppIntents
import CoreLocation
import SwiftUI
import WidgetKit

struct ZmanEntry: TimelineEntry {
    let date: Date
    let snapshot: ZmanSnapshot?
    let state: String?

    var next: ZmanItem? {
        snapshot?.items.first(where: { $0.date > date })
    }
}

final class WidgetLocationLoader: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func location() async -> CLLocation? {
        guard CLLocationManager.locationServicesEnabled() else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}

struct ZmanProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZmanEntry {
        ZmanEntry(date: .now, snapshot: demoSnapshot, state: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZmanEntry) -> Void) {
        completion(ZmanEntry(date: .now, snapshot: AppGroupStore.loadSnapshot() ?? demoSnapshot, state: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZmanEntry>) -> Void) {
        Task {
            let now = Date()

            if let cached = AppGroupStore.loadSnapshot(), !cached.items.isEmpty {
                completion(Timeline(entries: [ZmanEntry(date: now, snapshot: cached, state: nil)], policy: .after(now.addingTimeInterval(900))))
                return
            }

            let loader = WidgetLocationLoader()
            if let location = await loader.location() {
                let timeZone = TimeZone.current
                do {
                    let items = try await WidgetHebcal.fetch(location: location, timeZone: timeZone)
                    let snapshot = ZmanSnapshot(
                        cityName: "המיקום הנוכחי",
                        timeZoneID: timeZone.identifier,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        updatedAt: now,
                        items: items
                    )
                    AppGroupStore.saveSnapshot(snapshot)
                    completion(Timeline(entries: [ZmanEntry(date: now, snapshot: snapshot, state: nil)], policy: .after(now.addingTimeInterval(900))))
                    return
                } catch { }
            }

            completion(Timeline(entries: [ZmanEntry(date: now, snapshot: nil, state: "פתח את האפליקציה לרענון")], policy: .after(now.addingTimeInterval(600))))
        }
    }

    private var demoSnapshot: ZmanSnapshot {
        let now = Date()
        return ZmanSnapshot(
            cityName: "זמנים",
            timeZoneID: TimeZone.current.identifier,
            latitude: 0,
            longitude: 0,
            updatedAt: now,
            items: [
                ZmanItem(key: "sunrise", hebrewTitle: "הנץ החמה", englishTitle: "Sunrise", icon: "sunrise.fill", date: now.addingTimeInterval(-7200)),
                ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill", date: now.addingTimeInterval(7200))
            ]
        )
    }
}

enum WidgetHebcal {
    private struct Response: Decodable { let times: [String: String] }
    private static let definitions: [ZmanDefinition] = [
        .init(key: "alotHaShachar", hebrewTitle: "עלות השחר", englishTitle: "Alot HaShachar", icon: "moon.stars.fill"),
        .init(key: "sunrise", hebrewTitle: "הנץ החמה", englishTitle: "Sunrise", icon: "sunrise.fill"),
        .init(key: "sofZmanShma", hebrewTitle: "סוף זמן ק״ש", englishTitle: "Latest Shema", icon: "book.closed.fill"),
        .init(key: "sofZmanTfilla", hebrewTitle: "סוף זמן תפילה", englishTitle: "Latest Shacharit", icon: "clock.fill"),
        .init(key: "chatzot", hebrewTitle: "חצות היום", englishTitle: "Chatzot", icon: "sun.max.fill"),
        .init(key: "minchaGedola", hebrewTitle: "מנחה גדולה", englishTitle: "Mincha Gedola", icon: "sun.haze.fill"),
        .init(key: "minchaKetana", hebrewTitle: "מנחה קטנה", englishTitle: "Mincha Ketana", icon: "sun.haze.fill"),
        .init(key: "plagHaMincha", hebrewTitle: "פלג המנחה", englishTitle: "Plag HaMincha", icon: "sunset.fill"),
        .init(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill"),
        .init(key: "tzeit7083deg", hebrewTitle: "צאת הכוכבים", englishTitle: "Tzeit", icon: "moon.fill")
    ]

    static func fetch(location: CLLocation, timeZone: TimeZone) async throws -> [ZmanItem] {
        var components = URLComponents(string: "https://www.hebcal.com/zmanim")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        components.queryItems = [
            .init(name: "cfg", value: "json"),
            .init(name: "latitude", value: String(format: "%.6f", location.coordinate.latitude)),
            .init(name: "longitude", value: String(format: "%.6f", location.coordinate.longitude)),
            .init(name: "tzid", value: timeZone.identifier),
            .init(name: "date", value: formatter.string(from: .now)),
            .init(name: "sec", value: "1")
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(Response.self, from: data)
        let parser = ISO8601DateFormatter()
        return definitions.compactMap { definition in
            guard let raw = response.times[definition.key], let date = parser.date(from: raw) else { return nil }
            return ZmanItem(key: definition.key, hebrewTitle: definition.hebrewTitle, englishTitle: definition.englishTitle, icon: definition.icon, date: date)
        }.sorted { $0.date < $1.date }
    }
}

struct ZmanimWidget: Widget {
    let kind = "ZmanimWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZmanProvider()) { entry in
            ZmanWidgetView(entry: entry)
                .containerBackground(Color(red: 0.972, green: 0.966, blue: 0.936), for: .widget)
        }
        .configurationDisplayName("זמני היום")
        .description("הזמן הבא ומסלול השמש.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct ZmanWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ZmanEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryCircular:
            Gauge(value: progress) { Image(systemName: "sun.max.fill") }
                .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text(entry.next?.hebrewTitle ?? "זמנים").bold()
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
        VStack(alignment: .leading, spacing: 8) {
            Text("זמני היום").font(.headline)
            Spacer()
            Image(systemName: entry.next?.icon ?? "sun.max.fill").font(.title2).foregroundStyle(.orange)
            Text(entry.next?.hebrewTitle ?? entry.state ?? "טוען…").font(.headline)
            Text(nextTime).font(.title.monospacedDigit().bold())
            Button(intent: ToggleQuickReminderIntent()) {
                Image(systemName: AppGroupStore.quickReminderEnabled ? "bell.fill" : "bell")
            }
        }
    }

    private var medium: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.snapshot?.cityName ?? "זמני היום").font(.caption).foregroundStyle(.secondary)
                Text(entry.next?.hebrewTitle ?? entry.state ?? "טוען…").font(.title3.bold())
                Text(nextTime).font(.title.monospacedDigit().bold())
                if let next = entry.next { Text(next.date, style: .relative).font(.caption).foregroundStyle(.orange) }
            }
            Spacer()
            SolarMini(snapshot: entry.snapshot, now: entry.date).frame(width: 150, height: 90)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("זמני היום").font(.title2.bold())
                Spacer()
                Text(entry.snapshot?.cityName ?? "").foregroundStyle(.secondary)
            }
            SolarMini(snapshot: entry.snapshot, now: entry.date).frame(height: 110)
            if let snapshot = entry.snapshot {
                ForEach(Array(snapshot.items.filter { $0.date > entry.date }.prefix(5))) { item in
                    HStack {
                        Image(systemName: item.icon).frame(width: 25)
                        Text(item.hebrewTitle)
                        Spacer()
                        Text(time(item.date)).monospacedDigit()
                    }
                }
            } else {
                ContentUnavailableView("אין עדיין נתונים", systemImage: "location.slash", description: Text(entry.state ?? "פתח את האפליקציה לרענון"))
            }
            Spacer()
        }
    }

    private var inlineText: String { "\(entry.next?.hebrewTitle ?? "זמנים") \(nextTime)" }
    private var nextTime: String { entry.next.map { time($0.date) } ?? "--:--" }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = entry.snapshot?.timeZone ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var progress: Double {
        guard let sunrise = entry.snapshot?.items.first(where: { $0.key == "sunrise" })?.date,
              let sunset = entry.snapshot?.items.first(where: { $0.key == "sunset" })?.date,
              sunset > sunrise else { return 0 }
        return min(max(entry.date.timeIntervalSince(sunrise) / sunset.timeIntervalSince(sunrise), 0), 1)
    }
}

private struct SolarMini: View {
    let snapshot: ZmanSnapshot?
    let now: Date

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width - 8, y: geometry.size.height - 8))
                    path.addQuadCurve(
                        to: CGPoint(x: 8, y: geometry.size.height - 8),
                        control: CGPoint(x: geometry.size.width / 2, y: -geometry.size.height / 2)
                    )
                }
                .stroke(.secondary.opacity(0.25), lineWidth: 2)

                Circle()
                    .fill(.orange)
                    .frame(width: 18, height: 18)
                    .position(
                        x: geometry.size.width * (1 - CGFloat(progress)),
                        y: max(10, geometry.size.height - 8 - sin(.pi * progress) * (geometry.size.height - 20))
                    )
            }
        }
    }

    private var progress: Double {
        guard let sunrise = snapshot?.items.first(where: { $0.key == "sunrise" })?.date,
              let sunset = snapshot?.items.first(where: { $0.key == "sunset" })?.date,
              sunset > sunrise else { return 0 }
        return min(max(now.timeIntervalSince(sunrise) / sunset.timeIntervalSince(sunrise), 0), 1)
    }
}

struct ZmanimLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ZmanimActivityAttributes.self) { context in
            HStack {
                Image(systemName: context.state.icon).foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text(context.state.title).bold()
                    Text(timerInterval: Date()...context.state.targetDate, countsDown: true).monospacedDigit()
                }
                Spacer()
                Text(context.attributes.cityName).font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .activityBackgroundTint(.zmanBackground)
            .activitySystemActionForegroundColor(.zmanIndigo)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: context.state.icon).foregroundStyle(.orange) }
                DynamicIslandExpandedRegion(.center) { Text(context.state.title).bold() }
                DynamicIslandExpandedRegion(.trailing) { Text(timerInterval: Date()...context.state.targetDate, countsDown: true).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) { Text(context.attributes.cityName).font(.caption) }
            } compactLeading: {
                Image(systemName: context.state.icon)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.targetDate, countsDown: true).monospacedDigit().frame(width: 48)
            } minimal: {
                Image(systemName: "sun.max.fill")
            }
        }
    }
}

@main
struct ZmanimWidgetBundle: WidgetBundle {
    var body: some Widget {
        ZmanimWidget()
        ZmanimLiveActivityWidget()
    }
}
