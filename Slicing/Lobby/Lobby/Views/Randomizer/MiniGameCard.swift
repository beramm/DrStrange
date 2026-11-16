//
//  MiniGameCard.swift
//  One game card on the Game Map. The design's card pictures already show the
//  cover, the title and the tagline, so the card is just that picture.
//  VoiceOver still reads the title and tagline.
//
//  A locked game (testing setting "Lock games") is darkened and shows a lock.
//
//  The card is 421 × 570 at design size, multiplied by `scale`.
//  The Game Map shrinks the cards that aren't chosen.
//

import SwiftUI

struct MiniGameCard: View {
    let game: MiniGame
    var isLocked = false
    /// 1 = design size. Pass the screen's scale so the card grows with the iPad.
    let scale: CGFloat

    var body: some View {
        Image(game.cardImageName)
            .resizable()
            .scaledToFit()
            .frame(width: 421 * scale, height: 570 * scale)
            .overlay {
                if isLocked {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                            .fill(.black.opacity(0.35))
                            .padding(6 * scale)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 64 * scale, weight: .bold))
                            .foregroundStyle(Color.signText)
                            .frame(width: 130 * scale, height: 130 * scale)
                            .background(Circle().fill(Color.roundButton))
                    }
                }
            }
            .accessibilityElement()
            .accessibilityLabel(isLocked ? "\(game.title), locked" : "\(game.title). \(game.tagline)")
    }
}

#Preview(traits: .landscapeLeft) {
    HStack {
        MiniGameCard(game: .whackAMole, scale: 0.8)
        MiniGameCard(game: .veggieKeeper, isLocked: true, scale: 0.8)
    }
    .padding()
    .background(Color.sky)
}
