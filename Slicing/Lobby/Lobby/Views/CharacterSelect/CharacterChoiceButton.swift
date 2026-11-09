//
//  CharacterChoiceButton.swift
//  One small character tile. The chosen one gets an orange border.
//

import SwiftUI

struct CharacterChoiceButton: View {
    let character: GameCharacter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(character.imageName)
                .resizable()
                .scaledToFit()
                .padding(16)
                .frame(width: 140, height: 140)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.cream)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.accent, lineWidth: isSelected ? 6 : 0)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(character.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
