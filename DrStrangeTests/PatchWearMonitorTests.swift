import XCTest
@testable import DrStrange

final class PatchWearMonitorTests: XCTestCase {
    func testVerifiesOnlyAfterExpectedEyeIsContinuouslyVisible() {
        var monitor = PatchWearMonitor(verificationDuration: 1_500, removalDuration: 1_000)

        XCTAssertEqual(monitor.consume(.expectedEyeOnly, timestampNanoseconds: 1_000), .checking)
        XCTAssertEqual(monitor.consume(.expectedEyeOnly, timestampNanoseconds: 2_499), .checking)
        XCTAssertEqual(monitor.consume(.expectedEyeOnly, timestampNanoseconds: 2_500), .verified)
    }

    func testBlinkLikeInterruptionRestartsVerification() {
        var monitor = PatchWearMonitor(verificationDuration: 1_500, removalDuration: 1_000)

        XCTAssertEqual(monitor.consume(.expectedEyeOnly, timestampNanoseconds: 1_000), .checking)
        XCTAssertEqual(monitor.consume(.unavailable, timestampNanoseconds: 2_000), .checking)
        XCTAssertEqual(monitor.consume(.expectedEyeOnly, timestampNanoseconds: 2_100), .checking)
        XCTAssertEqual(monitor.consume(.expectedEyeOnly, timestampNanoseconds: 3_599), .checking)
        XCTAssertEqual(monitor.consume(.expectedEyeOnly, timestampNanoseconds: 3_600), .verified)
    }

    func testSustainedTwoEyeVisibilityMarksPatchMissing() {
        var monitor = verifiedMonitor()

        XCTAssertEqual(monitor.consume(.bothEyes, timestampNanoseconds: 3_000), .verified)
        XCTAssertEqual(monitor.consume(.bothEyes, timestampNanoseconds: 3_999), .verified)
        XCTAssertEqual(monitor.consume(.bothEyes, timestampNanoseconds: 4_000), .missing)
    }

    func testBriefTwoEyeVisibilityDoesNotPause() {
        var monitor = verifiedMonitor()

        XCTAssertEqual(monitor.consume(.bothEyes, timestampNanoseconds: 3_000), .verified)
        XCTAssertEqual(monitor.consume(.expectedEyeOnly, timestampNanoseconds: 3_800), .verified)
        XCTAssertEqual(monitor.consume(.bothEyes, timestampNanoseconds: 4_000), .verified)
        XCTAssertEqual(monitor.consume(.bothEyes, timestampNanoseconds: 4_999), .verified)
    }

    func testMissingPatchMustBeReverifiedBeforeResume() {
        var monitor = verifiedMonitor()
        XCTAssertEqual(monitor.consume(.bothEyes, timestampNanoseconds: 3_000), .verified)
        XCTAssertEqual(monitor.consume(.bothEyes, timestampNanoseconds: 4_000), .missing)

        XCTAssertEqual(monitor.consume(.expectedEyeOnly, timestampNanoseconds: 4_100), .checking)
        XCTAssertEqual(monitor.consume(.expectedEyeOnly, timestampNanoseconds: 5_599), .checking)
        XCTAssertEqual(monitor.consume(.expectedEyeOnly, timestampNanoseconds: 5_600), .verified)
    }

    func testWrongEyeAloneCannotVerifyPatch() {
        var monitor = PatchWearMonitor(verificationDuration: 1_500, removalDuration: 1_000)

        XCTAssertEqual(monitor.consume(.otherEyeOnly, timestampNanoseconds: 1_000), .checking)
        XCTAssertEqual(monitor.consume(.otherEyeOnly, timestampNanoseconds: 3_000), .checking)
    }

    private func verifiedMonitor() -> PatchWearMonitor {
        var monitor = PatchWearMonitor(verificationDuration: 1_500, removalDuration: 1_000)
        _ = monitor.consume(.expectedEyeOnly, timestampNanoseconds: 1_000)
        _ = monitor.consume(.expectedEyeOnly, timestampNanoseconds: 2_500)
        return monitor
    }
}
