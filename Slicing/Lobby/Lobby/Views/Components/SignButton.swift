//
//  SignButton.swift
//  Brown wooden button: the lobby signs (Start, Setting) and the Play button on the character card.
//  (In the lobby, the ropes the signs hang from are drawn by LobbyView.)
//

import SwiftUI

struct SignButton: View {
    let title: LocalizedStringKey
    let fontSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textCase(.uppercase)
                .font(.doodle(fontSize))
                .foregroundStyle(Color.signText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.signBoard)
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
                )
        }
        // Same press feedback as the other buttons: shrinks a little, small vibration.
        .buttonStyle(PressableButtonStyle())
    }
}
