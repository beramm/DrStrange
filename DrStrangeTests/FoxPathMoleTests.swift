import UIKit
import XCTest
@testable import DrStrange

/// The followed character while the mole is about, and where the mole's hole opens.
final class FoxPathMoleTests: XCTestCase {
    private let feet = CGPoint(x: 600, y: 500)
    /// Walking right, down the map (towards the player) and up the map (away from the player).
    private let tangents = [CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: 1), CGVector(dx: 0, dy: -1)]

    // MARK: - The character stops where it is

    func testStoppedCharacterKeepsItsPlaceAndItsFacing() {
        for character in PathCharacter.allCases {
            for tangent in tangents {
                let walking = FoxWalkPose.onPath(character, state: .following, feet: feet, tangent: tangent, distance: 230)
                let stopped = FoxWalkPose.onPath(character, state: .offTrack, feet: feet, tangent: tangent, distance: 230)
                XCTAssertEqual(stopped.feet, walking.feet, "\(character) stays exactly where it stopped")
                XCTAssertEqual(stopped.facing, walking.facing, "\(character) does not turn round")
                XCTAssertEqual(stopped.isMirrored, walking.isMirrored)
                XCTAssertEqual(stopped.character, character)
                XCTAssertEqual(stopped.assetName, FoxWalkAnimation.restingAssetName(for: character, facing: walking.facing))
            }
        }
    }

    func testStoppedSideViewKeepsFacingTheWayItWalked() {
        let stopped = FoxWalkPose.onPath(.raccoon, state: .offTrack, feet: feet, tangent: CGVector(dx: 1, dy: 0), distance: 0)
        XCTAssertEqual(stopped.facing, .side, "not turned to face the player")
        XCTAssertFalse(stopped.isMirrored)
    }

    func testCharacterFacesThePlayerOnlyBeforeTheWalkAndAtTheStall() {
        for state in [FoxTrackingState.waiting, .finished] {
            let pose = FoxWalkPose.onPath(.bunny, state: state, feet: feet, tangent: CGVector(dx: 1, dy: 0), distance: 0)
            XCTAssertEqual(pose.facing, .front)
            XCTAssertEqual(pose.assetName, PathCharacter.bunny.standingAsset)
        }
    }

    func testStoppedWalkPicksUpWhereItStopped() {
        var engine = FoxPathEngine(settings: .standard, routeLength: 5000)
        let step = 1.0 / 60
        for _ in 0..<60 { _ = engine.advance(by: step, reading: .onFox) }
        for _ in 0..<120 { _ = engine.advance(by: step, reading: .onFox) }
        for _ in 0..<60 { _ = engine.advance(by: step, reading: .away) }
        XCTAssertEqual(engine.state, .offTrack)
        let stoppedAt = engine.distance
        for _ in 0..<180 { _ = engine.advance(by: step, reading: .away) }
        XCTAssertEqual(engine.distance, stoppedAt, "it does not move while the child looks away")
        for _ in 0..<60 { _ = engine.advance(by: step, reading: .onFox) }
        XCTAssertEqual(engine.state, .following)
        XCTAssertGreaterThan(engine.distance, stoppedAt)
        // One second back on the character: the refocus dwell, then walking from where it stopped.
        let walked = FoxPathSettings.standard.foxSpeed * (1 - FoxPathSettings.standard.refocusDwell)
        XCTAssertLessThanOrEqual(engine.distance, stoppedAt + walked + 1, "it carries on from there")
    }

    // MARK: - The hole under the basket

    func testHoleIsBehindTheCharacterInSideView() {
        for character in PathCharacter.allCases {
            let pose = FoxWalkPose.onPath(character, state: .offTrack, feet: feet, tangent: CGVector(dx: 1, dy: 0), distance: 0)
            let hole = pose.bagHolePoint
            let width = character.size(facing: .side).width
            XCTAssertLessThan(hole.x, feet.x, "\(character): the basket is on the back, behind the body")
            XCTAssertGreaterThan(hole.x, feet.x - width * 0.6, "\(character): right under the basket, not far behind")
            XCTAssertEqual(hole.y, feet.y, accuracy: 10, "on the ground beside the feet")
        }
    }

    func testHoleIsInFrontOfTheLegsInBackView() {
        let pose = FoxWalkPose.onPath(.fox, state: .offTrack, feet: feet, tangent: CGVector(dx: 0, dy: -1), distance: 0)
        XCTAssertEqual(pose.facing, .back)
        XCTAssertEqual(pose.bagHolePoint.x, feet.x, accuracy: 0.001, "under the basket, which faces the player")
        XCTAssertGreaterThan(pose.bagHolePoint.y, feet.y, "in front of the legs, so the mole is drawn in front")
    }

    func testHoleIsBesideTheCharacterInFrontView() {
        let pose = FoxWalkPose.onPath(.bunny, state: .offTrack, feet: feet, tangent: CGVector(dx: 0, dy: 1), distance: 0)
        XCTAssertEqual(pose.facing, .front)
        XCTAssertGreaterThan(pose.bagHolePoint.x, feet.x, "beside the body, where the mole can be seen")
        XCTAssertLessThan(pose.bagHolePoint.y, feet.y, "a little behind, on the basket's side")
    }

    // MARK: - Pictures

    func testMoleAndHolePicturesAreInTheAssetCatalog() {
        for name in ["FoxPath/Mole/Standing", "FoxPath/Mole/Carrot", "Holes/Hole1"] {
            XCTAssertNotNil(UIImage(named: name), name)
        }
    }

    func testBothMolePicturesAreTheSameSize() {
        let standing = MoleThiefVisual.standingSize
        let carrot = MoleThiefVisual.carrotSize
        XCTAssertEqual(standing.width, carrot.width, accuracy: 3, "the body stays the same size when it grabs the carrot")
        XCTAssertEqual(standing.height, carrot.height, accuracy: 3)
    }
}
