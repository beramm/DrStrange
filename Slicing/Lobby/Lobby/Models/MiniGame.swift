//
//  MiniGame.swift
//  The three therapy mini-games the randomizer picks from.
//

import Foundation

nonisolated enum MiniGame: String, CaseIterable, Hashable {
    case whackAMole      // saccade
    case fixation        // fixation
    case followTheFox    // smooth pursuit

    var title: String {
        switch self {
        case .whackAMole:   "Whack a Mole"
        case .fixation:     "Fixation"
        case .followTheFox: "Follow the Fox"
        }
    }

    /// SF Symbol shown on the game's card.
    var systemImage: String {
        switch self {
        case .whackAMole:   "hammer.fill"
        case .fixation:     "eye.fill"
        case .followTheFox: "point.topleft.down.to.point.bottomright.curvepath"
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
