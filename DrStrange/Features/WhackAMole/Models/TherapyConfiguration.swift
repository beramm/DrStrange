import Foundation

enum Eye: String, Codable, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }
    var other: Eye { self == .left ? .right : .left }
    var title: String { self == .left ? "Left eye" : "Right eye" }
}

/// How the board is presented.
///
/// An ordinary iPad screen shows the same image to both eyes. Eye-specific images only exist when
/// the child wears filters (anaglyph) or uses a dedicated dichoptic display. A new display method
/// is added by implementing `EyeChannelRenderer` and adding a case here.
enum ViewingMode: String, Codable, CaseIterable, Identifiable {
    /// No eye separation. Both eyes see everything. Use for familiarisation and development.
    case standard
    /// Red/cyan glasses. Red ink is seen only by the eye behind the cyan filter, and vice versa.
    case anaglyph

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Standard (no glasses)"
        case .anaglyph: "Red/cyan glasses"
        }
    }

    var isDichoptic: Bool { self != .standard }
}

struct AnaglyphGlasses: Codable, Equatable {
    /// Eye behind the red filter. Most consumer glasses put red on the left.
    var redFilterEye: Eye = .left
}

/// Settings that control what each eye sees.
///
/// Nothing here is inferred by the app. The amblyopic eye and the contrast values must be entered
/// by (or under the direction of) the child's eye-care professional.
struct TherapyConfiguration: Codable, Equatable {
    var viewingMode: ViewingMode = .standard
    var glasses = AnaglyphGlasses()

    /// Entered by a clinician or caregiver. `nil` means "not set": both eyes are treated the same.
    var amblyopicEye: Eye?

    /// Contrast (0...1) of elements shown only to the amblyopic eye.
    /// Placeholder: `.requiresClinicalValidation`.
    var amblyopicEyeContrast: Double = 1.0

    /// Contrast (0...1) of elements shown only to the fellow eye. Published dichoptic games
    /// usually start the fellow eye lower and raise it as performance allows; the starting value
    /// and any schedule are clinical decisions. Placeholder: `.requiresClinicalValidation`.
    var fellowEyeContrast: Double = 1.0

    /// Share of characters whose identifying features (face, star) go to the amblyopic eye;
    /// the silhouette goes to the other eye. 0.5 = perfectly balanced.
    /// Placeholder: `.requiresClinicalValidation`.
    var criticalFeatureAmblyopicShare: Double = 0.5

    /// Contrast of the shared board (holes, rim) seen by both eyes. Kept low so it anchors
    /// fusion without competing with the targets. `.gameDesign`.
    var sharedBoardContrast: Double = 0.35

    /// Grey level of the anaglyph background. 1.0 is white; slightly lower reduces glare. `.gameDesign`.
    var anaglyphBackgroundLevel: Double = 0.94

    /// Contrast for an element meant for one eye.
    func contrast(for eye: Eye) -> Double {
        guard let amblyopicEye else { return 1.0 }
        return eye == amblyopicEye ? amblyopicEyeContrast : fellowEyeContrast
    }
}
