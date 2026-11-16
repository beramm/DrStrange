import XCTest
@testable import DrStrange

final class FoxPathEngineTests: XCTestCase {
    private let step = 1.0 / 60

    private func makeEngine(routeLength: Double = 1000) -> FoxPathEngine {
        // 48 units per second, 0.7 s grace, 0.35 s refocus dwell.
        let settings = FoxPathSettings(
            foxSpeed: 48,
            followRadius: 230,
            lookAwayGrace: 0.7,
            refocusDwell: 0.35,
            straightRunRange: 2...3,
            turnHeightRange: 1...2
        )
        return FoxPathEngine(settings: settings, routeLength: routeLength)
    }

    /// Feeds the same reading for `seconds` and returns every event.
    @discardableResult
    private func run(_ engine: inout FoxPathEngine, _ reading: FoxPointerReading, for seconds: Double) -> [FoxPathEvent] {
        var events: [FoxPathEvent] = []
        for _ in 0..<Int((seconds / step).rounded()) {
            events += engine.advance(by: step, reading: reading)
        }
        return events
    }

    func testNothingCountsBeforeTheFirstLookAtTheFox() {
        var engine = makeEngine()
        XCTAssertTrue(run(&engine, .away, for: 5).isEmpty)
        XCTAssertTrue(run(&engine, .unavailable, for: 5).isEmpty)
        XCTAssertEqual(engine.state, .waiting)
        XCTAssertEqual(engine.distance, 0)
        XCTAssertEqual(engine.elapsedTime, 0)
        XCTAssertEqual(engine.offTrackCount, 0)
    }

    func testFoxStartsAfterTheDwell() {
        var engine = makeEngine()
        XCTAssertTrue(run(&engine, .onFox, for: 0.2).isEmpty)
        XCTAssertGreaterThan(engine.refocusProgress, 0.4)
        XCTAssertEqual(run(&engine, .onFox, for: 0.3), [.started])
        XCTAssertEqual(engine.state, .following)
    }

    func testFoxWalksAtItsSpeedWhileFollowed() {
        var engine = makeEngine()
        run(&engine, .onFox, for: 0.5)
        let before = engine.distance
        run(&engine, .onFox, for: 2)
        XCTAssertEqual(engine.distance - before, engine.settings.foxSpeed * 2, accuracy: 0.5)
        XCTAssertTrue(engine.isWalking)
    }

    func testShortLookAwayIsForgiven() {
        var engine = makeEngine()
        run(&engine, .onFox, for: 0.5)
        XCTAssertTrue(run(&engine, .away, for: 0.5).isEmpty)
        XCTAssertTrue(run(&engine, .onFox, for: 0.2).isEmpty)
        // The grace time starts again after every look back.
        XCTAssertTrue(run(&engine, .away, for: 0.5).isEmpty)
        XCTAssertEqual(engine.state, .following)
        XCTAssertEqual(engine.offTrackCount, 0)
    }

    func testLongLookAwayStopsTheFoxUntilRefocus() {
        var engine = makeEngine()
        run(&engine, .onFox, for: 1)
        XCTAssertEqual(run(&engine, .away, for: 1), [.wentOffTrack])
        XCTAssertEqual(engine.state, .offTrack)
        XCTAssertFalse(engine.isWalking)

        let stoppedAt = engine.distance
        run(&engine, .away, for: 3)
        XCTAssertEqual(engine.distance, stoppedAt)
        XCTAssertEqual(engine.offTrackCount, 1, "one stop counts once however long it lasts")

        XCTAssertEqual(run(&engine, .onFox, for: 0.5), [.refocused])
        XCTAssertEqual(engine.state, .following)
        XCTAssertGreaterThan(engine.distance, stoppedAt)
    }

    func testGlanceDoesNotRefocus() {
        var engine = makeEngine()
        run(&engine, .onFox, for: 1)
        run(&engine, .away, for: 1)
        // Shorter than the dwell, then away again: the fox keeps waiting.
        XCTAssertTrue(run(&engine, .onFox, for: 0.2).isEmpty)
        XCTAssertTrue(run(&engine, .away, for: 0.5).isEmpty)
        XCTAssertEqual(engine.state, .offTrack)
        XCTAssertEqual(engine.refocusProgress, 0)
    }

    func testLostTrackingHoldsTheFoxWithoutBlame() {
        var engine = makeEngine()
        run(&engine, .onFox, for: 1)
        let heldAt = engine.distance
        XCTAssertTrue(run(&engine, .unavailable, for: 5).isEmpty)
        XCTAssertEqual(engine.state, .following)
        XCTAssertEqual(engine.distance, heldAt)
        XCTAssertEqual(engine.offTrackCount, 0)
        XCTAssertTrue(engine.needsPointer)

        run(&engine, .onFox, for: 0.1)
        XCTAssertFalse(engine.needsPointer)
        XCTAssertGreaterThan(engine.distance, heldAt)
    }

    func testFinishesOnceAtTheEndOfTheRoute() {
        var engine = makeEngine(routeLength: 96)
        let events = run(&engine, .onFox, for: 4)
        XCTAssertEqual(events, [.started, .finished])
        XCTAssertEqual(engine.state, .finished)
        XCTAssertEqual(engine.progress, 1)
        XCTAssertEqual(engine.followingTime, 2, accuracy: 0.05)
        XCTAssertTrue(run(&engine, .away, for: 2).isEmpty, "nothing happens after the finish")
    }
}
