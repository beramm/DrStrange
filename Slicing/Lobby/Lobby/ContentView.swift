//
// ContentView.swift
//  Lobby
//
//  Created by Keira on 03/11/26.
//

import SwiftUI

struct ContentView: View {
    @State private var path: [LobbyRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            LobbyView(
                onStart: { path.append(.characterSelect) },
                onSettings: { path.append(.settings) }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LobbyRoute.self) { route in
                switch route {
                case .characterSelect:
                    CharacterSelectView(
                        onPlay: { path.append(.randomizer) },
                        onSettings: { path.append(.settings) }
                    )
                case .randomizer:
                    RandomizerView(
                        onChosen: { game in path.append(.game(game)) },
                        onSettings: { path.append(.settings) }
                    )
                case .game(let game):  GamePlaceholder(game: game)
                case .settings:        SettingsPlaceholder()
                }
            }
        }
    }
}

#Preview("Lobby", traits: .landscapeLeft) {
    ContentView()
}
