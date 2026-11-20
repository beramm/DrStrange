import XCTest
@testable import DrStrange

final class WhackAMoleFinishTests: XCTestCase {
    func testNextGameAfterWhackAMoleIsSmoothPursuitOrFixationEquallyOften() {
        var generator = SeededGenerator(seed: 2026)
        var counts: [MiniGame: Int] = [:]
        let draws = 10_000
        for _ in 0..<draws {
            counts[MiniGame.randomNext(after: .whackAMole, using: &generator), default: 0] += 1
        }
        XCTAssertNil(counts[.whackAMole], "Whack a Mole is never picked again")
        XCTAssertEqual(Set(counts.keys), [.veggieDash, .veggieKeeper])
        for game in [MiniGame.veggieDash, .veggieKeeper] {
            let share = Double(counts[game] ?? 0) / Double(draws)
            XCTAssertEqual(share, 0.5, accuracy: 0.03, "\(game) share \(share)")
        }
    }

    /// 100, then 80, then 120, with a new store standing in for reopening the app.
    func testHighScoreSurvivesLowerScoresAndReopening() throws {
        let suite = "WhackAMoleFinishTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = HighScoreStore(defaults: defaults)
        XCTAssertTrue(store.submit(100), "first game sets the high score")
        XCTAssertEqual(store.best, 100)
        XCTAssertFalse(store.submit(80))
        XCTAssertEqual(store.best, 100)
        XCTAssertTrue(store.submit(120))
        XCTAssertEqual(store.best, 120)

        let reopened = HighScoreStore(defaults: defaults)
        XCTAssertEqual(reopened.best, 120)
    }

    func testFinishScreenShowsTheBestScoreIncludingThisGame() {
        XCTAssertEqual(GameResultView.highScore(previous: 0, score: 100), 100)
        XCTAssertEqual(GameResultView.highScore(previous: 100, score: 80), 100)
        XCTAssertEqual(GameResultView.highScore(previous: 100, score: 120), 120)
    }

    func testFinishScreenArtworkIsInTheAssetCatalog() {
        for name in ["FinishScreen/Star", "FinishScreen/Ribbon", "FinishScreen/ButtonRestart",
                     "FinishScreen/ButtonNext", "FinishScreen/ButtonHome", "SettingsCard"] {
            XCTAssertNotNil(UIImage(named: name), name)
        }
    }
}
