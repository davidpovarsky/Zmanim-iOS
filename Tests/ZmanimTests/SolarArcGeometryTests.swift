import CoreGraphics
import XCTest
@testable import Zmanim

final class SolarArcGeometryTests: XCTestCase {
    private let epsilon: CGFloat = 0.0001

    func testFiveProgressPointsMatchExactBezierMath() {
        let size = CGSize(width: 360, height: 145)
        let arc = SolarArcGeometry(size: size, margin: 24, base: 110, arcHeight: 80)

        // t = 0: Sunrise (left endpoint)
        let p0 = arc.point(at: 0.0)
        XCTAssertEqual(p0.x, arc.startPoint.x, accuracy: epsilon)
        XCTAssertEqual(p0.y, arc.startPoint.y, accuracy: epsilon)
        XCTAssertEqual(p0.x, 24, accuracy: epsilon)
        XCTAssertEqual(p0.y, 110, accuracy: epsilon)

        // t = 0.25: Rising segment
        let p25 = arc.point(at: 0.25)
        // y(0.25) = base - 4 * 0.25 * 0.75 * arcHeight = 110 - 0.75 * 80 = 110 - 60 = 50
        XCTAssertEqual(p25.y, 110 - 60, accuracy: epsilon)
        XCTAssertLessThan(p25.x, arc.size.width / 2)
        XCTAssertGreaterThan(p25.x, arc.startPoint.x)

        // t = 0.5: Curve Apex
        let p50 = arc.point(at: 0.5)
        XCTAssertEqual(p50.x, arc.size.width / 2, accuracy: epsilon)
        XCTAssertEqual(p50.y, arc.apexPoint.y, accuracy: epsilon)
        XCTAssertEqual(p50.y, 110 - 80, accuracy: epsilon) // 30

        // t = 0.75: Descending segment
        let p75 = arc.point(at: 0.75)
        // y(0.75) = base - 0.75 * 80 = 50
        XCTAssertEqual(p75.y, 50, accuracy: epsilon)
        XCTAssertGreaterThan(p75.x, arc.size.width / 2)
        XCTAssertLessThan(p75.x, arc.endPoint.x)

        // Symmetry between rising and descending segments
        XCTAssertEqual(p25.y, p75.y, accuracy: epsilon)
        let distLeft = p25.x - arc.startPoint.x
        let distRight = arc.endPoint.x - p75.x
        XCTAssertEqual(distLeft, distRight, accuracy: epsilon)

        // t = 1.0: Sunset (right endpoint)
        let p100 = arc.point(at: 1.0)
        XCTAssertEqual(p100.x, arc.endPoint.x, accuracy: epsilon)
        XCTAssertEqual(p100.y, arc.endPoint.y, accuracy: epsilon)
        XCTAssertEqual(p100.x, 360 - 24, accuracy: epsilon)
        XCTAssertEqual(p100.y, 110, accuracy: epsilon)
    }

    func testWidgetDimensionsProduceValidNormalizedGeometry() {
        let families: [(String, CGSize)] = [
            ("Small", CGSize(width: 170, height: 170)),
            ("Medium", CGSize(width: 364, height: 170)),
            ("Large", CGSize(width: 364, height: 382)),
            ("ExtraLarge-iPad", CGSize(width: 768, height: 382)),
            ("iPad-Home", CGSize(width: 1024, height: 160))
        ]

        for (name, size) in families {
            let arc = SolarArcGeometry(size: size)
            XCTAssertGreaterThan(arc.margin, 0, "\(name): margin must be positive")
            XCTAssertLessThan(arc.margin, size.width / 2, "\(name): margin must be less than half width")
            XCTAssertGreaterThan(arc.base, 0, "\(name): base must be positive")
            XCTAssertLessThan(arc.base, size.height, "\(name): base must be within height")
            XCTAssertGreaterThan(arc.apexPoint.y, 0, "\(name): apex must be within top bound")
            XCTAssertLessThan(arc.apexPoint.y, arc.base, "\(name): apex must be above base")

            // Endpoints are symmetric
            XCTAssertEqual(arc.startPoint.y, arc.endPoint.y, accuracy: epsilon, "\(name): base Y mismatch")
            XCTAssertEqual(arc.size.width - arc.endPoint.x, arc.startPoint.x, accuracy: epsilon, "\(name): horizontal symmetry mismatch")
        }
    }

    func testChronologicalProgressionLeftToRight() {
        let arc = SolarArcGeometry(size: CGSize(width: 400, height: 140))
        var prevX: CGFloat = -1

        for step in stride(from: 0.0, through: 1.0, by: 0.05) {
            let pt = arc.point(at: step)
            if prevX >= 0 {
                XCTAssertGreaterThan(pt.x, prevX, "Progression must strictly move left to right as progress increases")
            }
            prevX = pt.x
        }
    }

    func testHalachicProgressCalculation() {
        let sunrise = Date(timeIntervalSince1970: 1700000000)
        let sunset = Date(timeIntervalSince1970: 1700043200) // 12 hours later

        // Before sunrise -> clamp 0
        let before = sunrise.addingTimeInterval(-3600)
        XCTAssertEqual(SolarArcGeometry.progress(now: before, sunrise: sunrise, sunset: sunset), 0.0)

        // Exactly sunrise -> 0.0
        XCTAssertEqual(SolarArcGeometry.progress(now: sunrise, sunrise: sunrise, sunset: sunset), 0.0)

        // Midday (halfway) -> 0.5
        let midday = sunrise.addingTimeInterval(21600)
        XCTAssertEqual(SolarArcGeometry.progress(now: midday, sunrise: sunrise, sunset: sunset), 0.5, accuracy: 0.0001)

        // Exactly sunset -> 1.0
        XCTAssertEqual(SolarArcGeometry.progress(now: sunset, sunrise: sunrise, sunset: sunset), 1.0)

        // After sunset -> night state: daylight has ended, progress returns 0.0 (no fake 1.0)
        let after = sunset.addingTimeInterval(3600)
        XCTAssertEqual(SolarArcGeometry.progress(now: after, sunrise: sunrise, sunset: sunset), 0.0)

        // Missing data or invalid order
        XCTAssertEqual(SolarArcGeometry.progress(now: midday, sunrise: nil, sunset: sunset), 0.0)
        XCTAssertEqual(SolarArcGeometry.progress(now: midday, sunrise: sunrise, sunset: nil), 0.0)
        XCTAssertEqual(SolarArcGeometry.progress(now: midday, sunrise: sunset, sunset: sunrise), 0.0)
    }

    func testChronologicalProgressionRTLRightToLeft() {
        let size = CGSize(width: 400, height: 140)
        let arc = SolarArcGeometry(size: size, margin: 20, base: 100, arcHeight: 60, isRTL: true)

        // Sunrise (t = 0) is on the right
        let p0 = arc.point(at: 0.0)
        XCTAssertEqual(p0.x, 400 - 20, accuracy: epsilon)
        XCTAssertEqual(p0.x, arc.startPoint.x, accuracy: epsilon)

        // Sunset (t = 1) is on the left
        let p100 = arc.point(at: 1.0)
        XCTAssertEqual(p100.x, 20, accuracy: epsilon)
        XCTAssertEqual(p100.x, arc.endPoint.x, accuracy: epsilon)

        // Midday (t = 0.5) apex is centered
        let p50 = arc.point(at: 0.5)
        XCTAssertEqual(p50.x, 200, accuracy: epsilon)

        // X strictly decreases as progress increases
        var prevX: CGFloat = 9999
        for step in stride(from: 0.0, through: 1.0, by: 0.05) {
            let pt = arc.point(at: step)
            XCTAssertLessThan(pt.x, prevX, "In RTL, progress must move strictly right to left")
            prevX = pt.x
        }
    }
}
