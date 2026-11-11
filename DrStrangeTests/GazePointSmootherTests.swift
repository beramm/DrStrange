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

    func testSmallJitterIsStronglyDamped() {
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

        XCTAssertNotNil(filtered)
        XCTAssertGreaterThan(filtered?.x ?? 0, 0.5)
        XCTAssertLessThan(filtered?.x ?? 1, 0.505)
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

        XCTAssertGreaterThan(filtered?.x ?? 0, 0.48)
        XCTAssertLessThan(filtered?.x ?? 1, 0.8)
    }

    func testInvalidTrackingResetsSmoothing() {
        var smoother = GazePointSmoother()
        _ = smoother.consume(
            point: CGPoint(x: 0.2, y: 0.2),
            timestampNanoseconds: 1_000,
            isUsable: true
        )
        XCTAssertNil(smoother.consume(point: nil, timestampNanoseconds: 2_000, isUsable: false))

        let reacquired = CGPoint(x: 0.8, y: 0.8)
        XCTAssertEqual(
            smoother.consume(point: reacquired, timestampNanoseconds: 3_000, isUsable: true),
            reacquired
        )
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
                timestampNanoseconds: 1_300_000_001,
                isUsable: true
            ),
            current
        )
    }
}
