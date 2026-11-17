//
//  FixationCharacter.swift
//  The three characters. The one the player picks keeps the stall;
//  the other two are the thieves.
//
//  For now the player picks on the start screen (for testing). Later the choice
//  will come from onboarding ("Choose your character").
//

import CoreGraphics

nonisolated enum FixationCharacter: String, CaseIterable, Identifiable {
    case fox, bunny, raccoon

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fox: "Fox"
        case .bunny: "Bunny"
        case .raccoon: "Raccoon"
        }
    }

    /// The asset names start with the character's name: "FoxKeeperAwake", "BunnyThief1"…
    private var prefix: String { name }

    // MARK: Keeping the stall

    var keeperAwakeImage: String { "\(prefix)KeeperAwake" }
    var keeperSleepImages: [String] { (1...3).map { "\(prefix)KeeperSleep\($0)" } }

    // MARK: Stealing

    /// Walking up to the stall, seen from the back.
    var thiefWalkImages: [String] { (1...4).map { "\(prefix)Thief\($0)" } }
    /// Running away, seen from the front.
    var thiefRunImages: [String] { (1...4).map { "\(prefix)ThiefRun\($0)" } }

    /// The other two characters, who come to steal.
    var thieves: [FixationCharacter] { Self.allCases.filter { $0 != self } }

    // MARK: Sizes

    /// How tall the pictures are drawn, as a fraction of the stage height (before
    /// the stall is scaled). The pictures are cropped a little differently for each
    /// character, so these keep all three at the same size as each other.
    var keeperHeight: CGFloat {
        switch self {
        case .fox: 0.28
        case .bunny: 0.293
        case .raccoon: 0.302
        }
    }

    var thiefHeight: CGFloat {
        switch self {
        case .fox: 0.30
        case .bunny: 0.32
        case .raccoon: 0.332
        }
    }
}
