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

    func testCarrotsShownStayWithinThePaintedStates() {
        for lives in 0...FoxPathConfiguration.initialLives {
            XCTAssertEqual(FoxPathResultView.clampedLives(lives), lives)
        }
        XCTAssertEqual(FoxPathResultView.clampedLives(-1), 0)
        XCTAssertEqual(FoxPathResultView.clampedLives(5), FoxPathConfiguration.initialLives)
    }

    func testFinishAndPauseArtworkIsInTheAssetCatalog() {
        var names = ["FinishScreen/Star", "FinishScreen/Ribbon", "FinishScreen/ButtonRestart",
                     "FinishScreen/ButtonNext", "FinishScreen/ButtonHome", "FinishScreen/ButtonPlay",
                     "FinishScreen/ButtonClose", "SettingsCard", "LobbyRope"]
        // Every number of carrots the finish screen can show.
        names += (0...FoxPathConfiguration.initialLives).map { "FoxPath/Carrots\($0)" }
        for name in names {
            XCTAssertNotNil(UIImage(named: name), name)
        }
    }
}
