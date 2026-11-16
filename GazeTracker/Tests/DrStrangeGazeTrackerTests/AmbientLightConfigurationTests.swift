import XCTest
@_spi(Engineering) @testable import DrStrangeGazeTrackerPlatform

final class AmbientLightConfigurationTests: XCTestCase {
    func testLightingStateUsesHysteresisAroundTheDarkThreshold() {
        let lighting = GazeAmbientLightConfiguration()

        XCTAssertEqual(lighting.state(), .unknown)

        lighting.record(ambientIntensity: 200)
        XCTAssertEqual(lighting.state(), .tooDark)

        lighting.record(ambientIntensity: 300)
        XCTAssertEqual(lighting.state(), .tooDark)

        lighting.record(ambientIntensity: 450)
        XCTAssertEqual(lighting.state(), .adequate)

        lighting.record(ambientIntensity: 300)
        XCTAssertEqual(lighting.state(), .adequate)

        lighting.reset()
        XCTAssertEqual(lighting.state(), .unknown)
    }
}
