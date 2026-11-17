import XCTest
@_spi(Platform) @_spi(Engineering) @testable import DrStrangeGazeTracker

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

    func testEngineeringOverrideAllowsCalibrationWithBothEyesVisible() async throws {
        let (tracker, runtime, _, recorder) = makeTracker()

        try await tracker.start()
        runtime.emit(timestamp: 10, setupState: .ready, eyeAvailability: .both)
        XCTAssertThrowsError(try tracker.beginCalibration()) { error in
            XCTAssertEqual(error as? CalibrationContractError, .setupNotReady)
        }

        tracker.setOneEyeEnforcementEnabled(false)
        try tracker.beginCalibration()

        XCTAssertEqual(recorder.last?.calibrationState, .readyForTarget)
        XCTAssertEqual(recorder.last?.eyeAvailability, .both)
    }

    func testEngineeringOverrideAllowsTheVisibleLeftEye() async throws {
        let (tracker, runtime, _, recorder) = makeTracker()

        try await tracker.start()
        tracker.setOneEyeEnforcementEnabled(false)
        runtime.emit(timestamp: 10, setupState: .ready, eyeAvailability: .leftOnly)
        try tracker.beginCalibration()

        XCTAssertEqual(recorder.last?.calibrationState, .readyForTarget)
        XCTAssertEqual(recorder.last?.eyeAvailability, .leftOnly)
    }

    func testOneEyeEnforcementAllowsEitherSingleVisibleEye() async throws {
        for visibleEye in [EyeAvailability.leftOnly, .rightOnly] {
            let (tracker, runtime, _, recorder) = makeTracker()
            try await tracker.start()
            runtime.emit(timestamp: 10, setupState: .ready, eyeAvailability: visibleEye)

            try tracker.beginCalibration()

            XCTAssertEqual(recorder.last?.calibrationState, .readyForTarget)
            XCTAssertEqual(recorder.last?.eyeAvailability, visibleEye)
        }
    }

    func testEngineeringOverrideCanBeTurnedBackOn() async throws {
        let (tracker, runtime, _, _) = makeTracker()

        try await tracker.start()
        runtime.emit(timestamp: 10, setupState: .ready, eyeAvailability: .both)
        tracker.setOneEyeEnforcementEnabled(false)
        try tracker.beginCalibration()
        tracker.cancelCalibration()

        tracker.setOneEyeEnforcementEnabled(true)
        XCTAssertThrowsError(try tracker.beginCalibration()) { error in
            XCTAssertEqual(error as? CalibrationContractError, .setupNotReady)
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

    func testExcessiveMovementInvalidatesCompletedCalibration() async throws {
        let (tracker, runtime, _, recorder) = makeTracker()
        try await tracker.start()
        runtime.emit(timestamp: 10, setupState: .ready, eyeAvailability: .rightOnly)
        try tracker.beginCalibration()

        var timestamp: UInt64 = 10
        for target in CalibrationLayout.ninePosition.targets {
            try tracker.beginCalibrationTarget(at: target)
            for _ in 0..<100 {
                timestamp += 16_666_667
                runtime.emit(
                    timestamp: timestamp,
                    setupState: .ready,
                    eyeAvailability: .rightOnly,
                    selectedEyeRay: makeCalibrationRay(for: target)
                )
                if recorder.last?.calibrationState != .collecting { break }
            }
        }
        XCTAssertEqual(recorder.last?.calibrationState, .calibrated)

        runtime.emit(
            timestamp: timestamp + 16_666_667,
            setupState: .movingTooMuch,
            eyeAvailability: .rightOnly,
            selectedEyeRay: makeCalibrationRay(for: CalibrationLayout.ninePosition.targets[4])
        )

        XCTAssertEqual(recorder.last?.calibrationState, .invalid)
        XCTAssertNil(recorder.last?.pointNormalized)
    }

    func testExcessiveMovementInvalidatesCalibrationInProgress() async throws {
        let (tracker, runtime, _, recorder) = makeTracker()
        let target = try XCTUnwrap(CalibrationLayout.ninePosition.targets.first)
        try await tracker.start()
        runtime.emit(timestamp: 10, setupState: .ready, eyeAvailability: .rightOnly)
        try tracker.beginCalibration()
        try tracker.beginCalibrationTarget(at: target)

        runtime.emit(
            timestamp: 20,
            setupState: .movingTooMuch,
            eyeAvailability: .rightOnly,
            selectedEyeRay: makeCalibrationRay(for: target)
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

    private func makeCalibrationRay(for target: NormalizedGazePoint) -> SelectedEyeRayObservation {
        let horizontal = (target.x - 0.5) * 0.4
        let vertical = (target.y - 0.5) * 0.4
        return SelectedEyeRayObservation(
            originX: 0,
            originY: -0.1,
            originZ: -0.4,
            directionX: horizontal,
            directionY: vertical,
            directionZ: 1,
            baselineDirectionX: horizontal,
            baselineDirectionY: vertical,
            headDirectionX: 0,
            headDirectionY: 0,
            headDirectionZ: 1,
            faceDistanceMeters: 0.4,
            selectedEyeBlink: 0,
            publicationLatencyMilliseconds: 20
        )
    }
}
