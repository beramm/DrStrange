//
//  HUDButton.swift
//  Round white button in the top bar (exit, pause), same as in Whack-a-Mole.
//

import SwiftUI

struct HUDButton: View {
    let systemImage: String
    /// Read out by VoiceOver, since the button only shows an icon.
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.ink)
                .frame(width: 60, height: 60)
                .background(Circle().fill(.white.opacity(0.75)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
