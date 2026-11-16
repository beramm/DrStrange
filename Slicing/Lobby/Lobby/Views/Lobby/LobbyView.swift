//
//  LobbyView.swift
//  The lobby, sliced from the final design: PADDY logo and two foxes on the
//  left, hanging wooden Start / Setting signs on the right, grass at the bottom.
//
//  Every position below is taken from the 1194 × 834 Figma frame and then
//  scaled to the real screen, so the layout matches the design on every iPad.
//

import SwiftUI

struct LobbyView: View {
    let onStart: () -> Void
    let onSettings: () -> Void

    /// Size of the Figma frame the design was made in.
    private let design = CGSize(width: 1194, height: 834)

    var body: some View {
        GeometryReader { geo in
            // sx / sy turn design positions into screen positions.
            // s scales sizes without stretching anything.
            let sx = geo.size.width / design.width
            let sy = geo.size.height / design.height
            let s = min(sx, sy)

            // Sign boards: 469 × 150 in the design, centred at x 908.
            let signX = 908 * sx
            let startY = 252 * sy
            let settingY = 445 * sy

            ZStack {
                LobbyScenery()

                // Two ropes from the top of the screen down to the lower sign.
                // They sit at x 760 and 1057 in the design (148 left / 149 right of the signs' centre).
                ForEach([-148.0, 149.0], id: \.self) { offset in
                    Rectangle()
                        .fill(Color.signRope)
                        .frame(width: 5 * s, height: settingY)
                        .position(x: signX + offset * s, y: settingY / 2)
                }

                SignButton(title: "Start", fontSize: 92 * s, action: onStart)
                    .frame(width: 469 * s, height: 150 * s)
                    .position(x: signX, y: startY)

                SignButton(title: "Setting", fontSize: 92 * s, action: onSettings)
                    .frame(width: 469 * s, height: 150 * s)
                    .position(x: signX, y: settingY)

                // PADDY logo image (664 × 251, with some empty space around the letters).
                // Placed so the letters land where they are in the design.
                Image("Paddy Logo Lobby")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 664 * s, height: 251 * s)
                    .position(x: 334 * sx, y: 203 * sy)
                    .accessibilityLabel("Paddy")
                    .accessibilityAddTraits(.isHeader)

                // The fox image has empty space around the drawing, so these frames are
                // bigger than the fox itself.
                // The left fox is mirrored so it faces the other fox.
                fox(size: 539 * s, facingRight: true)
                    .position(x: 204 * sx, y: 542 * sy)
                fox(size: 511 * s)
                    .position(x: 470 * sx, y: 594 * sy)
            }
        }
        .ignoresSafeArea()
    }

    /// The fox image. `facingRight` flips it left-to-right, like a mirror.
    private func fox(size: CGFloat, facingRight: Bool = false) -> some View {
        Image(Buddy.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(x: facingRight ? -1 : 1, y: 1)
            .accessibilityHidden(true)
    }
}

#Preview("Lobby", traits: .landscapeLeft) {
    LobbyView(onStart: {}, onSettings: {})
}
