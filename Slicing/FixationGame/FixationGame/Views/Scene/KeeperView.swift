//
//  KeeperView.swift
//  The character who keeps the stall (the one the player picked). Awake (Bangun)
//  while the child watches the stall; falls asleep (Tidur 1 → 2 → 3, again and
//  again) when the child looks away.
//

import SwiftUI

struct KeeperView: View {
    let character: GameCharacter
    let isAwake: Bool

    /// How long each sleeping picture stays on screen.
    private let secondsPerSleepFrame = 0.5

    var body: some View {
        if isAwake {
            Image(character.keeperAwakeImage)
                .resizable()
                .scaledToFit()
        } else {
            // Redraws on a steady clock to step through the sleeping pictures.
            TimelineView(.animation(minimumInterval: 0.1)) { context in
                let frames = character.keeperSleepImages
                let step = Int(context.date.timeIntervalSinceReferenceDate / secondsPerSleepFrame)
                Image(frames[step % frames.count])
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

#Preview {
    HStack {
        ForEach(GameCharacter.allCases) { character in
            KeeperView(character: character, isAwake: true)
            KeeperView(character: character, isAwake: false)
        }
    }
    .frame(height: 200)
}
