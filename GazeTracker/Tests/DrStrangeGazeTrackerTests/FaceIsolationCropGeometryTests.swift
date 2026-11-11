import CoreGraphics
import ImageIO
import XCTest
@testable import DrStrangeGazeTrackerPlatform

final class FaceIsolationCropGeometryTests: XCTestCase {
    func testDisplayOrientationsRotateWithoutApplyingASecondMirror() {
        XCTAssertEqual(
            FaceIsolationDisplayOrientation.landscapeLeft.imagePropertyOrientation,
            .down
        )
        XCTAssertEqual(
            FaceIsolationDisplayOrientation.landscapeRight.imagePropertyOrientation,
            .up
        )
        XCTAssertEqual(
            FaceIsolationDisplayOrientation.portrait.imagePropertyOrientation,
            .left
        )
        XCTAssertEqual(
            FaceIsolationDisplayOrientation.portraitUpsideDown.imagePropertyOrientation,
            .right
        )
    }

    func testCropIsSquareAndPaddedAroundFace() throws {
        let crop = try XCTUnwrap(FaceIsolationCropGeometry.squareCrop(
            around: CGRect(x: 400, y: 250, width: 200, height: 300),
            inside: CGRect(x: 0, y: 0, width: 1_280, height: 720)
        ))

        XCTAssertEqual(crop.width, crop.height)
        XCTAssertEqual(crop.width, 405, accuracy: 1)
        XCTAssertTrue(crop.contains(CGPoint(x: 400, y: 250)))
        XCTAssertTrue(crop.contains(CGPoint(x: 600, y: 550)))
    }

    func testCropShiftsInsideImageWithoutLosingSquareShape() throws {
        let extent = CGRect(x: 0, y: 0, width: 1_280, height: 720)
        let crop = try XCTUnwrap(FaceIsolationCropGeometry.squareCrop(
            around: CGRect(x: 1_180, y: 600, width: 90, height: 110),
            inside: extent
        ))

        XCTAssertEqual(crop.width, crop.height)
        XCTAssertLessThanOrEqual(crop.maxX, extent.maxX)
        XCTAssertLessThanOrEqual(crop.maxY, extent.maxY)
        XCTAssertGreaterThanOrEqual(crop.minX, extent.minX)
        XCTAssertGreaterThanOrEqual(crop.minY, extent.minY)
    }

    func testFractionalFaceBoundsStillProduceAnExactSquare() throws {
        let crop = try XCTUnwrap(FaceIsolationCropGeometry.squareCrop(
            around: CGRect(x: 401.2, y: 253.7, width: 199.4, height: 301.1),
            inside: CGRect(x: 0, y: 0, width: 1_280, height: 720)
        ))

        XCTAssertEqual(crop.width, crop.height)
        XCTAssertEqual(crop.width.rounded(.up), crop.width)
    }

    func testCropRejectsEmptyInput() {
        XCTAssertNil(FaceIsolationCropGeometry.squareCrop(
            around: .zero,
            inside: CGRect(x: 0, y: 0, width: 1_280, height: 720)
        ))
    }
}
