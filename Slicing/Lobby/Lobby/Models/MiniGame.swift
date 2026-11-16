//
//  MiniGame.swift
//  The three therapy mini-games the randomizer picks from.
//

import Foundation

nonisolated enum MiniGame: String, CaseIterable, Hashable {
    // Listed in the order the cards appear on the Game Map (left, middle, right).
    case veggieDash      // smooth pursuit
    case whackAMole      // saccade
    case veggieKeeper    // fixation

    /// Shown on the game card (in capitals) and on the game page.
    var title: String {
        switch self {
        case .veggieDash:   "Veggie Dash"
        case .whackAMole:   "Whack a Mole"
        case .veggieKeeper: "Veggie Keeper"
        }
    }

    /// The title split over two lines, as on the game card.
    var cardTitle: String {
        switch self {
        case .veggieDash:   "Veggie\nDash"
        case .whackAMole:   "Whack\na Mole"
        case .veggieKeeper: "Veggie\nKeeper"
        }
    }

    /// Short line under the title on the game card.
    var tagline: String {
        switch self {
        case .veggieDash:
            "“Eyes on the move! Follow your little courier and make sure every veggie arrives safely!”"
        case .whackAMole:
            "“Pop goes the mole!\nStay quick, gaze, and catch every cheeky little troublemaker!”"
        case .veggieKeeper:
            "“Keep your eyes on the stall\nThose sneaky thieves are after your veggies!”"
        }
    }

    /// Key used to remember the last game played, so the same one isn't picked twice in a row.
    static let lastGameStorageKey = "lastMiniGame"

    /// Picks a random game, skipping `lastGame` if there is one.
    static func randomPick(avoiding lastGame: MiniGame?) -> MiniGame {
        let choices = allCases.filter { $0 != lastGame }
        return choices.randomElement() ?? .whackAMole
    }
}
