import UIKit
import XCTest
@testable import DrStrange

final class FoxPathFinishTests: XCTestCase {
    func testNextGameAfterVeggieDashIsWhackAMoleOrVeggieKeeperEquallyOften() {
        var generator = SeededGenerator(seed: 7)
        var counts: [MiniGame: Int] = [:]
        let draws = 10_000
        for _ in 0..<draws {
            counts[MiniGame.randomNext(after: .veggieDash, using: &generator), default: 0] += 1
        }
        XCTAssertNil(counts[.veggieDash], "Veggie Dash is never picked again")
        for game in [MiniGame.whackAMole, .veggieKeeper] {
            let share = Double(counts[game] ?? 0) / Double(draws)
            XCTAssertEqual(share, 0.5, accuracy: 0.03, "\(game) share \(share)")
        }
    }

    func testFinishAndPauseArtworkIsInTheAssetCatalog() {
        let names = ["FinishScreen/Ribbon", "FoxPath/GameOver/Ribbon", "FinishScreen/ButtonRestart",
                     "FinishScreen/ButtonNext", "FinishScreen/ButtonHome", "FinishScreen/ButtonPlay",
                     "FinishScreen/ButtonClose", "SettingsCard", "LobbyRope"]
        for name in names {
            XCTAssertNotNil(UIImage(named: name), name)
        }
    }
}
