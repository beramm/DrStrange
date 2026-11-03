//
//  LobbyBackground.swift
//  Sky gradient with soft hills.
//

import SwiftUI

struct LobbyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.skyTop, .skyBottom], startPoint: .top, endPoint: .bottom)
            // Soft rolling hills
            GeometryReader { geo in
                Ellipse()
                    .fill(Color.hill)
                    .frame(width: geo.size.width * 1.3, height: geo.size.height * 0.5)
                    .position(x: geo.size.width * 0.3, y: geo.size.height * 1.05)
                Ellipse()
                    .fill(Color.hillFar)
                    .frame(width: geo.size.width * 1.1, height: geo.size.height * 0.45)
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 1.08)
            }
        }
        .ignoresSafeArea()
    }
}
