import AVFAudio
import Foundation

/// Owns the app's single background-music channel.
///
/// Screen changes request a track. Repeated requests for the same track do not restart it,
/// and changing tracks uses a short crossfade instead of cutting between songs.
@MainActor
final class BackgroundMusicPlayer {
    enum Track: String {
        case lobby = "BGM_lobby"
        case gameSelected = "BGM_game_selected"
        case veggieKeeper = "BGM_veggie_keeper"
        case whackAMole = "BGM_whack_a_mole"

        fileprivate var fileExtension: String { "mp3" }
    }

    static let shared = BackgroundMusicPlayer()

    private let fadeDuration: TimeInterval = 0.35
    private var playbackVolume: Float = 1

    private var player: AVAudioPlayer?
    private var outgoingPlayer: AVAudioPlayer?
    private var fadeCleanupTask: Task<Void, Never>?
    private var currentTrack: Track?
    private var requestedTrack: Track?
    private var isSceneActive = true

    private init() {
        configureAudioSession()
    }

    func play(_ track: Track) {
        requestedTrack = track
        guard isSceneActive else { return }

        if currentTrack == track, let player {
            if !player.isPlaying { player.play() }
            return
        }

        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: track.fileExtension) else {
            assertionFailure("Missing background music: \(track.rawValue).\(track.fileExtension)")
            return
        }

        do {
            let nextPlayer = try AVAudioPlayer(contentsOf: url)
            nextPlayer.numberOfLoops = -1
            nextPlayer.volume = 0
            nextPlayer.prepareToPlay()

            fadeCleanupTask?.cancel()
            outgoingPlayer?.stop()

            let previousPlayer = player
            outgoingPlayer = previousPlayer
            player = nextPlayer
            currentTrack = track

            nextPlayer.play()
            nextPlayer.setVolume(playbackVolume, fadeDuration: fadeDuration)
            previousPlayer?.setVolume(0, fadeDuration: fadeDuration)

            fadeCleanupTask = Task { [weak self, weak previousPlayer] in
                try? await Task.sleep(for: .seconds(self?.fadeDuration ?? 0))
                guard !Task.isCancelled else { return }
                previousPlayer?.stop()
                if self?.outgoingPlayer === previousPlayer {
                    self?.outgoingPlayer = nil
                }
            }
        } catch {
            print("BackgroundMusicPlayer: could not play \(track.rawValue): \(error)")
        }
    }

    func setVolume(_ volume: Double) {
        playbackVolume = Float(min(max(volume, 0), 1))
        player?.setVolume(playbackVolume, fadeDuration: fadeDuration)
    }

    func setSceneActive(_ active: Bool) {
        guard isSceneActive != active else { return }
        isSceneActive = active

        if active {
            if let requestedTrack { play(requestedTrack) }
        } else {
            fadeCleanupTask?.cancel()
            outgoingPlayer?.stop()
            outgoingPlayer = nil
            player?.pause()
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        } catch {
            print("BackgroundMusicPlayer: could not configure audio session: \(error)")
        }
    }
}
