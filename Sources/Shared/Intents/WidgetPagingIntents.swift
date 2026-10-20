import AppIntents
import Foundation
import WidgetKit

public struct NextWidgetPageIntent: AppIntent {
    public static var title: LocalizedStringResource = LocalizedStringResource("widget.intent.next_page_title", defaultValue: "העמוד הבא בווידג'ט")
    public static var description = IntentDescription(LocalizedStringResource("widget.intent.next_page_desc", defaultValue: "מדפדף לחמשת זמני היום הבאים בווידג'ט."))
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        let now = Date()
        let snapshot = AppGroupStore.loadSnapshot()
        let timeZone = snapshot?.timeZone ?? .current
        let dayKey = WidgetPageStateStore.dayKey(for: now, timeZone: timeZone)
        let location = snapshot?.cityName ?? "default"

        let selector = WidgetDaySelector(
            allItems: snapshot?.items ?? [],
            referenceDate: now,
            timeZone: timeZone
        )

        let currentState = WidgetPageStateStore.loadState()
        let newState = WidgetPageReducer.reduce(
            state: currentState,
            action: .nextPage,
            dayKey: dayKey,
            locationFingerprint: location,
            now: now,
            pageCount: selector.pageCount
        )

        WidgetPageStateStore.saveState(newState)
        WidgetCenter.shared.reloadTimelines(ofKind: "ZmanimWidget")
        return .result()
    }
}

public struct PreviousWidgetPageIntent: AppIntent {
    public static var title: LocalizedStringResource = LocalizedStringResource("widget.intent.prev_page_title", defaultValue: "העמוד הקודם בווידג'ט")
    public static var description = IntentDescription(LocalizedStringResource("widget.intent.prev_page_desc", defaultValue: "חוזר לחמשת זמני היום הקודמים בווידג'ט."))
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        let now = Date()
        let snapshot = AppGroupStore.loadSnapshot()
        let timeZone = snapshot?.timeZone ?? .current
        let dayKey = WidgetPageStateStore.dayKey(for: now, timeZone: timeZone)
        let location = snapshot?.cityName ?? "default"

        let selector = WidgetDaySelector(
            allItems: snapshot?.items ?? [],
            referenceDate: now,
            timeZone: timeZone
        )

        let currentState = WidgetPageStateStore.loadState()
        let newState = WidgetPageReducer.reduce(
            state: currentState,
            action: .previousPage,
            dayKey: dayKey,
            locationFingerprint: location,
            now: now,
            pageCount: selector.pageCount
        )

        WidgetPageStateStore.saveState(newState)
        WidgetCenter.shared.reloadTimelines(ofKind: "ZmanimWidget")
        return .result()
    }
}
