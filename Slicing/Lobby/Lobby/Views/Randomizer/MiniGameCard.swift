//
//  MiniGameCard.swift
//  One game card on the Game Map.
//
//  While the game is being chosen, the card shows only the game's name. Once the
//  game is picked (by the randomizer or by a tap), the card flips over to show the
//  full card from the design: cover, title and tagline (all drawn in the picture).
//  VoiceOver always reads the title and tagline.
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
    /// False: only the name. True: flipped over to the full card.
    var isRevealed = false
    /// 1 = design size. Pass the screen's scale so the card grows with the iPad.
    let scale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FlipCard(
            angle: isRevealed ? 180 : 0,
            usesRotation: !reduceMotion,
            front: { nameSide },
            back: { fullCard }
        )
        .animation(.easeInOut(duration: 0.6), value: isRevealed)
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

    /// The plain card with just the game's name.
    private var nameSide: some View {
        Image("Card")
            .resizable()
            .overlay {
                Text(game.title)
                    .textCase(.uppercase)
                    .doodleText(size: 76 * scale)
                    .foregroundStyle(Color.titleBrown)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .frame(width: 330 * scale)
            }
    }

    /// The full card from the design.
    private var fullCard: some View {
        Image(game.cardImageName)
            .resizable()
            .scaledToFit()
    }
}

/// Shows `front` while turned less than halfway (`angle` below 90°) and `back` after that,
/// turning around the vertical axis like a real card.
private struct FlipCard<Front: View, Back: View>: View, Animatable {
    var angle: Double
    /// False (Reduce Motion): no turning, the sides just swap.
    let usesRotation: Bool
    @ViewBuilder let front: () -> Front
    @ViewBuilder let back: () -> Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            if angle < 90 {
                front()
            } else {
                // Turned the other way round, so it reads correctly after the flip.
                back()
                    .rotation3DEffect(.degrees(usesRotation ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            }
        }
        .rotation3DEffect(.degrees(usesRotation ? angle : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}

#Preview(traits: .landscapeLeft) {
    HStack {
        MiniGameCard(game: .whackAMole, scale: 0.8)
        MiniGameCard(game: .veggieKeeper, isRevealed: true, scale: 0.8)
    }
    .padding()
    .background(Color.sky)
}
