import ActivityKit
import AppIntents
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

struct ZmanProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZmanEntry {
        ZmanEntry(date: .now, snapshot: demoSnapshot, state: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZmanEntry) -> Void) {
        completion(ZmanEntry(date: .now, snapshot: AppGroupStore.loadSnapshot(), state: "פתח את האפליקציה לרענון"))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZmanEntry>) -> Void) {
        let now = Date()
        if let cached = AppGroupStore.loadSnapshot(), !cached.items.isEmpty {
            completion(Timeline(entries: [ZmanEntry(date: now, snapshot: cached, state: nil)], policy: .after(now.addingTimeInterval(900))))
        } else {
            // Widgets must not request location or perform network work. The app owns
            // computation and publishes a validated snapshot through the App Group.
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
            if let snapshot = entry.snapshot {
                SolarMini(snapshot: snapshot, now: entry.date).frame(width: 150, height: 90)
            } else {
                ContentUnavailableView("אין נתונים", systemImage: "location.slash", description: Text(entry.state ?? "פתח את האפליקציה לרענון"))
                    .frame(width: 150, height: 90)
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("זמני היום").font(.title2.bold())
                Spacer()
                Text(entry.snapshot?.cityName ?? "").foregroundStyle(.secondary)
            }
            if let snapshot = entry.snapshot {
                SolarMini(snapshot: snapshot, now: entry.date).frame(height: 110)
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
