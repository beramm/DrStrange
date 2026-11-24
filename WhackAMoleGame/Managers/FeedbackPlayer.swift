import AVFAudio
import AudioToolbox
import UIKit

/// Sound and haptic feedback for Whack-a-Mole. Custom effects are prepared up front so the
/// hammer impact and a missed mole can play without decode delay.
@MainActor
final class FeedbackPlayer {
    var soundEnabled: Bool
    var hapticsEnabled: Bool
    var volume: Float {
        didSet { updateCustomPlayerVolumes() }
    }

    private let impact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private var hitPlayer: AVAudioPlayer?
    private var missedPlayer: AVAudioPlayer?

    init(soundEnabled: Bool, hapticsEnabled: Bool, volume: Double = 1) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.volume = Float(min(max(volume, 0), 1))
        self.hitPlayer = Self.makePlayer(named: "SFX_mole_whacked")
        self.missedPlayer = Self.makePlayer(named: "SFX_mole_got_away")
        updateCustomPlayerVolumes()
        impact.prepare()
    }

    func hit() {
        if !play(hitPlayer) { playSystemSound(1104) }
        if hapticsEnabled { impact.impactOccurred() }
    }

    func missed() {
        _ = play(missedPlayer)
    }

    func decoyTapped() {
        playSystemSound(1103)
    }

    func newHighScore() {
        playSystemSound(1057)
        if hapticsEnabled { notification.notificationOccurred(.success) }
    }

    func sessionFinished() {
        playSystemSound(1025)
    }

    @discardableResult
    private func play(_ player: AVAudioPlayer?) -> Bool {
        guard soundEnabled, let player else { return false }
        player.currentTime = 0
        player.play()
        return true
    }

    private func playSystemSound(_ id: SystemSoundID) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(id)
    }

    private func updateCustomPlayerVolumes() {
        hitPlayer?.volume = volume
        missedPlayer?.volume = volume
    }

    private static func makePlayer(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else {
            assertionFailure("Missing Whack-a-Mole sound effect: \(name).caf")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("FeedbackPlayer: could not load \(name): \(error)")
            return nil
        }
    }
}
