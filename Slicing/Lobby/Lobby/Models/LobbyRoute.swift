//
//  LobbyRoute.swift
//  Screens reachable from the lobby.
//

import Foundation

nonisolated enum LobbyRoute: Hashable {
    case characterSelect
    case randomizer
    case game(MiniGame)
    // Settings is not a screen: it is a pop-up over the current screen (see ContentView).
}
