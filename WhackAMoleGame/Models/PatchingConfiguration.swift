import Foundation

enum Eye: String, Codable, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }
    var other: Eye { self == .left ? .right : .left }
    var title: String { self == .left ? "Left eye" : "Right eye" }
}

/// Caregiver-entered record of the patching routine for a session.
///
/// This is documentation only. The game plays the same whichever eye is patched. The app never
/// works out which eye is amblyopic, never checks the patch (no camera), and never suggests how
/// long a patch should be worn: those follow the child's ophthalmologist.
struct PatchingConfiguration: Codable, Equatable {
    /// Eye covered by the patch, as prescribed. `nil` means not recorded.
    var patchedEye: Eye?
    /// Eye the child plays with. `nil` means not recorded.
    var playingEye: Eye?

    var isRecorded: Bool { patchedEye != nil || playingEye != nil }

    /// `false` when the same eye is recorded as both patched and playing, which is almost
    /// certainly an entry mistake worth showing to the caregiver.
    var isConsistent: Bool {
        guard let patchedEye, let playingEye else { return true }
        return patchedEye != playingEye
    }
}
