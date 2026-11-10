//
//  VeggieStallView.swift
//  The stall the child guards: striped awning, the fox shopkeeper behind the
//  counter, veggies on top, and the thief sneaking in from the left.
//  Simple drawn placeholder until the design team's stall art is ready.
//

import SwiftUI

struct VeggieStallView: View {
    /// How many veggies are still on the counter.
    let veggiesLeft: Int
    let thiefIsHere: Bool

    private let veggies = ["🥕", "🥦", "🍅"]

    var body: some View {
        VStack(spacing: 0) {
            awning

            // Posts with the fox in between. The fox's legs go below this area;
            // the counter (drawn next) covers them, so the fox stands behind it.
            ZStack(alignment: .bottom) {
                HStack {
                    post
                    Spacer()
                    post
                }
                .padding(.horizontal, 30)

                Image("Fox")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400, height: 400)
                    .offset(y: 80)
                    .accessibilityHidden(true)
            }
            .frame(width: 600, height: 300)

            counter
        }
        // An overlay, so the stall stays still when the thief shows up.
        .overlay(alignment: .bottomLeading) {
            if thiefIsHere {
                Text("🦝")
                    .font(.system(size: 130))
                    .offset(x: -120, y: -40)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .accessibilityLabel("A thief is at the stall")
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: thiefIsHere)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: veggiesLeft)
    }

    /// Orange-and-cream striped roof.
    private var awning: some View {
        HStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { index in
                Rectangle().fill(index.isMultiple(of: 2) ? Color.accent : Color.cream)
            }
        }
        .frame(width: 640, height: 70)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 12,
                                          bottomTrailingRadius: 12, topTrailingRadius: 24))
    }

    private var post: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.rim)
            .frame(width: 18)
    }

    /// Wooden counter with the veggies sitting on top.
    private var counter: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.rim)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.holeShadow.opacity(0.5))
                    .frame(height: 12)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }
            .frame(width: 680, height: 150)
            .overlay(alignment: .top) {
                // Spaced wide so the veggies sit beside the fox, not in front of its face.
                HStack(spacing: 200) {
                    // Every veggie keeps its own spot; a taken one just disappears,
                    // so the others don't slide around.
                    ForEach(veggies.indices, id: \.self) { index in
                        Text(veggies[index])
                            .font(.system(size: 90))
                            .scaleEffect(index < veggiesLeft ? 1 : 0.3)
                            .opacity(index < veggiesLeft ? 1 : 0)
                    }
                }
                .offset(y: -55)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(veggiesLeft) veggies on the stall")
            }
    }
}

#Preview(traits: .landscapeLeft) {
    VeggieStallView(veggiesLeft: 2, thiefIsHere: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.meadow)
}
