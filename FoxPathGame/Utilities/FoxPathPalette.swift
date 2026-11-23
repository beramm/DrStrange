import SwiftUI

/// Colours for Follow the Fox.
enum FoxPathPalette {
    /// Flat green of the provided grass tiles, so the map has no visible edge.
    static let grass = Color(red: 92 / 255, green: 179 / 255, blue: 0)
    static let ink = WhackAMolePalette.ink
    static let cream = WhackAMolePalette.cream
    static let accent = WhackAMolePalette.accent
    static let star = WhackAMolePalette.star
    /// Warm warning colour for the off-track cue. Shown as a slow fade, never as a flash.
    static let danger = Color(red: 0.86, green: 0.2, blue: 0.1)
    static let guide = Color(red: 1.0, green: 0.86, blue: 0.3)
    /// Sky blue shown in place of the warning colour as soon as the eyes are back on the
    /// character. Blue rather than green so it stands out on the grass.
    static let lookingBack = Color(red: 59 / 255, green: 167 / 255, blue: 240 / 255)
    /// Hearts in the top bar.
    static let heart = Color(red: 0.9, green: 0.27, blue: 0.36)
}
