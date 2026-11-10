//
//  GameResultView.swift
//  End screen, styled like Whack-a-Mole's: the fox, a friendly headline,
//  how many veggies were kept safe, and Play again.
//  Always encouraging, never a "you lost" message.
//

import SwiftUI

struct GameResultView: View {
    let veggiesSaved: Int
    let totalVeggies: Int
    /// True when the child stopped early to rest (pause → Rest my eyes, or ✕).
    let stoppedEarly: Bool
    let onPlayAgain: () -> Void

    var body: some View {
        ZStack {
            Color.meadow.ignoresSafeArea()

            VStack(spacing: 40) {
                HStack(spacing: 24) {
                    Image("Fox")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline)
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                        Text(encouragement)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.ink.opacity(0.7))
                        VeggiesLeftView(left: veggiesSaved, total: totalVeggies)
                            .font(.system(size: 44))
                            .padding(.top, 8)
                    }
                    .foregroundStyle(Color.ink)
                }

                Button(action: onPlayAgain) {
                    Label("Play again", systemImage: "arrow.clockwise")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .frame(minWidth: 280, minHeight: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accent)
                .clipShape(Capsule())
            }
            .padding(40)
        }
    }

    private var headline: String {
        if stoppedEarly { return "Time to rest!" }
        return veggiesSaved > 0 ? "Great job!" : "Nice try!"
    }

    private var encouragement: String {
        if stoppedEarly { return "Resting your eyes was a good choice." }
        switch veggiesSaved {
        case totalVeggies: return "You kept every veggie safe!"
        case 0: return "The thieves were sneaky this time. Let's try again!"
        case 1: return "You kept 1 veggie safe!"
        default: return "You kept \(veggiesSaved) veggies safe!"
        }
    }
}

#Preview(traits: .landscapeLeft) {
    GameResultView(veggiesSaved: 2, totalVeggies: 3, stoppedEarly: false, onPlayAgain: {})
}
