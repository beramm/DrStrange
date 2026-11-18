//
// ContentView.swift
//  Lobby
//
//  Created by Keira on 03/11/26.
//

import SwiftUI

struct ContentView: View {
    @State private var path: [LobbyRoute] = []
    /// True while the Settings pop-up is open (it can open over any screen).
    @State private var showsSettings = false
    /// Setting "Random game": the Game Map picks the game by itself.
    @AppStorage(MiniGame.randomSpinEnabledStorageKey) private var randomSpinEnabled = true
    @AppStorage(AppSettings.backgroundVolumeKey)
    private var backgroundMusicVolume = AppSettings.migratedBackgroundVolume()
    @AppStorage(AppSettings.soundEffectsVolumeKey) private var soundEffectsVolume = 1.0
    @Environment(\.scenePhase) private var scenePhase

    private let music = BackgroundMusicPlayer.shared
    private let soundEffects = SoundEffectPlayer.shared

    var body: some View {
        NavigationStack(path: $path) {
            LobbyView(
                onStart: { path.append(.characterSelect) },
                onSettings: { showsSettings = true }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LobbyRoute.self) { route in
                switch route {
                case .characterSelect:
                    CharacterSelectView(
                        onPlay: { path.append(.randomizer) },
                        onSettings: { showsSettings = true }
                    )
                case .randomizer:
                    RandomizerView(onChosen: { game in path.append(.game(game)) })
                case .game(let game):
                    SelectedGameView(game: game, onExit: leaveGame)
                }
            }
        }
        // The Settings pop-up sits on top of whichever screen is showing.
        .overlay {
            if showsSettings {
                SettingsPopup(onClose: closeSettings)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsSettings)
        .onAppear {
            music.setVolume(backgroundMusicVolume)
            soundEffects.setVolume(soundEffectsVolume)
            music.setSceneActive(scenePhase == .active)
            updateBackgroundMusic()
        }
        .onChange(of: path) {
            updateBackgroundMusic()
        }
        .onChange(of: backgroundMusicVolume) { _, volume in
            music.setVolume(volume)
        }
        .onChange(of: soundEffectsVolume) { _, volume in
            soundEffects.setVolume(volume)
        }
        .onChange(of: scenePhase) { _, phase in
            music.setSceneActive(phase == .active)
        }
    }

    /// Leaving a game. With "Random game" on, going back to the Game Map would
    /// just pick and open a game again (a never-ending loop), so go back to the
    /// start screen. With it off, go back to the Game Map to choose another game.
    private func leaveGame() {
        if randomSpinEnabled {
            path.removeAll()
        } else {
            path.removeLast()
        }
    }

    private func closeSettings() {
        showsSettings = false
    }

    private func updateBackgroundMusic() {
        if case .game = path.last {
            music.play(.gameSelected)
        } else {
            music.play(.lobby)
        }
    }
}

#Preview("Lobby", traits: .landscapeLeft) {
    ContentView()
}
