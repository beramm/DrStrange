//
//  GamePlaceholder.swift
//  Temporary game screen. Replace with the real mini-game once it's in this app.
//

import SwiftUI

struct GamePlaceholder: View {
    let game: MiniGame

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: game.systemImage)
                .font(.system(size: 90))
            Text(LocalizedStringKey(game.title))
                .font(.system(size: 40, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LobbyBackground())
    }
}
