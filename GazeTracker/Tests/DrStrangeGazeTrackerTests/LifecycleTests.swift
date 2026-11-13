import XCTest
@testable import DrStrangeGazeTracker

final class LifecycleTests: XCTestCase {
    func testStartPauseResumeStopTransitionsAndReleasesRuntime() async throws {
        let (tracker, runtime, _, recorder) = makeTracker()

        try await tracker.start()
        XCTAssertEqual(recorder.last?.trackingState, .limited)
        XCTAssertEqual(runtime.startResetArguments, [true])

        try tracker.pause()
        XCTAssertEqual(recorder.last?.trackingState, .paused)
        XCTAssertEqual(recorder.last?.setupState, .unknown)
        XCTAssertEqual(recorder.last?.eyeAvailability, EyeAvailability.none)
        XCTAssertEqual(runtime.pauseCount, 1)

        try await tracker.resume()
        XCTAssertEqual(recorder.last?.trackingState, .limited)
        XCTAssertEqual(runtime.startResetArguments, [true, false])

        tracker.stop()
        XCTAssertEqual(recorder.last?.trackingState, .paused)
        XCTAssertEqual(recorder.last?.setupState, .unknown)
        XCTAssertEqual(recorder.last?.eyeAvailability, EyeAvailability.none)
        XCTAssertEqual(recorder.last?.calibrationState, .notCalibrated)
        XCTAssertEqual(runtime.stopCount, 1)
    }

    func testInvalidLifecycleTransitionsAreRejected() async throws {
        let (tracker, _, _, recorder) = makeTracker()

        XCTAssertThrowsError(try tracker.pause()) { error in
            XCTAssertEqual(error as? GazeTrackerError, .invalidLifecycleTransition)
        }

        try await tracker.start()
        do {
            try await tracker.start()
            XCTFail("A running tracker must reject a second start")
        } catch {
            XCTAssertEqual(error as? GazeTrackerError, .invalidLifecycleTransition)
        }
        XCTAssertEqual(recorder.last?.trackingState, .limited)
    }

    func testUnsupportedStartPublishesUnsupported() async {
        let runtime = TestRuntime()
        runtime.support = GazeSupport(isSupported: false, cameraAuthorization: .restricted)
        let (tracker, _, _, recorder) = makeTracker(runtime: runtime)

        do {
            try await tracker.start()
            XCTFail("Unsupported runtime must reject start")
        } catch {
            XCTAssertEqual(error as? GazeTrackerError, .unsupported)
        }
        XCTAssertEqual(recorder.last?.trackingState, .unsupported)
    }
}
