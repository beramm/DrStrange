//
//  Color+Palette.swift
//  Fixation game colors in one place.
//  Same values as `WhackAMolePalette` in the Whack-a-Mole game, so the games match.
//

import SwiftUI

extension Color {
    /// Light green background.
    static let meadow      = Color(red: 0.80, green: 0.91, blue: 0.70)
    /// Darker green (stall posts).
    static let meadowDeep  = Color(red: 0.62, green: 0.82, blue: 0.52)
    /// Dark brown shadow (top of the counter).
    static let holeShadow  = Color(red: 0.33, green: 0.22, blue: 0.16)
    /// Wood brown (the stall counter).
    static let rim         = Color(red: 0.52, green: 0.36, blue: 0.24)
    /// Text and icons.
    static let ink         = Color(red: 0.24, green: 0.16, blue: 0.12)
    /// Stars.
    static let star        = Color(red: 1.00, green: 0.78, blue: 0.20)
    /// Panels and banners.
    static let cream       = Color(red: 1.00, green: 0.97, blue: 0.90)
    /// Main buttons, countdown and the awning stripes.
    static let accent      = Color(red: 0.93, green: 0.56, blue: 0.18)
}
