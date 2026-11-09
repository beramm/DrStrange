import XCTest
@_spi(Platform) @testable import DrStrangeGazeTracker

final class EyeAvailabilityClassifierTests: XCTestCase {
    func testClassifiesAnatomicalEyesFromMirroredBlinkCoefficients() {
        XCTAssertEqual(EyeAvailabilityClassifier.classify(eyeBlinkLeft: 0, eyeBlinkRight: 0), .both)
        XCTAssertEqual(EyeAvailabilityClassifier.classify(eyeBlinkLeft: 0, eyeBlinkRight: 1), .rightOnly)
        XCTAssertEqual(EyeAvailabilityClassifier.classify(eyeBlinkLeft: 1, eyeBlinkRight: 0), .leftOnly)
        XCTAssertEqual(EyeAvailabilityClassifier.classify(eyeBlinkLeft: 1, eyeBlinkRight: 1), .none)
    }

    func testRejectsNonFiniteCoefficientsAsClosed() {
        XCTAssertEqual(EyeAvailabilityClassifier.classify(eyeBlinkLeft: .nan, eyeBlinkRight: 0), .leftOnly)
        XCTAssertEqual(EyeAvailabilityClassifier.classify(eyeBlinkLeft: 0, eyeBlinkRight: .infinity), .rightOnly)
    }
}
