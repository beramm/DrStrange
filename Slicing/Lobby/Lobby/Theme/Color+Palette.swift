//
//  Color+Palette.swift
//  App colors in one place.
//

import SwiftUI

extension Color {
    /// Dark brown text (character and game names, taglines).
    static let ink        = Color(red: 0.24, green: 0.16, blue: 0.12)

    // MARK: Lobby (from the final lobby design)

    /// Light blue sky behind the lobby.
    static let sky          = Color(red: 0.90, green: 0.96, blue: 0.99)
    /// Wooden sign buttons, their ropes and their text.
    static let signBoard    = Color(red: 0.59, green: 0.38, blue: 0.25)
    static let signRope     = Color(red: 0.48, green: 0.31, blue: 0.17)
    static let signText     = Color(red: 0.98, green: 0.91, blue: 0.89)

    // MARK: Character select (from the final design)

    /// "CHOOSE YOUR CHARACTER" title.
    static let titleBrown     = Color(red: 0.55, green: 0.35, blue: 0.23)
    /// Round back and settings buttons.
    static let roundButton    = Color(red: 0.79, green: 0.38, blue: 0.25)
    /// Square previous / next arrows.
    static let arrowYellow    = Color(red: 1.00, green: 0.84, blue: 0.43)
    /// Circle behind the character on the card.
    static let portraitBlue   = Color(red: 0.55, green: 0.76, blue: 0.94)

    // MARK: Game Map (randomizer)

    /// Stand-in for a game's cover picture until the real covers are ready.
    static let coverPlaceholder = Color(red: 0.64, green: 0.78, blue: 0.88)
}
