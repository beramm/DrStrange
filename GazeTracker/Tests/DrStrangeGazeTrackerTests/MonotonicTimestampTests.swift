import XCTest
@testable import DrStrangeGazeTracker

final class MonotonicTimestampTests: XCTestCase {
    func testPublishedTimestampsRemainStrictlyIncreasingWhenClockRepeatsOrSourceRegresses() async throws {
        let runtime = TestRuntime()
        let clock = TestClock(42)
        let (tracker, _, _, recorder) = makeTracker(runtime: runtime, clock: clock)

        try await tracker.start()
        runtime.emit(timestamp: 10)
        try tracker.pause()

        let timestamps = recorder.samples.map(\.timestamp.uptimeNanoseconds)
        XCTAssertEqual(timestamps.count, 4)
        XCTAssertTrue(zip(timestamps, timestamps.dropFirst()).allSatisfy(<))
    }

    func testDurationUsesMonotonicNanosecondsAndRejectsReverseOrder() {
        let start = MonotonicTimestamp(uptimeNanoseconds: 2_000_000_000)
        let end = MonotonicTimestamp(uptimeNanoseconds: 3_500_000_000)

        XCTAssertEqual(end.durationSince(start), 1.5)
        XCTAssertNil(start.durationSince(end))
    }
}
