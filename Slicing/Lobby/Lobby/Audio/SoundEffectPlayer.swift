import AVFAudio
import Foundation

enum SoundEffect: CaseIterable, Hashable {
    case button
    case characterSelection
    case randomizer

    fileprivate var resourceName: String {
        switch self {
        case .button: "SFX_button"
        case .characterSelection: "SFX_character_selection"
        case .randomizer: "SFX_randomizer"
        }
    }

    fileprivate var fileExtension: String {
        switch self {
        case .characterSelection: "mp3"
        case .button, .randomizer: "caf"
        }
    }
}

/// Owns the app's sound-effect players separately from background music.
///
/// Add future effects to `SoundEffect`, then trigger them with `play`,
/// `startLoop`, or `stop`.
@MainActor
final class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private var playbackVolume: Float = 1

    private init() {
        for effect in SoundEffect.allCases {
            players[effect] = makePlayer(for: effect)
        }
    }

    func setVolume(_ volume: Double) {
        playbackVolume = Float(min(max(volume, 0), 1))
        for player in players.values {
            player.volume = playbackVolume
        }
    }

    func play(_ effect: SoundEffect) {
        guard let player = players[effect] else { return }
        player.stop()
        player.currentTime = 0
        player.numberOfLoops = 0
        player.volume = playbackVolume
        player.play()
    }

    func startLoop(_ effect: SoundEffect) {
        guard let player = players[effect] else { return }
        player.stop()
        player.currentTime = 0
        player.numberOfLoops = -1
        player.volume = playbackVolume
        player.play()
    }

    func stop(_ effect: SoundEffect) {
        guard let player = players[effect] else { return }
        player.stop()
        player.currentTime = 0
    }

    private func makePlayer(for effect: SoundEffect) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(
            forResource: effect.resourceName,
            withExtension: effect.fileExtension
        ) else {
            assertionFailure("Missing sound effect: \(effect.resourceName).\(effect.fileExtension)")
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = playbackVolume
            player.prepareToPlay()
            return player
        } catch {
            print("SoundEffectPlayer: could not load \(effect.resourceName): \(error)")
            return nil
        }
    }
}
