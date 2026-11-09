import XCTest
@testable import DrStrange

final class GazeDwellSelectorTests: XCTestCase {
    private func candidate(
        targetID: Int = 40,
        holeIndex: Int = 4,
        distance: Double = 0.5
    ) -> GazeFocusCandidate {
        GazeFocusCandidate(
            targetID: targetID,
            holeIndex: holeIndex,
            normalizedDistance: distance
        )
    }

    func testDefaultConfirmationIsOneSecond() {
        XCTAssertEqual(GazeDwellSelector.defaultDwellNanoseconds, 1_000_000_000)
    }

    func testActivatesOnlyAfterContinuousDwell() {
        var selector = GazeDwellSelector(dwellNanoseconds: 600, scoringWindowNanoseconds: 300)

        XCTAssertNil(selector.consume(candidate: candidate(), timestampNanoseconds: 1_000, isUsable: true).activation)
        XCTAssertNil(selector.consume(candidate: candidate(), timestampNanoseconds: 1_599, isUsable: true).activation)
        XCTAssertEqual(
            selector.consume(candidate: candidate(), timestampNanoseconds: 1_600, isUsable: true).activation,
            GazeActivation(targetID: 40, holeIndex: 4, tier: .middle)
        )
    }

    func testInvalidSampleRestartsDwell() {
        var selector = GazeDwellSelector(dwellNanoseconds: 600)

        let target = candidate(holeIndex: 2)
        XCTAssertNil(selector.consume(candidate: target, timestampNanoseconds: 1_000, isUsable: true).activation)
        XCTAssertNil(selector.consume(candidate: target, timestampNanoseconds: 1_500, isUsable: false).activation)
        XCTAssertNil(selector.consume(candidate: target, timestampNanoseconds: 1_600, isUsable: true).activation)
        XCTAssertNil(selector.consume(candidate: target, timestampNanoseconds: 2_199, isUsable: true).activation)
        XCTAssertEqual(selector.consume(candidate: target, timestampNanoseconds: 2_200, isUsable: true).activation?.holeIndex, 2)
    }

    func testDoesNotRepeatWhileGazeRemainsOnSameTarget() {
        var selector = GazeDwellSelector(dwellNanoseconds: 600)
        let target = candidate(targetID: 70, holeIndex: 7)

        XCTAssertNil(selector.consume(candidate: target, timestampNanoseconds: 1_000, isUsable: true).activation)
        XCTAssertEqual(selector.consume(candidate: target, timestampNanoseconds: 1_600, isUsable: true).activation?.holeIndex, 7)
        XCTAssertNil(selector.consume(candidate: target, timestampNanoseconds: 2_500, isUsable: true).activation)
        XCTAssertNil(selector.consume(candidate: nil, timestampNanoseconds: 2_600, isUsable: true).activation)
        XCTAssertNil(selector.consume(candidate: target, timestampNanoseconds: 3_000, isUsable: true).activation)
        XCTAssertEqual(selector.consume(candidate: target, timestampNanoseconds: 3_600, isUsable: true).activation?.holeIndex, 7)
    }

    func testSwitchingTargetsRestartsDwell() {
        var selector = GazeDwellSelector(dwellNanoseconds: 600)

        _ = selector.consume(candidate: candidate(targetID: 1), timestampNanoseconds: 1_000, isUsable: true)
        _ = selector.consume(candidate: candidate(targetID: 1), timestampNanoseconds: 1_500, isUsable: true)
        XCTAssertNil(selector.consume(candidate: candidate(targetID: 2), timestampNanoseconds: 1_550, isUsable: true).activation)
        XCTAssertNil(selector.consume(candidate: candidate(targetID: 2), timestampNanoseconds: 2_149, isUsable: true).activation)
        XCTAssertEqual(selector.consume(candidate: candidate(targetID: 2), timestampNanoseconds: 2_150, isUsable: true).activation?.targetID, 2)
    }

    func testUsesMedianDistanceFromFinalScoringWindow() {
        var selector = GazeDwellSelector(dwellNanoseconds: 1_000, scoringWindowNanoseconds: 400)

        _ = selector.consume(candidate: candidate(distance: 0.9), timestampNanoseconds: 1_000, isUsable: true)
        _ = selector.consume(candidate: candidate(distance: 0.2), timestampNanoseconds: 1_700, isUsable: true)
        _ = selector.consume(candidate: candidate(distance: 0.25), timestampNanoseconds: 1_850, isUsable: true)
        let update = selector.consume(candidate: candidate(distance: 0.95), timestampNanoseconds: 2_000, isUsable: true)

        XCTAssertEqual(update.activation?.tier, .inner, "one noisy sample must not decide the score")
        XCTAssertEqual(update.activation?.tier.points, 30)
    }

    func testProximityTierBoundaries() {
        XCTAssertEqual(GazeProximityTier(normalizedDistance: 0.35), .inner)
        XCTAssertEqual(GazeProximityTier(normalizedDistance: 0.36), .middle)
        XCTAssertEqual(GazeProximityTier(normalizedDistance: 0.70), .middle)
        XCTAssertEqual(GazeProximityTier(normalizedDistance: 0.71), .outer)
    }
}
