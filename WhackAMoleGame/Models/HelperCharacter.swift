import SwiftUI

/// The friend who waits in the corner and swings the hammer when the child taps a mole. One helper
/// is picked at random when a game starts and stays for the whole game. Every helper runs exactly
/// the same attack (same phases, timing and placement); only the artwork
/// differs. Frames of every helper are aligned so its card sits at `FoxCharacterView.cardRect`.
///
/// To add a helper: add its `<Name>Hammer/FrameNN` images (card aligned the same way), a case
/// here and its values below. Random selection picks it up automatically.
enum HelperCharacter: String, CaseIterable, Equatable, Sendable {
    case fox
    case raccoon
    case bunny

    /// Asset folder of the hammer swing frames.
    var assetFolder: String {
        switch self {
        case .fox: "FoxHammer"
        case .raccoon: "RaccoonHammer"
        case .bunny: "BunnyHammer"
        }
    }

    /// Number of swing frames: frame 1 holds the hammer raised, the last is the moment of impact.
    var frameCount: Int {
        switch self {
        case .fox: 21
        case .raccoon: 24
        case .bunny: 9
        }
    }

    /// Where the hammer head is at the impact frame, as a fraction of the (unmirrored) image.
    var impactPoint: CGPoint {
        switch self {
        case .fox: CGPoint(x: 0.11, y: 0.62)
        case .raccoon: CGPoint(x: 0.153, y: 0.739)
        case .bunny: CGPoint(x: 0.197, y: 0.435)
        }
    }

    /// Colours of the card behind the helper, measured from its frames.
    var cardFill: Color {
        switch self {
        case .fox: Color(red: 0.984, green: 0.800, blue: 0.400)
        case .raccoon: Color(red: 0.525, green: 0.735, blue: 0.909)
        case .bunny: Color(red: 0.627, green: 0.708, blue: 0.571)
        }
    }

    var cardBorder: Color {
        switch self {
        case .fox: Color(red: 0.957, green: 0.608, blue: 0.227)
        case .raccoon: Color(red: 0.463, green: 0.663, blue: 0.878)
        case .bunny: Color(red: 0.514, green: 0.578, blue: 0.455)
        }
    }

    /// One helper at random, every helper equally likely. Each game draws on its own, so the same
    /// helper may come several games in a row.
    static func random(using generator: inout some RandomNumberGenerator) -> HelperCharacter {
        allCases.randomElement(using: &generator) ?? .fox
    }
}
