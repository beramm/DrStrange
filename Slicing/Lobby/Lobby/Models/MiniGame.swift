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

    /// The finished game card from the design (cover picture, title and tagline
    /// are all drawn in the picture).
    var cardImageName: String {
        switch self {
        case .veggieDash:   "GameCardVeggieDash"
        case .whackAMole:   "GameCardWhackAMole"
        case .veggieKeeper: "GameCardVeggieKeeper"
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
    /// Caregiver setting that controls whether the game map spins and chooses automatically.
    static let randomSpinEnabledStorageKey = "randomGameSpinEnabled"

    /// Is this game locked? With the "Lock games" testing setting on,
    /// only Whack a Mole stays open.
    func isLocked(whenGamesLocked gamesLocked: Bool) -> Bool {
        gamesLocked && self != .whackAMole
    }

    /// Picks a random open game, skipping `lastGame` when another open game is left.
    static func randomPick(avoiding lastGame: MiniGame?, gamesLocked: Bool) -> MiniGame {
        let open = allCases.filter { !$0.isLocked(whenGamesLocked: gamesLocked) }
        let choices = open.filter { $0 != lastGame }
        return (choices.isEmpty ? open : choices).randomElement() ?? .whackAMole
    }
}
