import XCTest
@testable import RotatorCore

final class RotationAngleTests: XCTestCase {
    func testNormalizesEquivalentAngles() {
        XCTAssertEqual(RotationAngle.nearest(to: 0), .normal)
        XCTAssertEqual(RotationAngle.nearest(to: 360), .normal)
        XCTAssertEqual(RotationAngle.nearest(to: -90), .left)
        XCTAssertEqual(RotationAngle.nearest(to: 450), .right)
    }

    func testSelectsNearestCardinalAngle() {
        XCTAssertEqual(RotationAngle.nearest(to: 89.8), .right)
        XCTAssertEqual(RotationAngle.nearest(to: 181), .upsideDown)
        XCTAssertEqual(RotationAngle.nearest(to: 269.5), .left)
    }

    func testMenuTitles() {
        XCTAssertEqual(RotationAngle.normal.title, "0° (기본)")
        XCTAssertEqual(RotationAngle.right.title, "90°")
    }
}
