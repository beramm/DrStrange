import XCTest
@_spi(Platform) @testable import DrStrangeGazeTracker
@testable import DrStrangeGazeTrackerPlatform
import simd

final class FaceSetupMonitorTests: XCTestCase {
    func testDistanceAndFaceAngleProduceSpecificGuidanceStates() {
        var monitor = FaceSetupMonitor()

        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 0,
                faceTranslation: SIMD3(0, 0, -0.30),
                headDirection: SIMD3(0, 0, 1)
            ),
            .tooClose
        )
        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 1,
                faceTranslation: SIMD3(0, 0, -0.51),
                headDirection: SIMD3(0, 0, 1)
            ),
            .tooFar
        )

        let thirtyDegrees = 30.0 * .pi / 180
        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 2,
                faceTranslation: SIMD3(0, 0, -0.50),
                headDirection: SIMD3(0, sin(thirtyDegrees), cos(thirtyDegrees))
            ),
            .lookDown
        )
        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 3,
                faceTranslation: SIMD3(0, 0, -0.50),
                headDirection: SIMD3(0, -sin(thirtyDegrees), cos(thirtyDegrees))
            ),
            .lookUp
        )
        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 4,
                faceTranslation: SIMD3(0, 0, -0.50),
                headDirection: SIMD3(sin(thirtyDegrees), 0, cos(thirtyDegrees))
            ),
            .turnLeft
        )
        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 5,
                faceTranslation: SIMD3(0, 0, -0.50),
                headDirection: SIMD3(-sin(thirtyDegrees), 0, cos(thirtyDegrees))
            ),
            .turnRight
        )
    }

    func testPostureMustRemainStableBeforeBecomingReady() {
        var monitor = FaceSetupMonitor()
        let translation = SIMD3<Double>(0, 0, -0.45)
        let direction = SIMD3<Double>(0, 0, 1)

        XCTAssertEqual(
            monitor.evaluate(timestamp: 10, faceTranslation: translation, headDirection: direction),
            .stabilizing
        )
        XCTAssertEqual(
            monitor.evaluate(timestamp: 10.34, faceTranslation: translation, headDirection: direction),
            .stabilizing
        )
        XCTAssertEqual(
            monitor.evaluate(timestamp: 10.36, faceTranslation: translation, headDirection: direction),
            .ready
        )
    }

    func testAlignmentUsesTheActualFaceToCameraDirection() {
        var monitor = FaceSetupMonitor()
        let translation = SIMD3<Double>(0, -0.20, -0.43)
        let towardCamera = simd_normalize(-translation)

        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 30,
                faceTranslation: translation,
                headDirection: towardCamera
            ),
            .stabilizing
        )
        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 30.36,
                faceTranslation: translation,
                headDirection: towardCamera
            ),
            .ready
        )
    }

    func testReversedARKitAxisStillRecognizesAForwardFacingPose() {
        var monitor = FaceSetupMonitor()
        let translation = SIMD3<Double>(0, 0, -0.50)

        _ = monitor.evaluate(
            timestamp: 40,
            faceTranslation: translation,
            headDirection: SIMD3(0, 0, -1)
        )
        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 40.36,
                faceTranslation: translation,
                headDirection: SIMD3(0, 0, -1)
            ),
            .ready
        )
    }

    func testMovementPausesReadinessUntilPostureRecovers() {
        var monitor = FaceSetupMonitor()
        let direction = SIMD3<Double>(0, 0, 1)

        _ = monitor.evaluate(
            timestamp: 20,
            faceTranslation: SIMD3(0, 0, -0.45),
            headDirection: direction
        )
        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 20.35,
                faceTranslation: SIMD3(0, 0, -0.45),
                headDirection: direction
            ),
            .ready
        )
        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 20.45,
                faceTranslation: SIMD3(0.04, 0, -0.45),
                headDirection: direction
            ),
            .stabilizing
        )
        XCTAssertEqual(
            monitor.evaluate(
                timestamp: 20.80,
                faceTranslation: SIMD3(0.04, 0, -0.45),
                headDirection: direction
            ),
            .ready
        )
    }
}
