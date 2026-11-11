import XCTest
@testable import Zmanim

final class AdaptiveRulesTests: XCTestCase {
    func testContainerWidthClassResolution() {
        // Compact (< 500)
        XCTAssertEqual(ContainerWidthClass.resolve(width: 320), .compact)
        XCTAssertEqual(ContainerWidthClass.resolve(width: 375), .compact)
        XCTAssertEqual(ContainerWidthClass.resolve(width: 430), .compact)
        XCTAssertEqual(ContainerWidthClass.resolve(width: 499.5), .compact)

        // Intermediate (500 ..< 800)
        XCTAssertEqual(ContainerWidthClass.resolve(width: 500), .intermediate)
        XCTAssertEqual(ContainerWidthClass.resolve(width: 600), .intermediate)
        XCTAssertEqual(ContainerWidthClass.resolve(width: 700), .intermediate)
        XCTAssertEqual(ContainerWidthClass.resolve(width: 799.5), .intermediate)

        // Spacious (>= 800)
        XCTAssertEqual(ContainerWidthClass.resolve(width: 800), .spacious)
        XCTAssertEqual(ContainerWidthClass.resolve(width: 1024), .spacious)
        XCTAssertEqual(ContainerWidthClass.resolve(width: 1366), .spacious)
    }
}
