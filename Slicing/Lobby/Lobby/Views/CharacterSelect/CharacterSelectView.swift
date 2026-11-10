//
//  CharacterSelectView.swift
//  "Choose your character", sliced from the final design: the chosen character
//  on a podium with previous / next arrows, and its card with a Play button.
//
//  Every position below is taken from the 1194 × 834 Figma frame and then
//  scaled to the real screen (same approach as LobbyView).
//

import SwiftUI

struct CharacterSelectView: View {
    /// Called when the child taps Play.
    let onPlay: () -> Void
    /// Called when the settings button is tapped.
    let onSettings: () -> Void

    /// The chosen character, saved on the device so it survives app restarts.
    @AppStorage(GameCharacter.storageKey) private var selectedID = GameCharacter.fox.id
    @Environment(\.dismiss) private var dismiss

    private var selected: GameCharacter { GameCharacter.with(id: selectedID) }

    /// Size of the Figma frame the design was made in.
    private let design = CGSize(width: 1194, height: 834)

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / design.width
            let sy = geo.size.height / design.height
            let s = min(sx, sy)

            ZStack {
                LobbyScenery()

                // Top bar: back, title, settings.
                RoundIconButton(systemImage: "arrowtriangle.backward.fill", label: "Back", size: 62 * s) {
                    dismiss()
                }
                .position(x: 68 * sx, y: 83 * sy)

                Text("Choose your character")
                    .textCase(.uppercase)
                    .font(.doodle(80 * s))
                    .foregroundStyle(Color.titleBrown)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 900 * s)
                    .position(x: 598 * sx, y: 80 * sy)
                    .accessibilityAddTraits(.isHeader)

                RoundIconButton(systemImage: "gearshape.fill", label: "Settings", size: 62 * s, action: onSettings)
                    .position(x: 1128 * sx, y: 83 * sy)

                // The chosen character standing on the podium.
                Image("Podium")
                    .resizable()
                    .frame(width: 374 * s, height: 161 * s)
                    .position(x: 339 * sx, y: 643 * sy)

                // The character image has empty space around the drawing, so this frame
                // is bigger than the character itself.
                Image(selected.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 574 * s, height: 574 * s)
                    .position(x: 343 * sx, y: 426 * sy)
                    .accessibilityLabel(selected.name)

                ArrowButton(direction: .previous, size: 76 * s) {
                    selectedID = selected.neighbour(-1).id
                }
                .position(x: 97 * sx, y: 450 * sy)

                ArrowButton(direction: .next, size: 76 * s) {
                    selectedID = selected.neighbour(1).id
                }
                .position(x: 576 * sx, y: 450 * sy)

                CharacterInfoCard(character: selected, buttonTitle: "Play", scale: s, action: onPlay)
                    .position(x: 907 * sx, y: 454 * sy)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        // A small tap feeling when the character changes.
        .sensoryFeedback(.selection, trigger: selectedID)
    }
}

#Preview("Character select", traits: .landscapeLeft) {
    CharacterSelectView(onPlay: {}, onSettings: {})
}
