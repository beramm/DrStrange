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
}
