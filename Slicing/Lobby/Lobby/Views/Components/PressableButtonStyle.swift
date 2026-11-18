//
//  PressableButtonStyle.swift
//  Press effect shared by the app's buttons: shrinks a little while pressed,
//  with a small haptic tap.
//

import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    let sound: SoundEffect?

    init(sound: SoundEffect? = .button) {
        self.sound = sound
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, new in new }
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed, let sound else { return }
                SoundEffectPlayer.shared.play(sound)
            }
    }
}
