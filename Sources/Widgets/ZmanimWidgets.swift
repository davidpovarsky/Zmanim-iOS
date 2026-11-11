import ActivityKit
import AppIntents
import CoreLocation
import os
import SwiftUI
import WidgetKit

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

        let target = WidgetTargetResolver.resolve(
            identifier: configuration.location?.id,
            preferencesResult: LocationPreferencesStore.loadPreferencesResult()
        )
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
            let locationKey = identity.canonicalStorageKey
            let now = Date()
            let cached = LocationSnapshotStore.loadSnapshot(for: identity)
            let validCache = cached.flatMap {
                validCitySnapshot($0, for: city, at: now) ? $0 : nil
            }
            // WidgetKit may request only snapshot(for:) and postpone timeline(for:).
            // Resolve saved-city times directly instead of leaving this view empty.
            let selected: ZmanSnapshot?
            if let validCache {
                selected = validCache
            } else {
                selected = await fetchCitySnapshot(for: city, now: now)
            }
            if let selected {
                let pager = UpcomingZmanPager(allItems: selected.items, referenceDate: now, timeZone: selected.timeZone)
                return ZmanEntry(
                    date: now,
                    snapshot: selected,
                    state: nil,
                    pageIndex: 0,
                    pageCount: max(1, pager.pageCount),
                    isGPS: false,
                    locationKey: locationKey,
                    customCityName: city.name
                )
            }
            return ZmanEntry(
                date: now,
                snapshot: nil,
                state: String(format: NSLocalizedString("widget.open_app_to_refresh_city_format", comment: ""), city.name),
                pageIndex: 0,
                pageCount: 1,
                isGPS: false,
                locationKey: locationKey,
                customCityName: city.name
            )
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
        AppGroupDiagnostics.recordWidgetAck(processName: "widget.timeline")
        let now = Date()
        let target = WidgetTargetResolver.resolve(
            identifier: configuration.location?.id,
            preferencesResult: LocationPreferencesStore.loadPreferencesResult()
        )

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

            if let cached, validCitySnapshot(cached, for: city, at: now) {
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

            // The city is carried by the AppIntent itself. Fetch even if the
            // App Group is unavailable; never substitute another city or GPS.
            if let fresh = await fetchCitySnapshot(for: city, now: now) {
                return makeTimeline(
                    snapshot: fresh,
                    now: now,
                    state: nil,
                    pageState: pageState,
                    isGPS: false,
                    locationKey: locationKey,
                    customCityName: city.name
                )
            }

            // Show old times only when they belong to this exact city.
            if let cached, structurallyValidCitySnapshot(cached, for: city) {
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

    private func structurallyValidCitySnapshot(_ snapshot: ZmanSnapshot, for city: SavedCity) -> Bool {
        let identity = LocationIdentity.savedCity(id: city.id)
        guard snapshot.sourceIdentity == identity,
              snapshot.timeZoneID == city.timeZoneID,
              !snapshot.items.isEmpty,
              snapshot.locationSignature != "demo" else { return false }
        let cachedLocation = CLLocation(latitude: snapshot.latitude, longitude: snapshot.longitude)
        let cityLocation = CLLocation(latitude: city.latitude, longitude: city.longitude)
        return cachedLocation.distance(from: cityLocation) <= 1_000
    }

    private func validCitySnapshot(_ snapshot: ZmanSnapshot, for city: SavedCity, at now: Date) -> Bool {
        guard structurallyValidCitySnapshot(snapshot, for: city) else { return false }
        let identity = LocationIdentity.savedCity(id: city.id)
        switch SnapshotValidator.validate(
            snapshot: snapshot,
            for: identity,
            expectedCoordinates: CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude),
            maxCoordinateDistanceMeters: 1_000,
            expectedTimeZoneID: city.timeZoneID,
            requiredDate: now,
            requireTomorrowCoverage: true
        ) {
        case .success:
            return true
        case .failure:
            return false
        }
    }

    private func fetchCitySnapshot(for city: SavedCity, now: Date) async -> ZmanSnapshot? {
        guard city.isValid, let zone = city.validTimeZone else {
            Self.logger.error("Rejected invalid saved-city widget configuration")
            return nil
        }
        let identity = LocationIdentity.savedCity(id: city.id)
        let coordinate = CLLocation(latitude: city.latitude, longitude: city.longitude)
        do {
            let items = try await HebcalService.fetchTodayAndTomorrow(
                location: coordinate,
                timeZone: zone,
                starting: now
            )
            guard !items.isEmpty else {
                Self.logger.error("Hebcal returned no saved-city zmanim")
                return nil
            }
            let snapshot = ZmanSnapshot(
                cityName: city.name,
                timeZoneID: city.timeZoneID,
                latitude: city.latitude,
                longitude: city.longitude,
                updatedAt: Date(),
                items: items,
                locationSignature: "\(city.name)-\(city.timeZoneID)",
                sourceIdentity: identity
            )
            guard validCitySnapshot(snapshot, for: city, at: now) else {
                Self.logger.error("Hebcal saved-city response failed identity or date validation")
                return nil
            }
            if !LocationSnapshotStore.saveSnapshot(snapshot, for: identity) {
                // Continue displaying authentic fetched data even when the
                // widget cannot access the shared container after signing.
                Self.logger.warning("Saved-city times fetched but App Group snapshot write unavailable")
            }
            return snapshot
        } catch {
            Self.logger.error("Saved-city widget Hebcal fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
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
