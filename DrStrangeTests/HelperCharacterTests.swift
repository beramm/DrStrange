import XCTest
import UIKit
@testable import DrStrange

final class HelperCharacterTests: XCTestCase {
    private func makeEngine(seed: UInt64) -> WhackAMoleEngine {
        var configuration = GameConfiguration()
        configuration.randomSeed = seed
        configuration.board = .testSingleRow
        return WhackAMoleEngine(configuration: configuration)
    }

    private func advanceToSpawn(_ engine: inout WhackAMoleEngine) -> ActiveTarget? {
        for _ in 0..<2000 {
            for event in engine.advance(by: 0.02) {
                if case let .spawned(target) = event { return target }
            }
        }
        return nil
    }

    func testFoxAndRaccoonAreInThePool() {
        XCTAssertEqual(HelperCharacter.allCases, [.fox, .raccoon])
    }

    func testEveryHelperFrameIsInTheAssetCatalog() {
        for helper in HelperCharacter.allCases {
            for frame in 1...helper.frameCount {
                let name = FoxCharacterView.assetName(frame, helper: helper)
                XCTAssertNotNil(UIImage(named: name), "missing \(name)")
            }
        }
        XCTAssertEqual(FoxCharacterView.assetName(1), "FoxHammer/Frame01", "the fox's frames are unchanged")
        XCTAssertEqual(FoxCharacterView.assetName(99, helper: .raccoon), "RaccoonHammer/Frame24")
    }

    func testEveryHelperIsEquallyLikely() {
        var generator = SeededGenerator(seed: 99)
        let draws = 20_000
        var counts: [HelperCharacter: Int] = [:]
        for _ in 0..<draws {
            counts[HelperCharacter.random(using: &generator), default: 0] += 1
        }
        let expected = Double(draws) / Double(HelperCharacter.allCases.count)
        for helper in HelperCharacter.allCases {
            XCTAssertEqual(Double(counts[helper] ?? 0), expected, accuracy: expected * 0.05, "\(helper)")
        }
    }

    func testSameHelperCanComeInConsecutiveGames() {
        let helpers = (UInt64(1)...50).map { makeEngine(seed: $0).helper }
        XCTAssertTrue(zip(helpers, helpers.dropFirst()).contains { $0 == $1 }, "games draw on their own, not in turns")
        XCTAssertEqual(Set(helpers), Set(HelperCharacter.allCases), "every helper turns up across games")
    }

    func testOneHelperForTheWholeGame() throws {
        for seed: UInt64 in 1...10 {
            var engine = makeEngine(seed: seed)
            let helper = engine.helper
            for _ in 0..<4 {
                let target = try XCTUnwrap(advanceToSpawn(&engine))
                engine.advance(by: 0.7)
                engine.tapHole(target.holeIndex)
                XCTAssertEqual(engine.attack?.helper, helper, "every attack in a game uses the game's helper")
                while engine.attack != nil { engine.advance(by: 0.05) }
                XCTAssertEqual(engine.helper, helper)
            }
        }
    }

    func testHelperChoiceDoesNotChangeTheGame() throws {
        // Same seed, same spawns and timing as before: only the artwork differs between helpers.
        var first = makeEngine(seed: 5)
        var second = makeEngine(seed: 5)
        let a = try XCTUnwrap(advanceToSpawn(&first))
        let b = try XCTUnwrap(advanceToSpawn(&second))
        XCTAssertEqual(a, b)
        XCTAssertEqual(first.helper, second.helper, "the same seed gives the same helper")
    }

    func testRaccoonUsesTheSameSwingOverItsOwnFrames() {
        func frame(_ phase: FoxAttackPhase, _ progress: Double) -> Int {
            FoxCharacterView.frame(for: FoxPose(phase: phase, progress: progress, holeIndex: 0, helper: .raccoon))
        }
        XCTAssertEqual(frame(.frameAppearing, 0.5), 1)
        XCTAssertEqual(frame(.foxEmerging, 0.5), 1)
        XCTAssertEqual(frame(.attacking, 1), HelperCharacter.raccoon.frameCount)
        XCTAssertEqual(frame(.hitting, 0.3), HelperCharacter.raccoon.frameCount)
        XCTAssertEqual(frame(.foxRetracting, 0.5), 1)
        XCTAssertEqual(frame(.frameDisappearing, 0.5), 1)
    }

    func testEveryHelperLandsItsHammerOnTheCharacter() {
        let home = CGRect(x: 16, y: 690, width: 130, height: 130)
        let hole = CGRect(x: 500, y: 300, width: 240, height: 240)
        let character = MoleHoleView.characterRect(artIndex: 0, in: hole.size).offsetBy(dx: hole.minX, dy: hole.minY)
        for helper in HelperCharacter.allCases {
            for holeIndex in [3, 5] {
                let pose = FoxPose(phase: .hitting, progress: 0, holeIndex: holeIndex, helper: helper)
                let fox = AttackAnimationView.scene(for: pose, home: home, hole: hole, reduceMotion: false).fox
                let impactX = fox.mirrored ? 1 - helper.impactPoint.x : helper.impactPoint.x
                let hammer = CGPoint(
                    x: fox.center.x + (impactX - 0.5) * fox.size,
                    y: fox.center.y + (helper.impactPoint.y - 0.5) * fox.size
                )
                XCTAssertTrue(character.contains(hammer), "\(helper): hammer \(hammer) should be on \(character)")
                // Same placement and timing for every helper: only where the hammer head sits differs.
                let foxPose = FoxPose(phase: .hitting, progress: 0, holeIndex: holeIndex)
                let foxScene = AttackAnimationView.scene(for: foxPose, home: home, hole: hole, reduceMotion: false).fox
                XCTAssertEqual(fox.size, foxScene.size, accuracy: 0.001)
                XCTAssertEqual(fox.mirrored, foxScene.mirrored)
            }
        }
    }
}
