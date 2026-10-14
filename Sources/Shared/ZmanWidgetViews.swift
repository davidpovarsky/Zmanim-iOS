import SwiftUI
import WidgetKit

struct ZmanEntry: TimelineEntry {
    let date: Date
    let snapshot: ZmanSnapshot?
    let state: String?

    init(date: Date, snapshot: ZmanSnapshot?, state: String?) {
        self.date = date
        self.snapshot = snapshot
        self.state = state
    }

    var next: ZmanItem? {
        snapshot?.items.first(where: { $0.date > date })
    }
}

struct ZmanWidgetView: View {
    @Environment(\.widgetFamily) private var envFamily
    let entry: ZmanEntry
    var explicitFamily: WidgetFamily? = nil

    init(entry: ZmanEntry, explicitFamily: WidgetFamily? = nil) {
        self.entry = entry
        self.explicitFamily = explicitFamily
    }

    private var activeFamily: WidgetFamily {
        explicitFamily ?? envFamily
    }

    var body: some View {
        switch activeFamily {
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

    var small: some View {
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

    var medium: some View {
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

    var large: some View {
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

struct SolarMini: View {
    let snapshot: ZmanSnapshot?
    let now: Date

    init(snapshot: ZmanSnapshot?, now: Date) {
        self.snapshot = snapshot
        self.now = now
    }

    var body: some View {
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
        guard let sunrise = snapshot?.items.first(where: { $0.key == "sunrise" })?.date,
              let sunset = snapshot?.items.first(where: { $0.key == "sunset" })?.date else { return 0 }
        return SolarArcGeometry.progress(now: now, sunrise: sunrise, sunset: sunset)
    }
}
