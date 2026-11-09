//
//  GamePlaceholder.swift
//  Temporary game page: just the game's name on an empty sky.
//  Replace with the real mini-game once it's in this app
//  (Whack a Mole is already built on the development branch).
//

import SwiftUI

struct GamePlaceholder: View {
    let game: MiniGame

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.sky
                .ignoresSafeArea()

            Text(game.title)
                .textCase(.uppercase)
                .font(.daysOne(64))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            RoundIconButton(systemImage: "arrowtriangle.backward.fill", label: "Back", size: 62) {
                dismiss()
            }
            .padding(.leading, 37)
            .padding(.top, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview(traits: .landscapeLeft) {
    GamePlaceholder(game: .whackAMole)
}
