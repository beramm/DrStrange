//
//  LobbyGameCharacter.swift
//  Characters the child can choose on the character select screen.
//

import Foundation

nonisolated struct GameCharacter: Identifiable, Hashable {
    let id: String
    /// Shown on the character card (in capitals) and read out by VoiceOver.
    let name: String
    /// Short line under the name on the character card.
    let tagline: String
    /// Asset-catalog image name.
    let imageName: String

    static let fox = GameCharacter(
        id: "fox",
        name: "Doomie",
        tagline: "“Small paws, big adventures\nthis little fox is ready to farm”",
        imageName: Buddy.imageName
    )

    /// Every character on the select screen, in order.
    /// Bunny and Bear are prototype characters (placeholder art and text)
    /// until the design team's characters arrive.
    static let all: [GameCharacter] = [
        fox,
        GameCharacter(
            id: "bunny",
            name: "Bunny",
            tagline: "“Hop, hop, hooray!\nthis bunny is ready to play”",
            imageName: "Bunny"
        ),
        GameCharacter(
            id: "bear",
            name: "Bear",
            tagline: "“Big hugs, bigger smiles\nthis bear is ready to help”",
            imageName: "Bear"
        ),
    ]

    /// Key used to save the chosen character on the device.
    static let storageKey = "selectedCharacterID"

    /// Finds a character by id. Falls back to the fox if the id is unknown.
    static func with(id: String) -> GameCharacter {
        all.first { $0.id == id } ?? fox
    }

    /// The character before / after this one in `all`, wrapping around at the ends.
    func neighbour(_ step: Int) -> GameCharacter {
        let list = Self.all
        let index = list.firstIndex(of: self) ?? 0
        return list[(index + step + list.count) % list.count]
    }
}
