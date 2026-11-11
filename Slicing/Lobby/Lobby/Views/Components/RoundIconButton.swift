//
//  RoundIconButton.swift
//  Round orange-red button with a cream icon (back, settings).
//

import SwiftUI

struct RoundIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(Color.signText)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.roundButton))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
    }
}
