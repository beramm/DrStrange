import XCTest
@_spi(Platform) @testable import DrStrangeGazeTracker

final class CalibrationStateTests: XCTestCase {
    func testCalibrationContractRequiresReadySetupAndStartsExpectedTarget() async throws {
        let (tracker, runtime, _, recorder) = makeTracker()
        let target = try XCTUnwrap(CalibrationLayout.ninePosition.targets.first)

        try await tracker.start()
        XCTAssertThrowsError(try tracker.beginCalibration()) { error in
            XCTAssertEqual(error as? CalibrationContractError, .setupNotReady)
        }
        runtime.emit(timestamp: 10, setupState: .ready, eyeAvailability: .rightOnly)
        try tracker.beginCalibration()
        XCTAssertEqual(recorder.last?.calibrationState, .readyForTarget)

        try tracker.beginCalibrationTarget(at: target)
        XCTAssertEqual(recorder.last?.calibrationState, .collecting)
        XCTAssertNil(recorder.last?.pointNormalized)

        tracker.cancelCalibration()
        XCTAssertEqual(recorder.last?.calibrationState, .notCalibrated)
    }

    func testCalibrationCannotBeginWhileStopped() {
        let (tracker, _, _, _) = makeTracker()

        XCTAssertThrowsError(try tracker.beginCalibration()) { error in
            XCTAssertEqual(error as? CalibrationContractError, .trackingNotRunning)
        }
    }

    func testEveryAcceptedInvalidationReasonTransitionsToInvalid() async throws {
        let reasons: [CalibrationInvalidationReason] = [
            .faceRepositioned,
            .deviceRemounted,
            .orientationChanged,
            .cameraPositionChanged,
            .viewingPositionChanged,
            .activeEyeOrPatchSideChanged,
            .setupChanged,
            .explicitlyRequested
        ]

        for reason in reasons {
            let (tracker, runtime, _, recorder) = makeTracker()
            try await tracker.start()
            runtime.emit(timestamp: 10, setupState: .ready, eyeAvailability: .rightOnly)
            try tracker.beginCalibration()
            tracker.invalidateCalibration(reason: reason)
            XCTAssertEqual(recorder.last?.calibrationState, .invalid, "Reason: \(reason)")
            XCTAssertNil(recorder.last?.pointNormalized)
        }
    }

    func testFaceLossWithRepositioningInvalidatesCalibration() async throws {
        let (tracker, runtime, _, recorder) = makeTracker()
        try await tracker.start()
        runtime.emit(
            timestamp: 10,
            setupState: .ready,
            eyeAvailability: .rightOnly,
            selectedEyeRay: makeRay(originX: 0)
        )
        try tracker.beginCalibration()

        runtime.emit(timestamp: 20, trackingState: .lost, setupState: .unknown, eyeAvailability: .none)
        runtime.emit(
            timestamp: 30,
            setupState: .ready,
            eyeAvailability: .rightOnly,
            selectedEyeRay: makeRay(originX: 0.04)
        )

        XCTAssertEqual(recorder.last?.calibrationState, .invalid)
        XCTAssertNil(recorder.last?.pointNormalized)
    }

    private func makeRay(originX: Double) -> SelectedEyeRayObservation {
        SelectedEyeRayObservation(
            originX: originX,
            originY: -0.1,
            originZ: -0.4,
            directionX: 0,
            directionY: -0.1,
            directionZ: 1,
            faceDistanceMeters: 0.4,
            selectedEyeBlink: 0,
            publicationLatencyMilliseconds: 20
        )
    }
}
