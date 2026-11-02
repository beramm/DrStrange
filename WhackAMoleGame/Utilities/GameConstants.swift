import SwiftUI

/// Colours for the game. Characters are kept clearly darker or more saturated than the meadow
/// background so they stand out without high-contrast flashing.
enum WhackAMolePalette {
    static let meadow = Color(red: 0.80, green: 0.91, blue: 0.70)
    static let meadowDeep = Color(red: 0.62, green: 0.82, blue: 0.52)
    static let holeShadow = Color(red: 0.33, green: 0.22, blue: 0.16)
    static let rim = Color(red: 0.52, green: 0.36, blue: 0.24)
    static let ink = Color(red: 0.24, green: 0.16, blue: 0.12)
    static let star = Color(red: 1.0, green: 0.78, blue: 0.2)
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.9)
    static let accent = Color(red: 0.93, green: 0.56, blue: 0.18)
    static let windowInterior = Color(red: 0.98, green: 0.88, blue: 0.62)

    static func body(_ variant: CharacterVariant) -> Color {
        switch variant {
        case .sunny: Color(red: 0.98, green: 0.62, blue: 0.24)
        case .berry: Color(red: 0.84, green: 0.40, blue: 0.58)
        case .leafy: Color(red: 0.24, green: 0.56, blue: 0.40)
        case .sky: Color(red: 0.34, green: 0.58, blue: 0.88)
        }
    }
}
