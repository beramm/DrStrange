import AudioToolbox
import UIKit

/// Gentle sound and haptic feedback. There is deliberately no "miss" sound.
///
/// No sound assets were provided, so short built-in system sounds stand in until real effects
/// are added. Most iPads have no haptic engine; the haptic calls are harmless there.
@MainActor
final class FeedbackPlayer {
    var soundEnabled: Bool
    var hapticsEnabled: Bool

    private let impact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()

    init(soundEnabled: Bool, hapticsEnabled: Bool) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        impact.prepare()
    }

    func hit() {
        play(1104)
        if hapticsEnabled { impact.impactOccurred() }
    }

    func decoyTapped() {
        play(1103)
    }

    func levelChanged() {
        play(1057)
        if hapticsEnabled { notification.notificationOccurred(.success) }
    }

    func sessionFinished() {
        play(1025)
    }

    private func play(_ id: SystemSoundID) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(id)
    }
}
