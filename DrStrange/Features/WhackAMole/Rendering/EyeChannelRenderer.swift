import SwiftUI

/// Which eyes a drawn element is meant for.
enum EyeTarget: Equatable {
    case both
    case only(Eye)
}

/// Turns "this element is for the left eye at 60 % contrast" into something drawable.
///
/// Implementations exist for the standard screen (no separation) and red/cyan anaglyph glasses.
/// A future validated dichoptic display (for example a stereo headset or a polarised screen)
/// would add a renderer here, plus a `ViewingMode` case, without touching game logic.
protocol EyeChannelRenderer {
    var isDichoptic: Bool { get }
    var background: Color { get }
    /// Colour for an element. `standardColor` is used when the screen does not separate the eyes.
    func ink(for target: EyeTarget, standardColor: Color, contrast: Double) -> Color
}

struct StandardRenderer: EyeChannelRenderer {
    var isDichoptic: Bool { false }
    var background: Color { WhackAMolePalette.meadow }

    func ink(for target: EyeTarget, standardColor: Color, contrast: Double) -> Color {
        standardColor
    }
}

/// Red/cyan anaglyph.
///
/// Physics: a red filter passes red light, so red ink on a light background looks the same as the
/// background to that eye (invisible) and dark to the eye behind the cyan filter. Cyan ink is the
/// reverse. Elements for one eye are therefore drawn in the ink the *other* filter blocks.
///
/// Inks are multiplicative factors (drawn with `.multiply` blending), so where a left-eye element
/// overlaps a right-eye element both eyes still see their own part.
///
/// Limitations: separation depends on the screen's colour primaries and the filters actually
/// used. Some crosstalk (ghosting) is expected and has to be measured per device/glasses pair.
struct AnaglyphRenderer: EyeChannelRenderer {
    let glasses: AnaglyphGlasses
    let backgroundLevel: Double

    var isDichoptic: Bool { true }
    var background: Color { Color(white: backgroundLevel) }

    func ink(for target: EyeTarget, standardColor: Color, contrast: Double) -> Color {
        let c = min(max(contrast, 0), 1)
        switch target {
        case .both:
            return Color(white: 1 - c)
        case let .only(eye) where eye == glasses.redFilterEye:
            // Cyan ink: no red light, so only the red-filtered eye sees it as dark.
            return Color(red: 1 - c, green: 1, blue: 1)
        case .only:
            // Red ink: only the cyan-filtered eye sees it as dark.
            return Color(red: 1, green: 1 - c, blue: 1 - c)
        }
    }
}

enum EyeChannelRendererFactory {
    static func make(for therapy: TherapyConfiguration) -> any EyeChannelRenderer {
        switch therapy.viewingMode {
        case .standard: StandardRenderer()
        case .anaglyph: AnaglyphRenderer(glasses: therapy.glasses, backgroundLevel: therapy.anaglyphBackgroundLevel)
        }
    }
}

extension View {
    /// Flattens a single-eye layer and, in dichoptic mode, multiplies it onto what is below
    /// so overlapping eye layers combine instead of covering each other.
    func eyeLayer(_ renderer: any EyeChannelRenderer) -> some View {
        compositingGroup().blendMode(renderer.isDichoptic ? .multiply : .normal)
    }
}

enum WhackAMolePalette {
    static let meadow = Color(red: 0.80, green: 0.91, blue: 0.70)
    static let meadowDeep = Color(red: 0.62, green: 0.82, blue: 0.52)
    static let holeShadow = Color(red: 0.33, green: 0.22, blue: 0.16)
    static let rim = Color(red: 0.52, green: 0.36, blue: 0.24)
    static let ink = Color(red: 0.24, green: 0.16, blue: 0.12)
    static let star = Color(red: 1.0, green: 0.78, blue: 0.2)
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.9)
    static let accent = Color(red: 0.93, green: 0.56, blue: 0.18)

    static func body(_ variant: CharacterVariant) -> Color {
        switch variant {
        case .sunny: Color(red: 0.98, green: 0.66, blue: 0.30)
        case .berry: Color(red: 0.86, green: 0.46, blue: 0.62)
        case .leafy: Color(red: 0.46, green: 0.72, blue: 0.44)
        case .sky: Color(red: 0.42, green: 0.66, blue: 0.90)
        }
    }
}
