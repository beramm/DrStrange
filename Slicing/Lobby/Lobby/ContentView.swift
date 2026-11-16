//
// ContentView.swift
//  Lobby
//
//  Created by Keira on 03/11/26.
//

import SwiftUI

struct ContentView: View {
    @State private var path: [LobbyRoute] = []
    /// True while the Setting pop-up is open (it can open over any screen).
    @State private var showsSettings = false
    /// A game the Game Map picked while the Setting pop-up was open.
    /// It opens when the pop-up closes.
    @State private var waitingGame: MiniGame?
    /// Setting "Random game": the Game Map picks the game by itself.
    @AppStorage(MiniGame.randomSpinEnabledStorageKey) private var randomSpinEnabled = true

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
                    RandomizerView(
                        onChosen: openGame,
                        onSettings: { showsSettings = true }
                    )
                case .game(let game):
                    SelectedGameView(game: game, onExit: leaveGame)
                }
            }
        }
        // The Setting pop-up sits on top of whichever screen is showing.
        .overlay {
            if showsSettings {
                SettingsPopup(onClose: closeSettings)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsSettings)
    }

    private func openGame(_ game: MiniGame) {
        if showsSettings {
            waitingGame = game
        } else {
            path.append(.game(game))
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
        if let game = waitingGame {
            waitingGame = nil
            path.append(.game(game))
        }
    }
}

#Preview("Lobby", traits: .landscapeLeft) {
    ContentView()
}
