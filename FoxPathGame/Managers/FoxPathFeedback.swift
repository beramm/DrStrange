import AudioToolbox
import UIKit

/// Gentle sound and haptic cues for Follow the Fox.
///
/// No sound assets were provided, so short built-in system sounds stand in until real effects
/// are added. Most iPads have no haptic engine; the haptic calls are harmless there.
@MainActor
final class FoxPathFeedback {
    var soundEnabled: Bool
    var hapticsEnabled: Bool

    private let impact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()

    init(soundEnabled: Bool, hapticsEnabled: Bool) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        impact.prepare()
    }

    /// One soft cue when the fox stops. It is not repeated while the fox waits.
    func wentOffTrack() {
        play(1103)
        if hapticsEnabled { impact.impactOccurred() }
    }

    func refocused() {
        play(1104)
    }

    /// The character reached the stall.
    func finished() {
        play(1025)
        if hapticsEnabled { notification.notificationOccurred(.success) }
    }

    /// The mole's hole opens. A soft cue, no alarm.
    func thiefAppeared() {
        play(1105)
    }

    /// The mole took a carrot and a heart is gone.
    func lifeLost() {
        play(1073)
        if hapticsEnabled { notification.notificationOccurred(.warning) }
    }

    /// Time is up or the last heart is gone.
    func gameEnded() {
        play(1025)
    }

    private func play(_ id: SystemSoundID) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(id)
    }
}
