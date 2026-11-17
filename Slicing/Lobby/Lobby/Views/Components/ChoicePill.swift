//
//  ChoicePill.swift
//  One choice on the Settings pop-up (ENGLISH, ON, OFF…): a rounded button with a
//  dark brown outline. The chosen one is filled yellow.
//

import SwiftUI

struct ChoicePill: View {
    let title: LocalizedStringKey
    let isChosen: Bool
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textCase(.uppercase)
                .font(.daysOne(height * 0.36))
                .foregroundStyle(Color.pillOutline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, height * 0.3)
                .frame(width: width, height: height)
                .background(Capsule().fill(isChosen ? Color.pillYellow : Color.clear))
                .overlay(Capsule().strokeBorder(Color.pillOutline, lineWidth: height * 0.065))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

#Preview {
    HStack {
        ChoicePill(title: "On", isChosen: true, width: 110, height: 56) {}
        ChoicePill(title: "Off", isChosen: false, width: 110, height: 56) {}
    }
    .padding()
    .background(Color.sky)
}
