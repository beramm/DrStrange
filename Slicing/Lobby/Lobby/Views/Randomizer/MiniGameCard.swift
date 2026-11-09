//
//  MiniGameCard.swift
//  One game card on the randomizer. Turns orange while highlighted.
//

import SwiftUI

struct MiniGameCard: View {
    let game: MiniGame
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: game.systemImage)
                .font(.system(size: 64))
            Text(LocalizedStringKey(game.title))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(isHighlighted ? Color.white : Color.ink)
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isHighlighted ? Color.accent : Color.cream)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }
}
