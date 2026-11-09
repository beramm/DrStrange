//
//  CharacterInfoCard.swift
//  The character card: portrait, name (Days One), tagline (Belanosima) and a button.
//  Used on character select; meant to be reused on the randomizer.
//
//  Sizes come from the 421 × 570 "Card" image and are multiplied by `scale`.
//

import SwiftUI

struct CharacterInfoCard: View {
    let character: GameCharacter
    let buttonTitle: LocalizedStringKey
    /// 1 = design size. Pass the screen's scale so the card grows with the iPad.
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        let s = scale

        ZStack {
            Image("Card")
                .resizable()

            CharacterPortrait(imageName: character.imageName, diameter: 186 * s)
                .position(x: 211 * s, y: 161 * s)

            Text(character.name)
                .textCase(.uppercase)
                .font(.daysOne(38 * s))
                .foregroundStyle(Color.ink)
                .position(x: 211 * s, y: 309 * s)

            Text(character.tagline)
                .font(.belanosima(19 * s))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
                .frame(width: 340 * s)
                .position(x: 211 * s, y: 358 * s)

            SignButton(title: buttonTitle, fontSize: 56 * s, action: action)
                .frame(width: 234 * s, height: 75 * s)
                .position(x: 211 * s, y: 464 * s)
        }
        .frame(width: 421 * s, height: 570 * s)
    }
}

#Preview(traits: .landscapeLeft) {
    CharacterInfoCard(character: .fox, buttonTitle: "Play", scale: 1, action: {})
        .padding()
        .background(Color.sky)
}
