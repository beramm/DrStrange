//
//  KidButton.swift
//  Big flat capsule button used across the app (same style as the whack-a-mole Play button).
//

import SwiftUI

struct KidButton: View {
    enum Kind { case primary, secondary }

    let title: LocalizedStringKey
    let systemImage: String
    var kind: Kind = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.system(size: kind == .primary ? 40 : 28, weight: .heavy, design: .rounded))
                // Primary: white on orange. Secondary: brown on cream.
                .foregroundStyle(kind == .primary ? Color.white : Color.ink)
                .frame(maxWidth: .infinity)
                .frame(height: kind == .primary ? 110 : 80)
                .background(Capsule().fill(kind == .primary ? Color.accent : Color.cream))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Shrinks the button a little while it's pressed, with a small haptic tap.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, new in new }
    }
}
