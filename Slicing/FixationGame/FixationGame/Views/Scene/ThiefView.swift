//
//  ThiefView.swift
//  A thief walks up from the bottom of the screen, right under the crate it
//  wants to steal, while the keeper sleeps (seen from the back). When it has taken
//  the veggies (or the child looks at the stall again), it turns around and runs
//  back down to where it came from (seen from the front).
//  The two thieves are the characters the player did not pick; they take turns.
//

import SwiftUI

struct ThiefView: View {
    let isHere: Bool
    /// Which crate to steal: 0 = left, 1 = middle, 2 = right.
    let crate: Int
    /// The characters who steal. They take turns, one per crate.
    let thieves: [FixationCharacter]
    /// Where each crate is, as a fraction of the stage width.
    let crateX: [CGFloat]
    /// Where the thief's feet are while stealing, as a fraction of the stage height.
    let feetY: CGFloat
    /// Makes the thief smaller together with the stall (1 = full size).
    let sizeScale: CGFloat
    let stageWidth: CGFloat
    let stageHeight: CGFloat

    /// How long each picture stays on screen (running is quicker steps).
    private let secondsPerWalkFrame = 0.15
    private let secondsPerRunFrame = 0.1
    /// How long walking up and running away take.
    private let walkUpSeconds = 0.6
    private let runAwaySeconds = 1.0

    /// The crate the thief is standing under. It only changes at the moment the
    /// thief starts to walk up, so the thief never slides sideways while visible.
    @State private var shownCrate = 0
    /// When the thief last started walking up or running away.
    @State private var startedMoving = Date.distantPast

    /// The thief for the current crate: the two thieves take turns.
    private var thief: FixationCharacter {
        thieves[shownCrate % thieves.count]
    }

    var body: some View {
        let height = stageHeight * thief.thiefHeight * sizeScale

        // The clock ticks every frame. Each tick picks the walking picture and
        // works out how far up or down the thief is.
        TimelineView(.animation(minimumInterval: 0.03)) { context in
            let frames = isHere ? thief.thiefWalkImages : thief.thiefRunImages
            let secondsPerFrame = isHere ? secondsPerWalkFrame : secondsPerRunFrame
            let step = Int(context.date.timeIntervalSinceReferenceDate / secondsPerFrame)

            Image(frames[step % frames.count])
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .offset(y: offsetY(at: context.date))
        }
        .position(x: stageWidth * crateX[shownCrate], y: stageHeight * feetY - height / 2)
        .onChange(of: isHere, initial: true) { _, nowHere in
            startedMoving = .now
            if nowHere { shownCrate = min(max(crate, 0), crateX.count - 1) }
        }
    }

    /// 0 = in front of the crate, `hiddenY` = hidden below the bottom edge.
    private func offsetY(at date: Date) -> CGFloat {
        let hiddenY = stageHeight * 0.5
        let elapsed = date.timeIntervalSince(startedMoving)
        if isHere {
            // Walking up: fast at first, slowing down as it reaches the crate.
            let t = min(elapsed / walkUpSeconds, 1)
            let eased = 1 - (1 - t) * (1 - t)
            return hiddenY * (1 - eased)
        } else {
            // Running away: starts slowly, then speeds up.
            let t = min(elapsed / runAwaySeconds, 1)
            return hiddenY * t * t
        }
    }
}
