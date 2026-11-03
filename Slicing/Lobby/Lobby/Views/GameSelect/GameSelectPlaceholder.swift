//
//  GameSelectPlaceholder.swift
//  Temporary game select screen. Replace when you build it.
//

import SwiftUI

struct GameSelectPlaceholder: View {
    private let games: [(String, String)] = [
        ("Whack a Mole", "scope"),                           // saccade
        ("Fixation", "hand.point.up.left.fill"),         // fixation
        ("Follow the Fox", "point.topleft.down.to.point.bottomright.curvepath") // pursuit
    ]

    var body: some View {
        HStack(spacing: 28) {
            ForEach(games, id: \.0) { game in
                Button {
                    // TODO: open the game once it exists.
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: game.1).font(.system(size: 60))
                        Text(LocalizedStringKey(game.0))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .background(RoundedRectangle(cornerRadius: 32).fill(Color.playGreen))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LobbyBackground())
    }
}
