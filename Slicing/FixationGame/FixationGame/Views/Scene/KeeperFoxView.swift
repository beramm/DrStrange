//
//  KeeperFoxView.swift
//  The fox who keeps the stall. Awake (Bangun) while the child watches the stall;
//  falls asleep (Tidur 1 → 2 → 3, again and again) when the child looks away.
//

import SwiftUI

struct KeeperFoxView: View {
    let isAwake: Bool

    private let sleepFrames = ["KeeperSleep1", "KeeperSleep2", "KeeperSleep3"]
    /// How long each sleeping picture stays on screen.
    private let secondsPerSleepFrame = 0.5

    var body: some View {
        if isAwake {
            Image("KeeperAwake")
                .resizable()
                .scaledToFit()
        } else {
            // Redraws on a steady clock to step through the sleeping pictures.
            TimelineView(.animation(minimumInterval: 0.1)) { context in
                let step = Int(context.date.timeIntervalSinceReferenceDate / secondsPerSleepFrame)
                Image(sleepFrames[step % sleepFrames.count])
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

#Preview {
    HStack {
        KeeperFoxView(isAwake: true)
        KeeperFoxView(isAwake: false)
    }
    .frame(height: 300)
}
