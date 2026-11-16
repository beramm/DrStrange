//
//  Font+App.swift
//  App fonts in one place.
//  The names here are the fonts' internal names, not their file names.
//  If a font file is missing, iOS quietly falls back to the system font.
//

import SwiftUI

extension Font {
    /// Doodle Chalk: buttons and screen titles (file: Fonts/Doodlechalk.ttf).
    /// Use `.doodleText(size:)` on text instead, so it also gets its letter spacing.
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

extension View {
    /// Doodle Chalk with extra space between the letters. Without it the letters
    /// sit too close together. The design asks for tracking 25 (25/1000 of the
    /// font size, which is 4 px on 160 px text), so the space grows with the text.
    func doodleText(size: CGFloat) -> some View {
        font(.doodle(size))
            .tracking(size * 0.025)
    }
}
