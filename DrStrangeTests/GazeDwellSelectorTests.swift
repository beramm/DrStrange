import XCTest
@testable import DrStrange

final class GazeDwellSelectorTests: XCTestCase {
    func testActivatesOnlyAfterContinuousDwell() {
        var selector = GazeDwellSelector(dwellNanoseconds: 600)

        XCTAssertNil(selector.consume(candidateHole: 4, timestampNanoseconds: 1_000, isUsable: true))
        XCTAssertNil(selector.consume(candidateHole: 4, timestampNanoseconds: 1_599, isUsable: true))
        XCTAssertEqual(selector.consume(candidateHole: 4, timestampNanoseconds: 1_600, isUsable: true), 4)
    }

    func testInvalidSampleRestartsDwell() {
        var selector = GazeDwellSelector(dwellNanoseconds: 600)

        XCTAssertNil(selector.consume(candidateHole: 2, timestampNanoseconds: 1_000, isUsable: true))
        XCTAssertNil(selector.consume(candidateHole: 2, timestampNanoseconds: 1_500, isUsable: false))
        XCTAssertNil(selector.consume(candidateHole: 2, timestampNanoseconds: 1_600, isUsable: true))
        XCTAssertNil(selector.consume(candidateHole: 2, timestampNanoseconds: 2_199, isUsable: true))
        XCTAssertEqual(selector.consume(candidateHole: 2, timestampNanoseconds: 2_200, isUsable: true), 2)
    }

    func testDoesNotRepeatWhileGazeRemainsOnSameHole() {
        var selector = GazeDwellSelector(dwellNanoseconds: 600)

        XCTAssertNil(selector.consume(candidateHole: 7, timestampNanoseconds: 1_000, isUsable: true))
        XCTAssertEqual(selector.consume(candidateHole: 7, timestampNanoseconds: 1_600, isUsable: true), 7)
        XCTAssertNil(selector.consume(candidateHole: 7, timestampNanoseconds: 2_500, isUsable: true))
        XCTAssertNil(selector.consume(candidateHole: nil, timestampNanoseconds: 2_600, isUsable: true))
        XCTAssertNil(selector.consume(candidateHole: 7, timestampNanoseconds: 3_000, isUsable: true))
        XCTAssertEqual(selector.consume(candidateHole: 7, timestampNanoseconds: 3_600, isUsable: true), 7)
    }
}
