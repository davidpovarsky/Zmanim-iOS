import ActivityKit
import AppIntents
import CoreLocation
import os
import SwiftUI
import WidgetKit

struct ZmanProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim.Widgets", category: "ZmanProvider")

    func placeholder(in context: Context) -> ZmanEntry {
        ZmanEntry(date: .now, snapshot: demoSnapshot, state: nil, pageIndex: 0, pageCount: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZmanEntry) -> Void) {
        if let cached = AppGroupStore.loadSnapshot(), !cached.items.isEmpty {
            let selector = WidgetDaySelector(
                allItems: cached.items,
                referenceDate: .now,
                timeZone: cached.timeZone
            )
            completion(ZmanEntry(date: .now, snapshot: cached, state: nil, pageIndex: 0, pageCount: selector.pageCount))
        } else if context.isPreview {
            completion(ZmanEntry(date: .now, snapshot: demoSnapshot, state: nil, pageIndex: 0, pageCount: 1))
        } else {
            completion(ZmanEntry(
                date: .now,
                snapshot: nil,
                state: NSLocalizedString("widget.open_app_to_refresh", value: "פתח את האפליקציה לרענון", comment: ""),
                pageIndex: 0,
                pageCount: 1
            ))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZmanEntry>) -> Void) {
        Task { @MainActor in
            let now = Date()
            let cached = AppGroupStore.loadSnapshot()
            let settings = AppGroupStore.loadSettings()
            let pageState = WidgetPageStateStore.loadState()

            // 1. Fixed city mode: strictly use shared snapshot without invoking GPS
            if settings.locationMode == .fixed && !settings.fixedCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let cached, !cached.items.isEmpty {
                    let stateNote = isSnapshotFresh(cached, now: now) ? nil : formatStaleNote(for: cached)
                    completion(makeTimeline(snapshot: cached, now: now, state: stateNote, pageState: pageState))
                    return
                } else {
                    let recovery = String(format: NSLocalizedString("widget.open_app_to_refresh_city_format", value: "פתח את האפליקציה לרענון %@", comment: ""), settings.fixedCity)
                    let entry = ZmanEntry(date: now, snapshot: nil, state: recovery, pageIndex: 0, pageCount: 1)
                    completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300))))
                    return
                }
            }

            // 2. Current GPS location mode: fast path with fresh snapshot
            if let cached, isSnapshotFresh(cached, now: now) {
                #if DEBUG
                Self.logger.debug("Using fresh App Group snapshot (\(cached.items.count) items)")
                #endif
                completion(makeTimeline(snapshot: cached, now: now, state: nil, pageState: pageState))
                return
            }

            // 3. Refresh path: missing or stale snapshot with GPS authorization
            let fetcher = WidgetLocationFetcher()
            let state = fetcher.currentState

            #if DEBUG
            Self.logger.debug("Attempting widget refresh. Location state: \(String(describing: state), privacy: .public)")
            #endif

            if case .authorized = state {
                if let location = await fetcher.requestOneShotLocation(timeoutSeconds: 4.0) {
                    var resolvedZone: TimeZone? = nil
                    if let cached, abs(cached.latitude - location.coordinate.latitude) < 0.2, abs(cached.longitude - location.coordinate.longitude) < 0.2 {
                        resolvedZone = cached.timeZone
                    } else if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
                              let tz = placemarks.first?.timeZone {
                        resolvedZone = tz
                    }
                    let timeZone = resolvedZone ?? TimeZone.current
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
                                items: items,
                                locationSignature: "current"
                            )
                            AppGroupStore.saveSnapshot(snapshot)
                            #if DEBUG
                            Self.logger.notice("Widget successfully fetched \(items.count) zmanim from Hebcal")
                            #endif
                            completion(makeTimeline(snapshot: snapshot, now: now, state: nil, pageState: pageState))
                            return
                        }
                    } catch {
                        #if DEBUG
                        Self.logger.error("Widget Hebcal fetch failed: \(error.localizedDescription, privacy: .public)")
                        #endif
                    }
                }
            }

            // 4. Stale cache fallback
            if let cached, !cached.items.isEmpty {
                #if DEBUG
                Self.logger.notice("Displaying stale cache as fallback")
                #endif
                let note = formatStaleNote(for: cached)
                completion(makeTimeline(snapshot: cached, now: now, state: note, pageState: pageState))
                return
            }

            // 5. No cache and no data: show recovery state (never demo Jerusalem)
            let recoveryMessage: String
            switch state {
            case .appAuthorizedWidgetDenied:
                recoveryMessage = NSLocalizedString("widget.location_required", value: "יש לאשר מיקום בווידג'ט", comment: "")
            case .deniedOrRestricted:
                recoveryMessage = NSLocalizedString("widget.permission_required", value: "נדרשת הרשאת מיקום", comment: "")
            case .notDetermined:
                recoveryMessage = NSLocalizedString("widget.open_app_to_refresh", value: "פתח את האפליקציה לרענון", comment: "")
            default:
                recoveryMessage = NSLocalizedString("widget.no_data", value: "אין נתוני זמנים זמינים", comment: "")
            }

            #if DEBUG
            Self.logger.notice("Displaying empty recovery state: \(recoveryMessage, privacy: .public)")
            #endif
            let entry = ZmanEntry(date: now, snapshot: nil, state: recoveryMessage, pageIndex: 0, pageCount: 1)
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300))))
        }
    }

    private func formatStaleNote(for snapshot: ZmanSnapshot) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = snapshot.timeZone
        return String(format: NSLocalizedString("widget.updated_at_format", value: "עודכן ב-%@", comment: ""), formatter.string(from: snapshot.updatedAt))
    }

    private func isSnapshotFresh(_ snapshot: ZmanSnapshot, now: Date) -> Bool {
        guard !snapshot.items.isEmpty else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = snapshot.timeZone
        let isToday = cal.isDate(snapshot.updatedAt, inSameDayAs: now)
        let hasUpcoming = snapshot.items.contains(where: { $0.date > now })
        return isToday && hasUpcoming
    }

    private func makeTimeline(
        snapshot: ZmanSnapshot,
        now: Date,
        state: String?,
        pageState: WidgetPageState?
    ) -> Timeline<ZmanEntry> {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = snapshot.timeZone

        let dayKey = WidgetPageStateStore.dayKey(for: now, timeZone: snapshot.timeZone)
        let selector = WidgetDaySelector(
            allItems: snapshot.items,
            referenceDate: now,
            timeZone: snapshot.timeZone
        )

        let effectivePage = WidgetPageStateStore.effectivePageIndex(
            state: pageState,
            currentDate: now,
            currentDayKey: dayKey,
            currentLocationFingerprint: snapshot.cityName,
            pageCount: selector.pageCount
        )

        var timePoints: [(date: Date, page: Int)] = [(now, effectivePage)]

        // Future entry for 60-second best-effort page reset
        if effectivePage > 0, let expiresAt = pageState?.expiresAt, expiresAt > now {
            timePoints.append((expiresAt, 0))
        }

        // Add entries for upcoming zmanim transitions today
        let upcomingItems = snapshot.items.filter { $0.date > now }
        for item in upcomingItems {
            let pageForTransition: Int
            if effectivePage > 0, let expiresAt = pageState?.expiresAt, item.date < expiresAt {
                pageForTransition = effectivePage
            } else {
                pageForTransition = 0
            }
            timePoints.append((item.date, pageForTransition))
        }

        // Add midnight rollover entry
        if let nextMidnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
            timePoints.append((nextMidnight, 0))
        }

        timePoints.sort { $0.date < $1.date }

        // Deduplicate timestamps within 10 seconds
        var uniquePoints: [(date: Date, page: Int)] = []
        for pt in timePoints {
            if let last = uniquePoints.last {
                if pt.date.timeIntervalSince(last.date) >= 10 {
                    uniquePoints.append(pt)
                }
            } else {
                uniquePoints.append(pt)
            }
        }

        let entries = uniquePoints.map { pt in
            ZmanEntry(
                date: pt.date,
                snapshot: snapshot,
                state: state,
                pageIndex: pt.page,
                pageCount: selector.pageCount,
                expiresAt: pageState?.expiresAt
            )
        }

        // Refresh policy: if paged, schedule reload at expiresAt (best effort 60s); otherwise next midnight or max 4h
        let nextMidnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
        let defaultRefresh = min(nextMidnight ?? now.addingTimeInterval(14400), now.addingTimeInterval(14400))

        let reloadPolicy: TimelineReloadPolicy
        if effectivePage > 0, let expiresAt = pageState?.expiresAt, expiresAt > now {
            reloadPolicy = .after(expiresAt)
        } else {
            reloadPolicy = .after(defaultRefresh)
        }

        return Timeline(entries: entries, policy: reloadPolicy)
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
                ZmanItem(key: "alotHaShachar", hebrewTitle: "עלות השחר", englishTitle: "Alot HaShachar", icon: "moon.stars.fill", date: now.addingTimeInterval(-10800)),
                ZmanItem(key: "sunrise", hebrewTitle: "הנץ החמה", englishTitle: "Sunrise", icon: "sunrise.fill", date: now.addingTimeInterval(-7200)),
                ZmanItem(key: "chatzot", hebrewTitle: "חצות היום", englishTitle: "Chatzot", icon: "sun.max.fill", date: now.addingTimeInterval(3600)),
                ZmanItem(key: "sunset", hebrewTitle: "שקיעה", englishTitle: "Sunset", icon: "sunset.fill", date: now.addingTimeInterval(7200)),
                ZmanItem(key: "tzeit7083deg", hebrewTitle: "צאת הכוכבים", englishTitle: "Tzeit", icon: "moon.fill", date: now.addingTimeInterval(9000))
            ],
            locationSignature: "demo"
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
        .configurationDisplayName(LocalizedStringKey("widget.display_name"))
        .description(LocalizedStringKey("widget.description"))
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
