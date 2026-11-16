//
//  LobbyScenery.swift
//  Lobby background: light blue sky with two grass hills along the bottom.
//

import SwiftUI

struct LobbyScenery: View {
    /// Width of the Figma frame the grass was drawn for.
    private let designWidth: CGFloat = 1194

    var body: some View {
        GeometryReader { geo in
            // Grows the grass with the screen width, keeping its shape.
            let scale = geo.size.width / designWidth

            ZStack {
                Color.sky

                // Darker hill on the right, behind.
                Image("Grass Lobby 2")
                    .resizable()
                    .frame(width: 896 * scale, height: 188 * scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

                // Lighter hill on the left, in front.
                Image("Grass Lobby")
                    .resizable()
                    .frame(width: 919 * scale, height: 184 * scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
