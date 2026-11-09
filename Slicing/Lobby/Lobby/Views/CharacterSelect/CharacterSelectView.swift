//
//  CharacterSelectView.swift
//  Pick a character, then tap Play to go to the randomizer.
//

import SwiftUI

struct CharacterSelectView: View {
    /// Called when the child taps Play.
    let onPlay: () -> Void

    /// The chosen character, saved on the device so it survives app restarts.
    @AppStorage(GameCharacter.storageKey) private var selectedID = GameCharacter.fox.id

    private var selected: GameCharacter { GameCharacter.with(id: selectedID) }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: geo.size.width * 0.06) {
                // Left: big picture of the chosen character
                ZStack {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(Color.cream)
                    Image(selected.imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(32)
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(width: geo.size.width * 0.38)

                // Right: character choices, then Play
                VStack(spacing: 48) {
                    Spacer()
                    HStack(spacing: 20) {
                        ForEach(GameCharacter.all) { character in
                            CharacterChoiceButton(
                                character: character,
                                isSelected: character.id == selected.id
                            ) {
                                selectedID = character.id
                            }
                        }
                    }
                    KidButton(title: "Play", systemImage: "play.fill", kind: .primary, action: onPlay)
                    Spacer()
                }
                .frame(maxWidth: 480)
            }
            .padding(.horizontal, 48)
            .padding(.top, 32)
            // Keep tappable things away from the bottom edge (wrists rest there).
            .padding(.bottom, 72)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(LobbyBackground())
    }
}

#Preview("Character select", traits: .landscapeLeft) {
    CharacterSelectView(onPlay: {})
}
