//
//  LobbyScenery.swift
//  Background for the lobby, character select and randomizer: sky with grass
//  hills along the bottom (the "BG" picture from the design).
//

import SwiftUI

struct LobbyScenery: View {
    var body: some View {
        // Fills the whole screen; on iPads that are not 4:3 the edges are trimmed.
        Color.sky
            .overlay {
                Image("LobbyBG")
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
