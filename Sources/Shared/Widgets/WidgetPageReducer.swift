import Foundation

public enum WidgetPageAction: Sendable, Equatable {
    case nextPage
    case previousPage
    case reset
    case validateExpiration
}

public enum WidgetPageReducer {
    public static let defaultTTL: TimeInterval = 60.0

    /// Pure function reducing widget paging events to a deterministic state.
    public static func reduce(
        state: WidgetPageState?,
        action: WidgetPageAction,
        dayKey: String,
        locationFingerprint: String,
        now: Date,
        pageCount: Int,
        ttl: TimeInterval = defaultTTL
    ) -> WidgetPageState {
        let safePageCount = max(1, pageCount)

        // Validate baseline validity of existing state
        let isFresh: Bool
        if let state,
           state.dayKey == dayKey,
           state.locationFingerprint == locationFingerprint,
           now < state.expiresAt,
           state.pageIndex >= 0,
           state.pageIndex < safePageCount {
            isFresh = true
        } else {
            isFresh = false
        }

        let baseIndex = isFresh ? (state?.pageIndex ?? 0) : 0

        switch action {
        case .nextPage:
            let nextIndex: Int
            if safePageCount <= 1 {
                nextIndex = 0
            } else {
                nextIndex = (baseIndex + 1) % safePageCount
            }
            return WidgetPageState(
                pageIndex: nextIndex,
                lastInteractionAt: now,
                expiresAt: now.addingTimeInterval(ttl),
                dayKey: dayKey,
                locationFingerprint: locationFingerprint,
                schemaVersion: 1
            )

        case .previousPage:
            let prevIndex: Int
            if safePageCount <= 1 {
                prevIndex = 0
            } else {
                prevIndex = (baseIndex - 1 + safePageCount) % safePageCount
            }
            return WidgetPageState(
                pageIndex: prevIndex,
                lastInteractionAt: now,
                expiresAt: now.addingTimeInterval(ttl),
                dayKey: dayKey,
                locationFingerprint: locationFingerprint,
                schemaVersion: 1
            )

        case .reset:
            return WidgetPageState(
                pageIndex: 0,
                lastInteractionAt: now,
                expiresAt: now,
                dayKey: dayKey,
                locationFingerprint: locationFingerprint,
                schemaVersion: 1
            )

        case .validateExpiration:
            if !isFresh {
                return WidgetPageState(
                    pageIndex: 0,
                    lastInteractionAt: now,
                    expiresAt: now,
                    dayKey: dayKey,
                    locationFingerprint: locationFingerprint,
                    schemaVersion: 1
                )
            } else {
                return state!
            }
        }
    }
}
