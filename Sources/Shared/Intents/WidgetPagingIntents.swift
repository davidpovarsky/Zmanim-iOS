import AppIntents
import Foundation
import WidgetKit

public struct NextWidgetPageIntent: AppIntent {
    public static var title: LocalizedStringResource = LocalizedStringResource("widget.intent.next_page_title")
    public static var description = IntentDescription(LocalizedStringResource("widget.intent.next_page_desc"))
    public static var openAppWhenRun: Bool = false

    @Parameter(title: LocalizedStringResource("widget.location_param_title"))
    public var locationKey: String?

    public init() {
        self.locationKey = nil
    }

    public init(locationKey: String?) {
        self.locationKey = locationKey
    }

    public func perform() async throws -> some IntentResult {
        let now = Date()
        let resolvedKey: String
        if let key = locationKey, key != "default", !key.isEmpty {
            resolvedKey = key
        } else {
            let prefs = LocationPreferencesStore.loadPreferences()
            resolvedKey = prefs.defaultChoice.storageKey
        }

        guard let snapshot = LocationSnapshotStore.loadSnapshot(for: resolvedKey), !snapshot.items.isEmpty else {
            return .result()
        }
        let timeZone = snapshot.timeZone
        let dayKey = WidgetPageStateStore.dayKey(for: now, timeZone: timeZone)
        let fingerprint = resolvedKey

        let pager = UpcomingZmanPager(
            allItems: snapshot.items,
            referenceDate: now,
            timeZone: timeZone
        )

        let currentState = WidgetPageStateStore.loadState(for: resolvedKey)
        let newState = WidgetPageReducer.reduce(
            state: currentState,
            action: .nextPage,
            dayKey: dayKey,
            locationFingerprint: fingerprint,
            now: now,
            pageCount: pager.pageCount
        )

        WidgetPageStateStore.saveState(newState, for: resolvedKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "ZmanimWidget")
        return .result()
    }
}

public struct PreviousWidgetPageIntent: AppIntent {
    public static var title: LocalizedStringResource = LocalizedStringResource("widget.intent.prev_page_title")
    public static var description = IntentDescription(LocalizedStringResource("widget.intent.prev_page_desc"))
    public static var openAppWhenRun: Bool = false

    @Parameter(title: LocalizedStringResource("widget.location_param_title"))
    public var locationKey: String?

    public init() {
        self.locationKey = nil
    }

    public init(locationKey: String?) {
        self.locationKey = locationKey
    }

    public func perform() async throws -> some IntentResult {
        let now = Date()
        let resolvedKey: String
        if let key = locationKey, key != "default", !key.isEmpty {
            resolvedKey = key
        } else {
            let prefs = LocationPreferencesStore.loadPreferences()
            resolvedKey = prefs.defaultChoice.storageKey
        }

        guard let snapshot = LocationSnapshotStore.loadSnapshot(for: resolvedKey), !snapshot.items.isEmpty else {
            return .result()
        }
        let timeZone = snapshot.timeZone
        let dayKey = WidgetPageStateStore.dayKey(for: now, timeZone: timeZone)
        let fingerprint = resolvedKey

        let pager = UpcomingZmanPager(
            allItems: snapshot.items,
            referenceDate: now,
            timeZone: timeZone
        )

        let currentState = WidgetPageStateStore.loadState(for: resolvedKey)
        let newState = WidgetPageReducer.reduce(
            state: currentState,
            action: .previousPage,
            dayKey: dayKey,
            locationFingerprint: fingerprint,
            now: now,
            pageCount: pager.pageCount
        )

        WidgetPageStateStore.saveState(newState, for: resolvedKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "ZmanimWidget")
        return .result()
    }
}
