import SwiftUI
import WidgetKit

public struct ZmanEntry: TimelineEntry {
    public let date: Date
    public let snapshot: ZmanSnapshot?
    public let state: String?

    public init(date: Date, snapshot: ZmanSnapshot?, state: String?) {
        self.date = date
        self.snapshot = snapshot
        self.state = state
    }

    public var next: ZmanItem? {
        snapshot?.items.first(where: { $0.date > date })
    }
}

public struct ZmanWidgetView: View {
    @Environment(\.widgetFamily) private var family
    public let entry: ZmanEntry

    public init(entry: ZmanEntry) {
        self.entry = entry
    }

    public var body: some View {
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

    public var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("זמני היום").font(.headline)
                Spacer()
                Image(systemName: entry.next?.icon ?? "sun.max.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            Spacer()
            if let next = entry.next {
                Text(next.hebrewTitle).font(.headline)
                Text(nextTime).font(.title.monospacedDigit().bold())
            } else if let state = entry.state {
                Text(state).font(.caption).foregroundStyle(.secondary)
                Text(nextTime).font(.title2.monospacedDigit())
            } else {
                Text("טוען…").font(.headline)
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

    public var medium: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.snapshot?.cityName ?? "זמני היום").font(.caption).foregroundStyle(.secondary)
                if let next = entry.next {
                    Text(next.hebrewTitle).font(.title3.bold())
                    Text(nextTime).font(.title.monospacedDigit().bold())
                    Text(next.date, style: .relative).font(.caption).foregroundStyle(.orange)
                } else {
                    Text(entry.state ?? "טוען…").font(.title3.bold())
                    Text(nextTime).font(.title.monospacedDigit().bold())
                }
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

    public var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("זמני היום").font(.title2.bold())
                Spacer()
                Text(entry.snapshot?.cityName ?? "").foregroundStyle(.secondary)
            }
            if let snapshot = entry.snapshot {
                SolarMini(snapshot: snapshot, now: entry.date).frame(height: 90)
                let upcoming = snapshot.items.filter { $0.date > entry.date }
                let itemsToShow = upcoming.isEmpty ? Array(snapshot.items.suffix(5)) : Array(upcoming.prefix(5))
                ForEach(itemsToShow) { item in
                    HStack {
                        Image(systemName: item.icon).frame(width: 25)
                        Text(item.hebrewTitle)
                        Spacer()
                        Text(time(item.date)).monospacedDigit()
                    }
                    .font(.subheadline)
                }
            } else {
                ContentUnavailableView("אין עדיין נתונים", systemImage: "location.slash", description: Text(entry.state ?? "פתח את האפליקציה לרענון"))
            }
            if let state = entry.state, entry.snapshot != nil {
                Text(state).font(.caption2).foregroundStyle(.secondary)
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

public struct SolarMini: View {
    public let snapshot: ZmanSnapshot?
    public let now: Date

    public init(snapshot: ZmanSnapshot?, now: Date) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
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
