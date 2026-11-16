//
//  VeggiesLeftView.swift
//  Top-bar row of carrots: one for each veggie still safe on the stall.
//  (Takes the place of Whack-a-Mole's star score.)
//

import SwiftUI

struct VeggiesLeftView: View {
    let left: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Image(systemName: "carrot.fill")
                    .foregroundStyle(index < left ? Color.accent : Color.ink.opacity(0.2))
            }
        }
        .font(.title)
        .animation(.snappy, value: left)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(left) of \(total) veggies safe")
    }
}
