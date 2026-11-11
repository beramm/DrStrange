import CoreGraphics
import XCTest
@testable import DrStrangeGazeTrackerPlatform

final class BlazeGazePreprocessingTests: XCTestCase {
    func testHomographyMapsAllFourCorners() throws {
        let source = [
            CGPoint(x: 20, y: 30),
            CGPoint(x: 15, y: 180),
            CGPoint(x: 250, y: 170),
            CGPoint(x: 240, y: 20)
        ]
        let destination = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 512),
            CGPoint(x: 512, y: 512),
            CGPoint(x: 512, y: 0)
        ]
        let matrix = try XCTUnwrap(
            BlazeGazeEyePatchExtractor.homography(source: source, destination: destination)
        )
        for index in source.indices {
            let point = apply(matrix, to: source[index])
            XCTAssertEqual(point.x, destination[index].x, accuracy: 0.001)
            XCTAssertEqual(point.y, destination[index].y, accuracy: 0.001)
        }
    }

    func testRBFCorrectionLearnsCalibrationPoints() {
        let pairs = [
            BlazeGazeCalibrationPair(
                observed: CGPoint(x: 0.25, y: 0.20),
                target: CGPoint(x: 0.15, y: 0.15)
            ),
            BlazeGazeCalibrationPair(
                observed: CGPoint(x: 0.70, y: 0.25),
                target: CGPoint(x: 0.85, y: 0.15)
            ),
            BlazeGazeCalibrationPair(
                observed: CGPoint(x: 0.50, y: 0.75),
                target: CGPoint(x: 0.50, y: 0.85)
            )
        ]
        var correction = BlazeGazeRBFCorrection()
        XCTAssertTrue(correction.fit(pairs))
        for pair in pairs {
            let corrected = correction.correct(pair.observed)
            XCTAssertEqual(corrected.x, pair.target.x, accuracy: 0.02)
            XCTAssertEqual(corrected.y, pair.target.y, accuracy: 0.02)
        }
    }

    private func apply(_ matrix: [Double], to point: CGPoint) -> CGPoint {
        let x = Double(point.x)
        let y = Double(point.y)
        let divisor = matrix[6] * x + matrix[7] * y + matrix[8]
        return CGPoint(
            x: (matrix[0] * x + matrix[1] * y + matrix[2]) / divisor,
            y: (matrix[3] * x + matrix[4] * y + matrix[5]) / divisor
        )
    }
}
