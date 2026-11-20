import XCTest
@testable import DrStrange

final class PaddyMiniGameCursorTests: XCTestCase {
    func testMiniGamesMapCalibratedGazeAcrossTheFullScreen() {
        let frame = CGRect(x: 20, y: 40, width: 1_000, height: 700)
        XCTAssertEqual(
            PaddyGazeScreenGeometry.point(CGPoint(x: 0.08, y: 0.92), in: frame),
            CGPoint(x: 100, y: 684)
        )
        XCTAssertEqual(
            PaddyGazeScreenGeometry.point(CGPoint(x: 0.5, y: 0.5), in: frame),
            CGPoint(x: 520, y: 390)
        )
    }

    @MainActor
    func testVeggieDashDoesNotFilterTheSharedSmoothedPointTwice() {
        let game = FoxPathGameViewModel(configuration: FoxPathConfiguration(), pointerTimeout: 0.5)
        game.pointerMoved(to: CGPoint(x: 100, y: 100), alreadySmoothed: true)
        game.pointerMoved(to: CGPoint(x: 300, y: 200), alreadySmoothed: true)
        XCTAssertEqual(game.pointer, CGPoint(x: 300, y: 200))
    }
}
