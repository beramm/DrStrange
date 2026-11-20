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

    // MARK: Pop-ups (Setting, pause)

    /// Faded brown layer behind a pop-up card.
    static let popupShade   = Color(red: 0.36, green: 0.22, blue: 0.12).opacity(0.55)
    /// Chosen option on the Setting card, and the outline / text of the options.
    static let pillYellow   = Color(red: 0.96, green: 0.83, blue: 0.49)
    static let pillOutline  = Color(red: 0.20, green: 0.11, blue: 0.03)

    // MARK: Game Map (randomizer)

}
