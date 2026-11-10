//
//  ArrowButton.swift
//  Square yellow button with a cream triangle, for previous / next.
//

import SwiftUI

struct ArrowButton: View {
    enum Direction { case previous, next }

    let direction: Direction
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction == .previous ? "arrowtriangle.backward.fill" : "arrowtriangle.forward.fill")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(Color.signText)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                        .fill(Color.arrowYellow)
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(direction == .previous ? "Previous character" : "Next character")
    }
}
