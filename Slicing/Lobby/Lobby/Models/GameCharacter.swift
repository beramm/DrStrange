//
//  GameCharacter.swift
//  Characters the child can choose on the character select screen.
//

import Foundation

nonisolated struct GameCharacter: Identifiable, Hashable {
    let id: String
    /// Read out by VoiceOver.
    let name: String
    /// Asset-catalog image name.
    let imageName: String

    static let fox = GameCharacter(id: "fox", name: "Fox", imageName: Buddy.imageName)

    /// Every character on the select screen, in order.
    /// Bunny and Bear use placeholder drawings until the design team's art arrives.
    static let all: [GameCharacter] = [
        fox,
        GameCharacter(id: "bunny", name: "Bunny", imageName: "Bunny"),
        GameCharacter(id: "bear", name: "Bear", imageName: "Bear"),
    ]

    /// Key used to save the chosen character on the device.
    static let storageKey = "selectedCharacterID"

    /// Finds a character by id. Falls back to the fox if the id is unknown.
    static func with(id: String) -> GameCharacter {
        all.first { $0.id == id } ?? fox
    }
}
