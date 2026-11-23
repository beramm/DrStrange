import XCTest
@testable import DrStrange

final class GazePointSmootherTests: XCTestCase {
    func testFirstUsablePointPassesThrough() {
        var smoother = GazePointSmoother()
        let point = CGPoint(x: 0.25, y: 0.75)

        XCTAssertEqual(
            smoother.consume(point: point, timestampNanoseconds: 1_000, isUsable: true),
            point
        )
    }

    func testSmallJitterStaysInsideSoftDeadZone() {
        var smoother = GazePointSmoother()
        _ = smoother.consume(
            point: CGPoint(x: 0.5, y: 0.5),
            timestampNanoseconds: 1_000_000_000,
            isUsable: true
        )

        let filtered = smoother.consume(
            point: CGPoint(x: 0.52, y: 0.5),
            timestampNanoseconds: 1_016_666_667,
            isUsable: true
        )

        XCTAssertEqual(filtered, CGPoint(x: 0.5, y: 0.5))
    }

    func testLargeIntentionalMoveRespondsQuickly() {
        var smoother = GazePointSmoother()
        _ = smoother.consume(
            point: CGPoint(x: 0.2, y: 0.5),
            timestampNanoseconds: 1_000_000_000,
            isUsable: true
        )

        let filtered = smoother.consume(
            point: CGPoint(x: 0.8, y: 0.5),
            timestampNanoseconds: 1_016_666_667,
            isUsable: true
        )

        XCTAssertGreaterThan(filtered?.x ?? 0, 0.2)
        XCTAssertLessThan(filtered?.x ?? 1, 0.8)
    }

    func testBriefTrackingLossKeepsSmoothing() {
        var smoother = GazePointSmoother()
        _ = smoother.consume(
            point: CGPoint(x: 0.2, y: 0.2),
            timestampNanoseconds: 1_000_000_000,
            isUsable: true
        )
        XCTAssertNil(smoother.consume(
            point: nil,
            timestampNanoseconds: 1_033_000_000,
            isUsable: false
        ))

        let reacquired = CGPoint(x: 0.8, y: 0.8)
        let filtered = smoother.consume(
            point: reacquired,
            timestampNanoseconds: 1_066_000_000,
            isUsable: true
        )
        XCTAssertGreaterThan(filtered?.x ?? 0, 0.2)
        XCTAssertLessThan(filtered?.x ?? 1, reacquired.x)
    }

    func testLongTrackingLossResetsSmoothing() {
        var smoother = GazePointSmoother()
        _ = smoother.consume(
            point: CGPoint(x: 0.2, y: 0.2),
            timestampNanoseconds: 1_000_000_000,
            isUsable: true
        )
        XCTAssertNil(smoother.consume(
            point: nil,
            timestampNanoseconds: 1_500_000_001,
            isUsable: false
        ))

        let reacquired = CGPoint(x: 0.8, y: 0.8)
        XCTAssertEqual(smoother.consume(
            point: reacquired,
            timestampNanoseconds: 1_600_000_000,
            isUsable: true
        ), reacquired)
    }

    func testLongSampleGapSnapsToCurrentPoint() {
        var smoother = GazePointSmoother()
        _ = smoother.consume(
            point: CGPoint(x: 0.2, y: 0.2),
            timestampNanoseconds: 1_000_000_000,
            isUsable: true
        )

        let current = CGPoint(x: 0.7, y: 0.7)
        XCTAssertEqual(
            smoother.consume(
                point: current,
                timestampNanoseconds: 1_500_000_001,
                isUsable: true
            ),
            current
        )
    }
}
