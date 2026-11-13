import XCTest
@testable import DrStrangeGazeTracker

final class CoordinateTests: XCTestCase {
    func testTopLeftCoordinateConversionAndRoundTrip() throws {
        let viewport = try XCTUnwrap(GazeViewport(width: 1_366, height: 1_024))

        XCTAssertEqual(
            NormalizedGazePoint(viewportPoint: ViewportPoint(x: 0, y: 0), in: viewport),
            NormalizedGazePoint(x: 0, y: 0)
        )
        XCTAssertEqual(
            NormalizedGazePoint(viewportPoint: ViewportPoint(x: 1_366, y: 1_024), in: viewport),
            NormalizedGazePoint(x: 1, y: 1)
        )

        let center = try XCTUnwrap(NormalizedGazePoint(x: 0.5, y: 0.5))
        XCTAssertEqual(center.viewportPoint(in: viewport), ViewportPoint(x: 683, y: 512))
    }

    func testInvalidNormalizedCoordinatesAndViewportsAreRejected() {
        XCTAssertNil(NormalizedGazePoint(x: -0.01, y: 0.5))
        XCTAssertNil(NormalizedGazePoint(x: 0.5, y: 1.01))
        XCTAssertNil(NormalizedGazePoint(x: .nan, y: 0.5))
        XCTAssertNil(GazeViewport(width: 0, height: 100))
        XCTAssertNil(GazeViewport(width: 100, height: .infinity))
    }
}
