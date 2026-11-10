//
//  Font+App.swift
//  App fonts in one place.
//  The names here are the fonts' internal names, not their file names.
//  If a font file is missing, iOS quietly falls back to the system font.
//

import SwiftUI

extension Font {
    /// Doodle Chalk: buttons and screen titles (file: Fonts/Doodlechalk.ttf).
    static func doodle(_ size: CGFloat) -> Font {
        .custom("DoodleChalkDemoRegular", size: size)
    }

    /// Days One: character name on the character card.
    static func daysOne(_ size: CGFloat) -> Font {
        .custom("DaysOne-Regular", size: size)
    }

    /// Belanosima: character tagline on the character card.
    static func belanosima(_ size: CGFloat) -> Font {
        .custom("Belanosima-Regular", size: size)
    }
}
