import UIKit
import XCTest
@testable import DrStrange

final class FixationFinishTests: XCTestCase {
    func testNextGameAfterVeggieKeeperIsWhackAMoleOrVeggieDashEquallyOften() {
        var generator = SeededGenerator(seed: 11)
        var counts: [MiniGame: Int] = [:]
        let draws = 10_000
        for _ in 0..<draws {
            counts[MiniGame.randomNext(after: .veggieKeeper, using: &generator), default: 0] += 1
        }
        XCTAssertNil(counts[.veggieKeeper], "Veggie Keeper is never picked again")
        for game in [MiniGame.whackAMole, .veggieDash] {
            let share = Double(counts[game] ?? 0) / Double(draws)
            XCTAssertEqual(share, 0.5, accuracy: 0.03, "\(game) share \(share)")
        }
    }

    func testTopBarAndFinishArtworkIsInTheAssetCatalog() {
        var names = ["VeggieKeeperPauseButton", "FinishScreen/Star", "FinishScreen/Ribbon",
                     "FinishScreen/ButtonRestart", "FinishScreen/ButtonNext", "FinishScreen/ButtonHome",
                     "SettingsCard", "LobbyRope"]
        names += (0...3).map { "VeggieKeeperCarrots\($0)" }
        for name in names {
            XCTAssertNotNil(UIImage(named: name), name)
        }
    }
}
