import ActivityKit
import AppIntents
import CoreLocation
import os
import SwiftUI
import WidgetKit

enum ResolvedWidgetTarget: Sendable {
    case gps
    case savedCity(SavedCity)
    case cityRemoved
}

struct ConfigurableZmanProvider: AppIntentTimelineProvider {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim.Widgets", category: "ConfigurableZmanProvider")

    func placeholder(in context: Context) -> ZmanEntry {
        ZmanEntry(
            date: .now,
            snapshot: demoSnapshot,
            state: nil,
            pageIndex: 0,
            pageCount: 1,
            isGPS: false,
            locationKey: "default",
            customCityName: "ירושלים"
        )
    }

    func snapshot(for configuration: WidgetLocationConfigurationIntent, in context: Context) async -> ZmanEntry {
        if context.isPreview {
            return placeholder(in: context)
        }

        let target = resolveTarget(from: configuration)
        switch target {
        case .gps:
            if let cached = LocationSnapshotStore.loadSnapshot(for: "current"), !cached.items.isEmpty {
                let pager = UpcomingZmanPager(allItems: cached.items, referenceDate: .now, timeZone: cached.timeZone)
                return ZmanEntry(date: .now, snapshot: cached, state: nil, pageIndex: 0, pageCount: pager.pageCount, isGPS: true, locationKey: "current", customCityName: cached.cityName)
            }
        case .savedCity(let city):
            let locationKey = "city_\(city.id)"
            if let cached = LocationSnapshotStore.loadSnapshot(for: locationKey), !cached.items.isEmpty {
                let pager = UpcomingZmanPager(allItems: cached.items, referenceDate: .now, timeZone: cached.timeZone)
                return ZmanEntry(date: .now, snapshot: cached, state: nil, pageIndex: 0, pageCount: pager.pageCount, isGPS: false, locationKey: locationKey, customCityName: city.name)
            }
        case .cityRemoved:
            return ZmanEntry(
                date: .now,
                snapshot: nil,
                state: NSLocalizedString("location.city_removed_widget", value: "העיר הוסרה — ערוך את הווידג'ט", comment: ""),
                pageIndex: 0,
                pageCount: 1,
                isGPS: false,
                locationKey: "removed",
                customCityName: nil
            )
        }

        if let fallback = AppGroupStore.loadSnapshot(), !fallback.items.isEmpty {
            let pager = UpcomingZmanPager(allItems: fallback.items, referenceDate: .now, timeZone: fallback.timeZone)
            return ZmanEntry(date: .now, snapshot: fallback, state: nil, pageIndex: 0, pageCount: pager.pageCount, isGPS: false, locationKey: "default", customCityName: fallback.cityName)
        }

        return ZmanEntry(
            date: .now,
            snapshot: nil,
            state: NSLocalizedString("widget.open_app_to_refresh", value: "פתח את האפליקציה לרענון", comment: ""),
            pageIndex: 0,
            pageCount: 1,
            isGPS: false,
            locationKey: "default",
            customCityName: nil
        )
    }

    func timeline(for configuration: WidgetLocationConfigurationIntent, in context: Context) async -> Timeline<ZmanEntry> {
        let now = Date()
        let target = resolveTarget(from: configuration)

        switch target {
        case .cityRemoved:
            let recovery = NSLocalizedString("location.city_removed_widget", value: "העיר הוסרה — ערוך את הווידג'ט", comment: "")
            let entry = ZmanEntry(
                date: now,
                snapshot: nil,
                state: recovery,
                pageIndex: 0,
                pageCount: 1,
                isGPS: false,
                locationKey: "removed",
                customCityName: nil
            )
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300)))

        case .savedCity(let city):
            let locationKey = "city_\(city.id)"
            let pageState = WidgetPageStateStore.loadState(for: locationKey)
            let cached = LocationSnapshotStore.loadSnapshot(for: locationKey)

            if let cached, isSnapshotFresh(cached, now: now) {
                return makeTimeline(
                    snapshot: cached,
                    now: now,
                    state: nil,
                    pageState: pageState,
                    isGPS: false,
                    locationKey: locationKey,
                    customCityName: city.name
                )
            }

            // Stale or missing: fetch Hebcal for city coordinates
            let cityLocation = CLLocation(latitude: city.latitude, longitude: city.longitude)
            do {
                let items = try await HebcalService.fetchDays(
                    location: cityLocation,
                    timeZone: city.timeZone,
                    starting: now,
                    count: 3
                )
                if !items.isEmpty {
                    let snapshot = ZmanSnapshot(
                        cityName: city.name,
                        timeZoneID: city.timeZone.identifier,
                        latitude: city.latitude,
                        longitude: city.longitude,
                        updatedAt: now,
                        items: items,
                        locationSignature: "\(city.name)-\(city.timeZone.identifier)"
                    )
                    LocationSnapshotStore.saveSnapshot(snapshot, for: locationKey)
                    return makeTimeline(
                        snapshot: snapshot,
                        now: now,
                        state: nil,
                        pageState: pageState,
                        isGPS: false,
                        locationKey: locationKey,
                        customCityName: city.name
                    )
                }
            } catch {
                #if DEBUG
                Self.logger.error("Failed to fetch Hebcal for city \(city.name): \(error.localizedDescription, privacy: .public)")
                #endif
            }

            // Fallback to stale cache if available
            if let cached, !cached.items.isEmpty {
                let note = formatStaleNote(for: cached)
                return makeTimeline(
                    snapshot: cached,
                    now: now,
                    state: note,
                    pageState: pageState,
                    isGPS: false,
                    locationKey: locationKey,
                    customCityName: city.name
                )
            }

            // Empty state for city
            let recovery = String(
                format: NSLocalizedString("widget.open_app_to_refresh_city_format", value: "פתח את האפליקציה לרענון %@", comment: ""),
                city.name
            )
            let entry = ZmanEntry(date: now, snapshot: nil, state: recovery, pageIndex: 0, pageCount: 1, isGPS: false, locationKey: locationKey, customCityName: city.name)
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300)))

        case .gps:
            let locationKey = "current"
            let pageState = WidgetPageStateStore.loadState(for: locationKey)
            let cached = LocationSnapshotStore.loadSnapshot(for: locationKey)

            if let cached, isSnapshotFresh(cached, now: now) {
                return makeTimeline(
                    snapshot: cached,
                    now: now,
                    state: nil,
                    pageState: pageState,
                    isGPS: true,
                    locationKey: locationKey,
                    customCityName: cached.cityName
                )
            }

            // Request fresh GPS
            let (state, oneShotLocation) = await requestWidgetLocation()

            if let location = oneShotLocation {
                var resolvedZone: TimeZone? = nil
                var resolvedCity: String? = nil

                if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale.autoupdatingCurrent),
                   let place = placemarks.first {
                    resolvedZone = place.timeZone
                    resolvedCity = place.locality ?? place.subLocality ?? place.administrativeArea
                }

                let timeZone = resolvedZone ?? cached?.timeZone ?? .current
                let cityName = resolvedCity ?? cached?.cityName ?? NSLocalizedString("location.current", value: "המיקום הנוכחי", comment: "")

                do {
                    let items = try await HebcalService.fetchDays(
                        location: location,
                        timeZone: timeZone,
                        starting: now,
                        count: 3
                    )
                    if !items.isEmpty {
                        let snapshot = ZmanSnapshot(
                            cityName: cityName,
                            timeZoneID: timeZone.identifier,
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            updatedAt: now,
                            items: items,
                            locationSignature: "current"
                        )
                        LocationSnapshotStore.saveSnapshot(snapshot, for: locationKey)
                        return makeTimeline(
                            snapshot: snapshot,
                            now: now,
                            state: nil,
                            pageState: pageState,
                            isGPS: true,
                            locationKey: locationKey,
                            customCityName: cityName
                        )
                    }
                } catch {
                    #if DEBUG
                    Self.logger.error("Widget Hebcal GPS fetch failed: \(error.localizedDescription, privacy: .public)")
                    #endif
                }
            }

            // Stale cache fallback
            if let cached, !cached.items.isEmpty {
                let note = formatStaleNote(for: cached)
                return makeTimeline(
                    snapshot: cached,
                    now: now,
                    state: note,
                    pageState: pageState,
                    isGPS: true,
                    locationKey: locationKey,
                    customCityName: cached.cityName
                )
            }

            // No cache: show recovery
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

            let entry = ZmanEntry(date: now, snapshot: nil, state: recoveryMessage, pageIndex: 0, pageCount: 1, isGPS: true, locationKey: locationKey, customCityName: nil)
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300)))
        }
    }

    @MainActor
    private func requestWidgetLocation() async -> (WidgetLocationFetcher.WidgetLocationState, CLLocation?) {
        let fetcher = WidgetLocationFetcher()
        let state = fetcher.currentState
        if case .authorized = state {
            let location = await fetcher.requestOneShotLocation(timeoutSeconds: 4.0)
            return (state, location)
        }
        return (state, nil)
    }

    private func resolveTarget(from intent: WidgetLocationConfigurationIntent) -> ResolvedWidgetTarget {
        let prefs = LocationPreferencesStore.loadPreferences()
        guard let locationParam = intent.location else {
            // Intent is unconfigured: follow app default
            return resolveAppDefault(prefs: prefs)
        }

        let paramId = locationParam.id
        if paramId == "app-default" {
            return resolveAppDefault(prefs: prefs)
        } else if paramId == "current-gps" {
            return .gps
        } else if paramId.hasPrefix("city:") {
            let cityId = String(paramId.dropFirst("city:".count))
            if let city = prefs.savedCities.first(where: { $0.id == cityId }) {
                return .savedCity(city)
            } else {
                return .cityRemoved
            }
        }

        return resolveAppDefault(prefs: prefs)
    }

    private func resolveAppDefault(prefs: LocationPreferences) -> ResolvedWidgetTarget {
        switch prefs.defaultChoice {
        case .current:
            return .gps
        case .savedCity(let id):
            if let city = prefs.savedCities.first(where: { $0.id == id }) {
                return .savedCity(city)
            } else {
                return .gps
            }
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
        pageState: WidgetPageState?,
        isGPS: Bool,
        locationKey: String,
        customCityName: String?
    ) -> Timeline<ZmanEntry> {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = snapshot.timeZone

        let dayKey = WidgetPageStateStore.dayKey(for: now, timeZone: snapshot.timeZone)
        let pager = UpcomingZmanPager(
            allItems: snapshot.items,
            referenceDate: now,
            timeZone: snapshot.timeZone
        )

        let effectivePage = WidgetPageStateStore.effectivePageIndex(
            state: pageState,
            currentDate: now,
            currentDayKey: dayKey,
            currentLocationFingerprint: locationKey,
            pageCount: pager.pageCount
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
                pageCount: pager.pageCount,
                expiresAt: pageState?.expiresAt,
                isGPS: isGPS,
                locationKey: locationKey,
                customCityName: customCityName
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
        AppIntentConfiguration(
            kind: kind,
            intent: WidgetLocationConfigurationIntent.self,
            provider: ConfigurableZmanProvider()
        ) { entry in
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
