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
        imageName: "CharacterFox"
    )

    static let bunny = GameCharacter(
        id: "bunny",
        name: "Bea",
        tagline: "“Floppy ears, happy cheers\nthis little bunny loves to hop”",
        imageName: "CharacterBunny"
    )

    static let raccoon = GameCharacter(
        id: "raccoon",
        name: "Coonie",
        tagline: "“Striped tail, never fail\nthis little raccoon finds every treat”",
        imageName: "CharacterRaccoon"
    )

    /// Every character on the select screen, in order.
    /// The taglines of Bea and Coonie are placeholders and can still change.
    static let all: [GameCharacter] = [fox, bunny, raccoon]

    /// Walking towards the player: four pictures, played again and again.
    var walkImageNames: [String] { (1...4).map { "\(imageName)Walk\($0)" } }
    /// Seen from the side, facing right (used while turning around).
    var sideImageName: String { "\(imageName)Side" }
    /// Seen from the back (used while turning around).
    var backImageName: String { "\(imageName)Back" }

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
