import ActivityKit
import AppIntents
import CoreLocation
import os
import SwiftUI
import WidgetKit

struct ZmanProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim.Widgets", category: "ZmanProvider")

    func placeholder(in context: Context) -> ZmanEntry {
        ZmanEntry(date: .now, snapshot: demoSnapshot, state: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZmanEntry) -> Void) {
        if let cached = AppGroupStore.loadSnapshot(), !cached.items.isEmpty {
            completion(ZmanEntry(date: .now, snapshot: cached, state: nil))
        } else {
            completion(ZmanEntry(date: .now, snapshot: demoSnapshot, state: nil))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZmanEntry>) -> Void) {
        Task { @MainActor in
            let now = Date()
            let cached = AppGroupStore.loadSnapshot()

            // 1. Fast path: fresh valid snapshot from today
            if let cached, isSnapshotFresh(cached, now: now) {
                #if DEBUG
                Self.logger.debug("Using fresh App Group snapshot (\(cached.items.count) items)")
                #endif
                completion(makeTimeline(snapshot: cached, now: now, state: nil))
                return
            }

            // 2. Refresh path: missing, stale, or different-day snapshot
            let fetcher = WidgetLocationFetcher()
            let state = fetcher.currentState

            #if DEBUG
            Self.logger.debug("Attempting widget refresh. Location state: \(String(describing: state), privacy: .public)")
            #endif

            if case .authorized = state {
                if let location = await fetcher.requestOneShotLocation(timeoutSeconds: 4.0) {
                    let timeZone = TimeZone.current
                    do {
                        let items = try await HebcalService.fetchDays(
                            location: location,
                            timeZone: timeZone,
                            starting: now,
                            count: 2
                        )
                        if !items.isEmpty {
                            let snapshot = ZmanSnapshot(
                                cityName: "המיקום הנוכחי",
                                timeZoneID: timeZone.identifier,
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude,
                                updatedAt: now,
                                items: items
                            )
                            // Best-effort cache save (does not fail if App Group is unavailable)
                            AppGroupStore.saveSnapshot(snapshot)
                            #if DEBUG
                            Self.logger.notice("Widget successfully fetched \(items.count) zmanim from Hebcal")
                            #endif
                            completion(makeTimeline(snapshot: snapshot, now: now, state: nil))
                            return
                        }
                    } catch {
                        #if DEBUG
                        Self.logger.error("Widget Hebcal fetch failed: \(error.localizedDescription, privacy: .public)")
                        #endif
                    }
                }
            }

            // 3. Fallback strategy:
            // If stale cache exists, display stale cache with update note
            if let cached, !cached.items.isEmpty {
                #if DEBUG
                Self.logger.notice("Displaying stale cache as fallback")
                #endif
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                formatter.timeZone = cached.timeZone
                let timeStr = formatter.string(from: cached.updatedAt)
                completion(makeTimeline(snapshot: cached, now: now, state: "עודכן ב-\(timeStr)"))
                return
            }

            // 4. No cache and no fresh data: display clear explanatory state
            let recoveryMessage: String
            switch state {
            case .appAuthorizedWidgetDenied:
                recoveryMessage = "יש לאשר מיקום בווידג'ט"
            case .deniedOrRestricted:
                recoveryMessage = "נדרשת הרשאת מיקום"
            case .notDetermined:
                recoveryMessage = "פתח את האפליקציה לרענון"
            default:
                recoveryMessage = "אין נתוני זמנים זמינים"
            }

            #if DEBUG
            Self.logger.notice("Displaying empty recovery state: \(recoveryMessage, privacy: .public)")
            #endif
            let entry = ZmanEntry(date: now, snapshot: nil, state: recoveryMessage)
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300))))
        }
    }

    private func isSnapshotFresh(_ snapshot: ZmanSnapshot, now: Date) -> Bool {
        guard !snapshot.items.isEmpty else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = snapshot.timeZone
        // Snapshot is considered fresh if it was updated today and has upcoming items or is recent
        let isToday = cal.isDate(snapshot.updatedAt, inSameDayAs: now)
        let hasUpcoming = snapshot.items.contains(where: { $0.date > now })
        return isToday && hasUpcoming
    }

    private func makeTimeline(snapshot: ZmanSnapshot, now: Date, state: String?) -> Timeline<ZmanEntry> {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = snapshot.timeZone

        // Create entries for now and at upcoming zmanim transitions today
        var dates: [Date] = [now]
        let upcomingItems = snapshot.items.filter { $0.date > now }

        for item in upcomingItems {
            dates.append(item.date)
        }

        // Add midnight rollover entry
        if let nextMidnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
            dates.append(nextMidnight)
        }

        dates.sort()
        // Deduplicate timestamps within 10 seconds of each other
        var uniqueDates: [Date] = []
        for d in dates {
            if let last = uniqueDates.last {
                if d.timeIntervalSince(last) >= 10 {
                    uniqueDates.append(d)
                }
            } else {
                uniqueDates.append(d)
            }
        }

        let entries = uniqueDates.map { ZmanEntry(date: $0, snapshot: snapshot, state: state) }

        // Refresh at the next day rollover or in at most 4 hours
        let nextMidnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
        let refreshDate = min(nextMidnight ?? now.addingTimeInterval(14400), now.addingTimeInterval(14400))

        return Timeline(entries: entries, policy: .after(refreshDate))
    }

    private var demoSnapshot: ZmanSnapshot {
        let now = Date()
        return ZmanSnapshot(
            cityName: "ירושלים",
            timeZoneID: TimeZone(identifier: "Asia/Jerusalem")?.identifier ?? TimeZone.current.identifier,
            latitude: 31.778,
            longitude: 35.235,
            updatedAt: now,
            items: [
                ZmanItem(key: "sunrise", hebrewTitle: "הנץ החמה", englishTitle: "Sunrise", icon: "sunrise.fill", date: now.addingTimeInterval(-7200)),
                ZmanItem(key: "chatzot", hebrewTitle: "חצות היום", englishTitle: "Chatzot", icon: "sun.max.fill", date: now.addingTimeInterval(3600)),
                ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill", date: now.addingTimeInterval(7200)),
                ZmanItem(key: "tzeit7083deg", hebrewTitle: "צאת הכוכבים", englishTitle: "Tzeit", icon: "moon.fill", date: now.addingTimeInterval(9000))
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
