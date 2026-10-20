import ActivityKit
import AppIntents
import CoreLocation
import os
import SwiftUI
import WidgetKit

enum ResolvedWidgetTarget: Sendable, Equatable {
    case gps
    case savedCity(SavedCity)
    case sharedStoreUnavailable
    case savedCityMissing(cityID: String)
    case cityRemoved(cityID: String)
    case invalidConfiguration
}

struct ConfigurableZmanProvider: AppIntentTimelineProvider {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim.Widgets", category: "ConfigurableZmanProvider")

    func placeholder(in context: Context) -> ZmanEntry {
        ZmanEntry(
            date: .now,
            snapshot: nil,
            state: nil,
            pageIndex: 0,
            pageCount: 1,
            isGPS: false,
            locationKey: "default",
            customCityName: nil,
            isPlaceholder: true
        )
    }

    func snapshot(for configuration: WidgetLocationConfigurationIntent, in context: Context) async -> ZmanEntry {
        if context.isPreview {
            return placeholder(in: context)
        }

        let target = resolveTarget(from: configuration)
        switch target {
        case .gps:
            let identity = LocationIdentity.gps
            if let cached = LocationSnapshotStore.loadSnapshot(for: identity),
               SnapshotValidator.isFresh(snapshot: cached, for: identity, now: .now) {
                let pager = UpcomingZmanPager(allItems: cached.items, referenceDate: .now, timeZone: cached.timeZone)
                return ZmanEntry(
                    date: .now,
                    snapshot: cached,
                    state: nil,
                    pageIndex: 0,
                    pageCount: pager.pageCount,
                    isGPS: true,
                    locationKey: identity.canonicalStorageKey,
                    customCityName: cached.cityName.isEmpty ? nil : cached.cityName
                )
            }
        case .savedCity(let city):
            let identity = LocationIdentity.savedCity(id: city.id)
            if let cached = LocationSnapshotStore.loadSnapshot(for: identity),
               SnapshotValidator.isFresh(snapshot: cached, for: identity, now: .now) {
                let pager = UpcomingZmanPager(allItems: cached.items, referenceDate: .now, timeZone: cached.timeZone)
                return ZmanEntry(
                    date: .now,
                    snapshot: cached,
                    state: nil,
                    pageIndex: 0,
                    pageCount: pager.pageCount,
                    isGPS: false,
                    locationKey: identity.canonicalStorageKey,
                    customCityName: city.name
                )
            }
        case .cityRemoved:
            return ZmanEntry(
                date: .now,
                snapshot: nil,
                state: NSLocalizedString("location.city_removed_widget", comment: ""),
                pageIndex: 0,
                pageCount: 1,
                isGPS: false,
                locationKey: "removed",
                customCityName: nil
            )
        case .sharedStoreUnavailable:
            return ZmanEntry(
                date: .now,
                snapshot: nil,
                state: NSLocalizedString("widget.shared_store_unavailable", comment: ""),
                pageIndex: 0,
                pageCount: 1,
                isGPS: false,
                locationKey: "unavailable",
                customCityName: nil
            )
        case .savedCityMissing, .invalidConfiguration:
            return ZmanEntry(
                date: .now,
                snapshot: nil,
                state: NSLocalizedString("widget.open_app_to_refresh", comment: ""),
                pageIndex: 0,
                pageCount: 1,
                isGPS: false,
                locationKey: "missing",
                customCityName: nil
            )
        }

        return ZmanEntry(
            date: .now,
            snapshot: nil,
            state: NSLocalizedString("widget.open_app_to_refresh", comment: ""),
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
            let recovery = NSLocalizedString("location.city_removed_widget", comment: "")
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

        case .sharedStoreUnavailable:
            let recovery = NSLocalizedString("widget.shared_store_unavailable", comment: "")
            let entry = ZmanEntry(
                date: now,
                snapshot: nil,
                state: recovery,
                pageIndex: 0,
                pageCount: 1,
                isGPS: false,
                locationKey: "unavailable",
                customCityName: nil
            )
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300)))

        case .savedCityMissing:
            let recovery = NSLocalizedString("widget.city_not_found", comment: "")
            let entry = ZmanEntry(
                date: now,
                snapshot: nil,
                state: recovery,
                pageIndex: 0,
                pageCount: 1,
                isGPS: false,
                locationKey: "missing",
                customCityName: nil
            )
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300)))

        case .invalidConfiguration:
            let recovery = NSLocalizedString("widget.invalid_configuration", comment: "")
            let entry = ZmanEntry(
                date: now,
                snapshot: nil,
                state: recovery,
                pageIndex: 0,
                pageCount: 1,
                isGPS: false,
                locationKey: "invalid",
                customCityName: nil
            )
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300)))

        case .savedCity(let city):
            let identity = LocationIdentity.savedCity(id: city.id)
            let locationKey = identity.canonicalStorageKey
            let pageState = WidgetPageStateStore.loadState(for: locationKey)
            let cached = LocationSnapshotStore.loadSnapshot(for: identity)

            if let cached, SnapshotValidator.isFresh(snapshot: cached, for: identity, now: now) {
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

            // Missing or stale: fetch Hebcal for city coordinates
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
                        locationSignature: "\(city.name)-\(city.timeZone.identifier)",
                        sourceIdentity: identity
                    )
                    _ = LocationSnapshotStore.saveSnapshot(snapshot, for: identity)
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

            // Fallback to stale cache if available and authentic
            if let cached, !cached.items.isEmpty, cached.validTimeZone != nil {
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
                format: NSLocalizedString("widget.open_app_to_refresh_city_format", comment: ""),
                city.name
            )
            let entry = ZmanEntry(date: now, snapshot: nil, state: recovery, pageIndex: 0, pageCount: 1, isGPS: false, locationKey: locationKey, customCityName: city.name)
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300)))

        case .gps:
            let identity = LocationIdentity.gps
            let locationKey = identity.canonicalStorageKey
            let pageState = WidgetPageStateStore.loadState(for: locationKey)
            let cached = LocationSnapshotStore.loadSnapshot(for: identity)

            if let cached, SnapshotValidator.isFresh(snapshot: cached, for: identity, now: now) {
                return makeTimeline(
                    snapshot: cached,
                    now: now,
                    state: nil,
                    pageState: pageState,
                    isGPS: true,
                    locationKey: locationKey,
                    customCityName: cached.cityName.isEmpty ? nil : cached.cityName
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

                let timeZone = resolvedZone ?? cached?.validTimeZone
                if let timeZone {
                    if let resolvedCity, !resolvedCity.isEmpty {
                        let locality = VerifiedLocality(
                            name: resolvedCity,
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            timeZoneID: timeZone.identifier,
                            localeIdentifier: Locale.autoupdatingCurrent.identifier
                        )
                        VerifiedLocalityStore.save(locality)
                    }

                    let verifiedCityName = resolvedCity
                        ?? VerifiedLocalityStore.load(for: location.coordinate)?.name
                        ?? (cached?.cityName.isEmpty == false ? cached?.cityName : nil)

                    do {
                        let items = try await HebcalService.fetchDays(
                            location: location,
                            timeZone: timeZone,
                            starting: now,
                            count: 3
                        )
                        if !items.isEmpty {
                            let snapshot = ZmanSnapshot(
                                cityName: verifiedCityName ?? "",
                                timeZoneID: timeZone.identifier,
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude,
                                updatedAt: now,
                                items: items,
                                locationSignature: "current",
                                sourceIdentity: identity
                            )
                            _ = LocationSnapshotStore.saveSnapshot(snapshot, for: identity)
                            return makeTimeline(
                                snapshot: snapshot,
                                now: now,
                                state: nil,
                                pageState: pageState,
                                isGPS: true,
                                locationKey: locationKey,
                                customCityName: verifiedCityName
                            )
                        }
                    } catch {
                        #if DEBUG
                        Self.logger.error("Widget Hebcal GPS fetch failed: \(error.localizedDescription, privacy: .public)")
                        #endif
                    }
                }
            }

            // Stale cache fallback for GPS
            if let cached, !cached.items.isEmpty, cached.validTimeZone != nil {
                let note = formatStaleNote(for: cached)
                return makeTimeline(
                    snapshot: cached,
                    now: now,
                    state: note,
                    pageState: pageState,
                    isGPS: true,
                    locationKey: locationKey,
                    customCityName: cached.cityName.isEmpty ? nil : cached.cityName
                )
            }

            // No cache: show recovery
            let recoveryMessage: String
            switch state {
            case .appAuthorizedWidgetDenied:
                recoveryMessage = NSLocalizedString("widget.location_required", comment: "")
            case .deniedOrRestricted:
                recoveryMessage = NSLocalizedString("widget.permission_required", comment: "")
            case .notDetermined:
                recoveryMessage = NSLocalizedString("widget.open_app_to_refresh", comment: "")
            default:
                recoveryMessage = NSLocalizedString("widget.no_data", comment: "")
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
        let prefsResult = LocationPreferencesStore.loadPreferencesResult()
        let prefs: LocationPreferences
        switch prefsResult {
        case .loaded(let loaded):
            prefs = loaded
        case .noPreferencesYet:
            prefs = LocationPreferences()
        case .storeUnavailable:
            return .sharedStoreUnavailable
        case .corruptData:
            return .invalidConfiguration
        }

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
            } else if prefs.removedCityIDs.contains(cityId) {
                return .cityRemoved(cityID: cityId)
            } else {
                return .savedCityMissing(cityID: cityId)
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
            } else if prefs.removedCityIDs.contains(id) {
                return .cityRemoved(cityID: id)
            } else {
                return .savedCityMissing(cityID: id)
            }
        }
    }

    private func formatStaleNote(for snapshot: ZmanSnapshot) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = snapshot.timeZone
        return String(format: NSLocalizedString("widget.updated_at_format", comment: ""), formatter.string(from: snapshot.updatedAt))
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
        let initialPager = UpcomingZmanPager(
            allItems: snapshot.items,
            referenceDate: now,
            timeZone: snapshot.timeZone
        )

        let effectivePage = WidgetPageStateStore.effectivePageIndex(
            state: pageState,
            currentDate: now,
            currentDayKey: dayKey,
            currentLocationFingerprint: locationKey,
            pageCount: initialPager.pageCount
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

        // Compute page count and coherent pager per individual entry date
        let entries = uniquePoints.map { pt in
            let entryPager = UpcomingZmanPager(
                allItems: snapshot.items,
                referenceDate: pt.date,
                timeZone: snapshot.timeZone
            )
            let safePage = min(pt.page, max(0, entryPager.pageCount - 1))
            return ZmanEntry(
                date: pt.date,
                snapshot: snapshot,
                state: state,
                pageIndex: safePage,
                pageCount: entryPager.pageCount,
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
