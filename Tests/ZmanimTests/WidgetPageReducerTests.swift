import XCTest
@testable import Zmanim

final class WidgetPageReducerTests: XCTestCase {
    func testNextPageFromNilStartsAtOneAndSetsExpiry() {
        let now = Date(timeIntervalSince1970: 1000)
        let state = WidgetPageReducer.reduce(
            state: nil,
            action: .nextPage,
            dayKey: "2026-10-19",
            locationFingerprint: "Jerusalem",
            now: now,
            pageCount: 3,
            ttl: 60
        )

        XCTAssertEqual(state.pageIndex, 1)
        XCTAssertEqual(state.lastInteractionAt, now)
        XCTAssertEqual(state.expiresAt, Date(timeIntervalSince1970: 1060))
        XCTAssertEqual(state.dayKey, "2026-10-19")
        XCTAssertEqual(state.locationFingerprint, "Jerusalem")
    }

    func testConsecutiveTapsAdvanceAndExtendExpiry() {
        let t0 = Date(timeIntervalSince1970: 1000)
        var state = WidgetPageReducer.reduce(
            state: nil,
            action: .nextPage,
            dayKey: "2026-10-19",
            locationFingerprint: "Jerusalem",
            now: t0,
            pageCount: 3,
            ttl: 60
        )
        XCTAssertEqual(state.pageIndex, 1)
        XCTAssertEqual(state.expiresAt, Date(timeIntervalSince1970: 1060))

        // Second tap 10 seconds later
        let t1 = Date(timeIntervalSince1970: 1010)
        state = WidgetPageReducer.reduce(
            state: state,
            action: .nextPage,
            dayKey: "2026-10-19",
            locationFingerprint: "Jerusalem",
            now: t1,
            pageCount: 3,
            ttl: 60
        )
        XCTAssertEqual(state.pageIndex, 2)
        XCTAssertEqual(state.expiresAt, Date(timeIntervalSince1970: 1070))

        // Third tap loops back to 0
        let t2 = Date(timeIntervalSince1970: 1020)
        state = WidgetPageReducer.reduce(
            state: state,
            action: .nextPage,
            dayKey: "2026-10-19",
            locationFingerprint: "Jerusalem",
            now: t2,
            pageCount: 3,
            ttl: 60
        )
        XCTAssertEqual(state.pageIndex, 0)
        XCTAssertEqual(state.expiresAt, Date(timeIntervalSince1970: 1080))
    }

    func testPreviousPageWrapsAround() {
        let t0 = Date(timeIntervalSince1970: 1000)
        var state = WidgetPageState(
            pageIndex: 0,
            lastInteractionAt: t0,
            expiresAt: Date(timeIntervalSince1970: 1060),
            dayKey: "2026-10-19",
            locationFingerprint: "Jerusalem",
            schemaVersion: 1
        )

        state = WidgetPageReducer.reduce(
            state: state,
            action: .previousPage,
            dayKey: "2026-10-19",
            locationFingerprint: "Jerusalem",
            now: t0,
            pageCount: 3,
            ttl: 60
        )
        XCTAssertEqual(state.pageIndex, 2)
    }

    func testExpiryResetsToZero() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let state = WidgetPageState(
            pageIndex: 2,
            lastInteractionAt: t0,
            expiresAt: Date(timeIntervalSince1970: 1060),
            dayKey: "2026-10-19",
            locationFingerprint: "Jerusalem",
            schemaVersion: 1
        )

        // Validate expiration at t = 1061 (after expiry)
        let expiredNow = Date(timeIntervalSince1970: 1061)
        let validated = WidgetPageReducer.reduce(
            state: state,
            action: .validateExpiration,
            dayKey: "2026-10-19",
            locationFingerprint: "Jerusalem",
            now: expiredNow,
            pageCount: 3
        )
        XCTAssertEqual(validated.pageIndex, 0)
    }

    func testDayRolloverResetsState() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let state = WidgetPageState(
            pageIndex: 2,
            lastInteractionAt: t0,
            expiresAt: Date(timeIntervalSince1970: 1060),
            dayKey: "2026-10-19",
            locationFingerprint: "Jerusalem",
            schemaVersion: 1
        )

        // Action on new day "2026-10-20"
        let newDayState = WidgetPageReducer.reduce(
            state: state,
            action: .nextPage,
            dayKey: "2026-10-20",
            locationFingerprint: "Jerusalem",
            now: t0,
            pageCount: 3
        )
        XCTAssertEqual(newDayState.pageIndex, 1)
        XCTAssertEqual(newDayState.dayKey, "2026-10-20")
    }
}
