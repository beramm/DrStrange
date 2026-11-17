import XCTest
@testable import DrStrange

final class CalibrationSampleGateTests: XCTestCase {
    func testRepeatedAcceptedFramesProduceOnlyOneTargetResult() {
        var gate = CalibrationSampleGate()
        gate.markTargetStarted(at: 100)

        XCTAssertEqual(
            gate.evaluate(timestampNanoseconds: 200, isTargetResult: true),
            .init(shouldConsume: true, isCurrentTargetResult: true)
        )
        XCTAssertEqual(
            gate.evaluate(timestampNanoseconds: 300, isTargetResult: true),
            .init(shouldConsume: true, isCurrentTargetResult: false)
        )
    }

    func testPreviousAcceptanceCannotConsumeTheNextTargetResult() {
        var gate = CalibrationSampleGate()
        gate.markTargetStarted(at: 100)
        _ = gate.evaluate(timestampNanoseconds: 200, isTargetResult: true)

        gate.markTargetStarted(at: 400)

        XCTAssertEqual(
            gate.evaluate(timestampNanoseconds: 350, isTargetResult: true),
            .init(shouldConsume: true, isCurrentTargetResult: false)
        )
        XCTAssertEqual(
            gate.evaluate(timestampNanoseconds: 500, isTargetResult: true),
            .init(shouldConsume: true, isCurrentTargetResult: true)
        )
    }

    func testOutOfOrderSampleIsNotConsumed() {
        var gate = CalibrationSampleGate()

        _ = gate.evaluate(timestampNanoseconds: 300, isTargetResult: false)
        XCTAssertEqual(
            gate.evaluate(timestampNanoseconds: 200, isTargetResult: false),
            .init(shouldConsume: false, isCurrentTargetResult: false)
        )
    }
}
