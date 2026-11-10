//
//  MiniGameCard.swift
//  One game card on the Game Map: cover picture, title (Days One) and tagline (Belanosima)
//  on the same "Card" image as the character card.
//
//  Sizes come from the 421 × 570 "Card" image and are multiplied by `scale`.
//  The card is drawn at full size; the Game Map shrinks the cards that aren't chosen.
//

import SwiftUI

struct MiniGameCard: View {
    let game: MiniGame
    /// 1 = design size. Pass the screen's scale so the card grows with the iPad.
    let scale: CGFloat

    var body: some View {
        let s = scale

        ZStack {
            Image("Card")
                .resizable()

            // Cover picture. TODO: replace with the game's real cover image when it's ready.
            RoundedRectangle(cornerRadius: 8 * s, style: .continuous)
                .fill(Color.coverPlaceholder)
                .frame(width: 324 * s, height: 280 * s)
                .position(x: 210 * s, y: 186 * s)

            // Title: one Text per line, pulled closer together than normal line spacing allows.
            VStack(spacing: -10 * s) {
                ForEach(game.cardTitle.components(separatedBy: "\n"), id: \.self) { line in
                    Text(line)
                }
            }
            .textCase(.uppercase)
            .font(.daysOne(40 * s))
            .foregroundStyle(Color.ink)
            .position(x: 210 * s, y: 393 * s)

            Text(game.tagline)
                .font(.belanosima(20 * s))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .frame(width: 320 * s)
                .position(x: 210 * s, y: 486 * s)
        }
        .frame(width: 421 * s, height: 570 * s)
        .accessibilityElement(children: .combine)
    }
}

#Preview(traits: .landscapeLeft) {
    MiniGameCard(game: .whackAMole, scale: 1)
        .padding()
        .background(Color.sky)
}
