//
//  KidButton.swift
//  Big chunky button used across the app.
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
                .font(.system(size: kind == .primary ? 44 : 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: kind == .primary ? 130 : 84)
        }
        .buttonStyle(ChunkyButtonStyle(
            face: kind == .primary ? .playGreen : .settingsBlue,
            edge: kind == .primary ? .playGreenDark : .settingsBlueDark
        ))
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    let face: Color
    let edge: Color
    private let depth: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous).fill(face)
            )
            .offset(y: pressed ? depth - 2 : 0)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(edge)
                    .offset(y: depth)
            )
            .scaleEffect(pressed ? 0.98 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: pressed) { _, new in new }
    }
}
