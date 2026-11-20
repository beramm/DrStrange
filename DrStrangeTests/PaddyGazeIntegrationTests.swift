import DrStrangeGazeTracker
import SwiftUI
import XCTest
@testable import DrStrange

final class PaddyGazeIntegrationTests: XCTestCase {
    @MainActor
    func testPreparationCountdownDisplaysThreeThroughZero() {
        XCTAssertEqual(GazeInputController.countdownValues(preparationSeconds: 4), [3, 2, 1, 0])
    }

    func testCalibrationTargetsHaveExactOrderAndBottomRow() {
        let expected: [(Double, Double)] = [
            (0.08, 0.08), (0.29, 0.08), (0.50, 0.08), (0.71, 0.08), (0.92, 0.08),
            (0.92, 0.50), (0.92, 0.92), (0.71, 0.92), (0.50, 0.92),
            (0.29, 0.92), (0.08, 0.92), (0.08, 0.50), (0.50, 0.50)
        ]
        XCTAssertEqual(PaddyCalibrationCapture.targets.count, 13)
        for (actual, expected) in zip(PaddyCalibrationCapture.targets, expected) {
            XCTAssertEqual(actual.x, expected.0, accuracy: 0.000_001)
            XCTAssertEqual(actual.y, expected.1, accuracy: 0.000_001)
        }
    }

    func testCaptureNeedsSixRawSamplesAndRejectsOutlier() {
        let stable = [
            GazeCoordinate(x: 2.00, y: -0.40), GazeCoordinate(x: 2.01, y: -0.40),
            GazeCoordinate(x: 2.00, y: -0.39), GazeCoordinate(x: 1.99, y: -0.40),
            GazeCoordinate(x: 2.00, y: -0.41), GazeCoordinate(x: 2.00, y: -0.40)
        ]
        XCTAssertNil(PaddyCalibrationCapture.reduce(Array(stable.prefix(5))))
        let raw = PaddyCalibrationCapture.reduce(stable + [GazeCoordinate(x: 100, y: 100)])
        XCTAssertEqual(raw?.x ?? .nan, 2, accuracy: 0.01)
        XCTAssertEqual(raw?.y ?? .nan, -0.40, accuracy: 0.01)
        // Raw model units survive capture; the visual filter never participates here.
        XCTAssertGreaterThan(raw?.x ?? 0, 1)
    }

    func testCaptureRequiresFullStableWindow() {
        XCTAssertFalse(PaddyCalibrationCapture.hasCompleteWindow(
            elapsed: 2.0, stableDuration: 0.69, sampleCount: 20
        ))
        XCTAssertFalse(PaddyCalibrationCapture.hasCompleteWindow(
            elapsed: 0.69, stableDuration: 0.70, sampleCount: 6
        ))
        XCTAssertTrue(PaddyCalibrationCapture.hasCompleteWindow(
            elapsed: 0.70, stableDuration: 0.70, sampleCount: 6
        ))
    }

    func testIncompleteCalibrationIsRejected() {
        let samples = PaddyCalibrationCapture.targets.dropLast().map {
            GazeCalibrationSample(raw: GazeCoordinate(x: $0.x, y: $0.y), target: $0)
        }
        XCTAssertThrowsError(try PaddyCalibrationCapture.fitComplete(samples))
    }

    func testQuadraticMappingSelectedForCurvedRawPredictions() throws {
        let samples = PaddyCalibrationCapture.targets.map { target in
            let x = target.x
            let y = target.y
            return GazeCalibrationSample(
                raw: GazeCoordinate(x: x + 0.45 * (x - 0.5) * (x - 0.5), y: y),
                target: target
            )
        }
        let calibration = try PaddyCalibrationCapture.fitComplete(samples)
        XCTAssertEqual(calibration.kind, .quadratic)
    }

    func testCalibrationScreenUsesWhiteBackground() {
        XCTAssertEqual(GazeCalibrationView.calibrationBackground, Color.white)
    }

    @MainActor
    func testCancellationClearsCalibrationAndReturnsToStoppedState() {
        let controller = GazeInputController()
        controller.stop()
        XCTAssertNil(controller.activeCalibrationTarget)
        XCTAssertFalse(controller.isCalibrated)
        XCTAssertEqual(controller.sample.trackingState, .paused)
    }

    @MainActor
    func testCompleteCalibrationSignalsGameTransitionOnlyAfterSuccessfulFit() {
        let controller = GazeInputController()
        let samples = PaddyCalibrationCapture.targets.map { target in
            GazeCalibrationSample(
                raw: GazeCoordinate(x: target.x, y: target.y),
                target: target
            )
        }

        controller.finishCalibration(Array(samples.dropLast()))
        XCTAssertEqual(controller.completedCalibrationCount, 0)
        XCTAssertFalse(controller.isCalibrated)
        XCTAssertEqual(controller.sample.calibrationState, .failed)

        controller.finishCalibration(samples)
        XCTAssertEqual(controller.completedCalibrationCount, 1)
        XCTAssertTrue(controller.isCalibrated)
        XCTAssertEqual(controller.sample.calibrationState, .calibrated)
    }

    @MainActor
    func testGameplayKeepsValidGazeWhenFaceMovesOutsideCalibrationAlignment() {
        let controller = GazeInputController()
        controller.setOneEyeEnforcerEnabled(false)
        controller.finishCalibration(PaddyCalibrationCapture.targets.map { target in
            GazeCalibrationSample(
                raw: GazeCoordinate(x: target.x, y: target.y),
                target: target
            )
        })

        for index in 0..<3 {
            controller.consume(PaddyFrameAnalysis(
                hostUptime: Double(index + 1),
                imageOrientation: .up,
                prediction: EyeStripPrediction(
                    xScreenCentered: 0.5,
                    yScreenCentered: 0.5,
                    inferenceDurationMS: 5
                ),
                setupCandidate: .misaligned,
                eyeAvailability: .both,
                isSceneTooDark: false,
                captureRejectionReason: "the face was not aligned with the screen",
                modelStatus: "paddy-gazeTrack active · on-device",
                previewImage: nil
            ))
        }

        XCTAssertEqual(controller.sample.setupState, .misaligned)
        XCTAssertEqual(controller.sample.trackingState, .tracking)
        XCTAssertTrue(controller.hasUsableGaze)
        XCTAssertNotNil(controller.sample.pointNormalized)

        controller.consume(PaddyFrameAnalysis(
            hostUptime: 4,
            imageOrientation: .up,
            prediction: nil,
            setupCandidate: .stabilizing,
            eyeAvailability: .none,
            isSceneTooDark: false,
            captureRejectionReason: "the model lost one or both eye regions",
            modelStatus: "paddy-gazeTrack waiting for eye regions",
            previewImage: nil
        ))
        XCTAssertEqual(controller.sample.trackingState, .lost)
        XCTAssertFalse(controller.hasUsableGaze)
        XCTAssertNil(controller.sample.pointNormalized)
    }

    @MainActor
    func testOlderAnalysisCannotMoveCursorBackToStalePrediction() {
        let controller = GazeInputController()
        controller.setOneEyeEnforcerEnabled(false)
        controller.finishCalibration(PaddyCalibrationCapture.targets.map { target in
            GazeCalibrationSample(raw: GazeCoordinate(x: target.x, y: target.y), target: target)
        })

        func analysis(at uptime: TimeInterval, x: Double) -> PaddyFrameAnalysis {
            PaddyFrameAnalysis(
                hostUptime: uptime,
                imageOrientation: .up,
                prediction: EyeStripPrediction(
                    xScreenCentered: x,
                    yScreenCentered: 0.5,
                    inferenceDurationMS: 5
                ),
                setupCandidate: .ready,
                eyeAvailability: .both,
                isSceneTooDark: false,
                captureRejectionReason: nil,
                modelStatus: "paddy-gazeTrack active · on-device",
                previewImage: nil
            )
        }

        controller.consume(analysis(at: 2, x: 0.5))
        let latest = controller.sample
        controller.consume(analysis(at: 1, x: 0.9))
        XCTAssertEqual(controller.sample.timestamp, latest.timestamp)
        XCTAssertEqual(controller.sample.pointNormalized, latest.pointNormalized)
    }

    func testEyeStripGeometryMatchesDocumentedFrameConvention() throws {
        let geometry = try XCTUnwrap(
            EyeStripInputGeometry.cropGeometry(
                leftEyePointsFaceNormBottomLeft: [
                    CGPoint(x: 0.20, y: 0.60),
                    CGPoint(x: 0.30, y: 0.60)
                ],
                rightEyePointsFaceNormBottomLeft: [
                    CGPoint(x: 0.70, y: 0.60),
                    CGPoint(x: 0.80, y: 0.60)
                ],
                faceRectVisionNorm: CGRect(x: 0.20, y: 0.30, width: 0.60, height: 0.50),
                imageWidth: 1_000,
                imageHeight: 500
            )
        )

        XCTAssertEqual(geometry.normalizedRectVision.midX, 0.50, accuracy: 0.000_001)
        XCTAssertEqual(geometry.normalizedRectVision.midY, 0.60, accuracy: 0.000_001)
        XCTAssertEqual(geometry.normalizedRectVision.width, 0.45, accuracy: 0.000_001)
        XCTAssertEqual(geometry.normalizedRectVision.height, 0.405, accuracy: 0.000_001)
        XCTAssertEqual(geometry.metadata[0], 0, accuracy: 0.000_001)
        XCTAssertEqual(geometry.metadata[1], -0.20, accuracy: 0.000_001)
        XCTAssertEqual(geometry.metadata[2], 0.45, accuracy: 0.000_001)
        XCTAssertEqual(geometry.metadata[3], 0.405, accuracy: 0.000_001)
    }

    func testPersonalizedCalibrationRecoversAffineMapping() throws {
        let targets = [
            (0.08, 0.08), (0.29, 0.08), (0.50, 0.08), (0.71, 0.08), (0.92, 0.08),
            (0.92, 0.50), (0.92, 0.92), (0.71, 0.92), (0.50, 0.92),
            (0.29, 0.92), (0.08, 0.92), (0.08, 0.50), (0.50, 0.50)
        ]
        let samples = targets.compactMap { x, y -> GazeCalibrationSample? in
            guard let target = NormalizedGazePoint(x: x, y: y) else { return nil }
            return GazeCalibrationSample(
                raw: GazeCoordinate(x: (x - 0.15) / 0.72, y: (y + 0.08) / 1.18),
                target: target
            )
        }
        let calibration = try PersonalizedGazeCalibration.fit(samples: samples)
        let prediction = calibration.predict(
            GazeCoordinate(x: (0.33 - 0.15) / 0.72, y: (0.77 + 0.08) / 1.18)
        )

        XCTAssertEqual(calibration.kind, .affine)
        XCTAssertEqual(prediction.x, 0.33, accuracy: 0.002)
        XCTAssertEqual(prediction.y, 0.77, accuracy: 0.002)
    }

    func testCursorSoftDeadZoneSuppressesSmallJitter() {
        var smoother = GazePointSmoother()
        let initial = smoother.consume(
            point: CGPoint(x: 0.50, y: 0.50),
            timestampNanoseconds: 1_000_000_000,
            isUsable: true
        )
        let jittered = smoother.consume(
            point: CGPoint(x: 0.505, y: 0.50),
            timestampNanoseconds: 1_016_666_667,
            isUsable: true
        )

        XCTAssertEqual(initial, CGPoint(x: 0.50, y: 0.50))
        XCTAssertEqual(jittered, initial)
    }

    func testBriefTrackingLossDoesNotResetCursorFilter() {
        var smoother = GazePointSmoother()
        _ = smoother.consume(
            point: CGPoint(x: 0.20, y: 0.20),
            timestampNanoseconds: 1_000_000_000,
            isUsable: true
        )
        XCTAssertNil(
            smoother.consume(
                point: nil,
                timestampNanoseconds: 1_016_666_667,
                isUsable: false
            )
        )

        let reacquired = CGPoint(x: 0.80, y: 0.75)
        let filtered = smoother.consume(
            point: reacquired,
            timestampNanoseconds: 1_033_333_334,
            isUsable: true
        )
        XCTAssertLessThan(filtered?.x ?? 1, reacquired.x)
    }
}
