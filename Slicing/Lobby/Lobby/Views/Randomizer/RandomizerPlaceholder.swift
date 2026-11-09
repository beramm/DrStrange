//
//  RandomizerPlaceholder.swift
//  Temporary randomizer screen. Replace when you build it.
//

import SwiftUI

struct RandomizerPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dice.fill")
                .font(.system(size: 90))
            Text("Randomizer")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LobbyBackground())
    }
}
