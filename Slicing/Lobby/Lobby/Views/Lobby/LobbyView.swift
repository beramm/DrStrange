//
//  LobbyView.swift
//  The lobby, from the final design: PADDY logo, Bea, Doomie and Coonie on the
//  grass, little houses and a lamp, and the hanging Start / Setting signs.
//
//  The design's pictures are all drawn on one 4:3 canvas (2752 × 2064). Each piece
//  is placed with its rectangle on that canvas, as fractions (0–1) of the width
//  and height, on a 4:3 "stage" that fills the screen. So every iPad shows the
//  same picture as the design.
//

import SwiftUI

struct LobbyView: View {
    let onStart: () -> Void
    let onSettings: () -> Void

    var body: some View {
        Color.sky
            .overlay {
                GeometryReader { geo in
                    stage(size: geo.size)
                }
                .aspectRatio(4 / 3, contentMode: .fill)
            }
            .clipped()
            .ignoresSafeArea()
    }

    private func stage(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Image("LobbyBG")
                .resizable()
                .frame(width: size.width, height: size.height)

            piece("LobbyCloud1", x0: 0.0541, y0: 0.3414, x1: 0.3368, y1: 0.4866, in: size)
            piece("LobbyCloud2", x0: 0.6584, y0: 0.0435, x1: 0.9637, y1: 0.2109, in: size)
            piece("LobbyHouseMushroom", x0: 0.2329, y0: 0.7450, x1: 0.3572, y1: 0.8843, in: size)
            piece("LobbyHouseOnion", x0: 0.8387, y0: 0.7160, x1: 0.9520, y1: 0.8814, in: size)
            piece("LobbyLamp", x0: 0.8081, y0: 0.5759, x1: 0.8692, y1: 0.9367, in: size)

            // The ropes the signs hang from.
            piece("LobbyRope", x0: 0.6225, y0: 0.0000, x1: 0.8943, y1: 0.3572, in: size)

            // The signs are buttons. `board` is where the wooden board is inside the
            // picture (the rest is vines): only the board can be tapped, and the
            // word is written in its middle.
            LobbySignButton(
                imageName: "LobbySignTop",
                title: "Start",
                board: CGRect(x: 0.01, y: 0.03, width: 0.98, height: 0.81),
                fontSize: size.height * 0.105,
                action: onStart
            )
            .frame(width: size.width * (0.9658 - 0.5494), height: size.height * (0.3000 - 0.0793))
            .position(x: size.width * (0.5494 + 0.9658) / 2, y: size.height * (0.0793 + 0.3000) / 2)

            LobbySignButton(
                imageName: "LobbySignBottom",
                title: "Setting",
                board: CGRect(x: 0.01, y: 0.43, width: 0.98, height: 0.55),
                fontSize: size.height * 0.105,
                action: onSettings
            )
            .frame(width: size.width * (0.9637 - 0.5665), height: size.height * (0.4929 - 0.1612))
            .position(x: size.width * (0.5665 + 0.9637) / 2, y: size.height * (0.1612 + 0.4929) / 2)

            Image("LobbyLogo")
                .resizable()
                .frame(width: size.width * (0.5193 - 0.0371), height: size.height * (0.3960 - 0.0997))
                .position(x: size.width * (0.0371 + 0.5193) / 2, y: size.height * (0.0997 + 0.3960) / 2)
                .accessibilityLabel("Paddy")
                .accessibilityAddTraits(.isHeader)

            // Bea, Doomie and Coonie. Their pictures are squares with space around the
            // character, so these rectangles are bigger than the characters (and may
            // go past the screen edge).
            piece("CharacterBunny", x0: -0.0948, y0: 0.4194, x1: 0.4199, y1: 1.1057, in: size)
            piece("CharacterFox", x0: 0.2062, y0: 0.4306, x1: 0.6757, y1: 1.0566, in: size)
            piece("CharacterRaccoon", x0: 0.4551, y0: 0.4945, x1: 0.9050, y1: 1.0943, in: size)
        }
        .frame(width: size.width, height: size.height)
    }

    /// One picture from the design, placed by its rectangle on the 4:3 canvas.
    private func piece(_ name: String, x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat, in size: CGSize) -> some View {
        Image(name)
            .resizable()
            .frame(width: size.width * (x1 - x0), height: size.height * (y1 - y0))
            .position(x: size.width * (x0 + x1) / 2, y: size.height * (y0 + y1) / 2)
            .accessibilityHidden(true)
    }
}

/// A hanging wooden sign from the design, with its word written on the board.
private struct LobbySignButton: View {
    let imageName: String
    let title: LocalizedStringKey
    /// Where the board is inside the picture, as fractions (0–1) of its size.
    let board: CGRect
    let fontSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Image(imageName)
                        .resizable()
                    Text(title)
                        .textCase(.uppercase)
                        .doodleText(size: fontSize)
                        .foregroundStyle(Color.signText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: geo.size.width * board.width * 0.9)
                        .position(x: geo.size.width * board.midX, y: geo.size.height * board.midY)
                }
            }
            // Only the board reacts to taps, not the vines above it.
            .contentShape(BoardShape(board: board))
        }
        // Same press feedback as the other buttons: shrinks a little, small vibration.
        .buttonStyle(PressableButtonStyle())
    }
}

/// The board part of a sign picture.
private struct BoardShape: Shape {
    let board: CGRect

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX + rect.width * board.minX,
            y: rect.minY + rect.height * board.minY,
            width: rect.width * board.width,
            height: rect.height * board.height
        ))
    }
}

#Preview("Lobby", traits: .landscapeLeft) {
    LobbyView(onStart: {}, onSettings: {})
}
