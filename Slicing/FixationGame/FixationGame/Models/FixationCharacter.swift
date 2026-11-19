//
//  FixationCharacter.swift
//  The three characters. The one the player picks keeps the stall;
//  the thief is a mole (MoleThiefView).
//
//  The choice comes from onboarding ("Choose your character") and is passed in
//  through GameStartView.
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

    /// The asset names start with the character's name: "FoxKeeperAwake"…
    private var prefix: String { name }

    // MARK: Keeping the stall

    var keeperAwakeImage: String { "\(prefix)KeeperAwake" }
    var keeperSleepImages: [String] { (1...3).map { "\(prefix)KeeperSleep\($0)" } }

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
}
