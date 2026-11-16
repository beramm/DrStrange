//
//  ThiefView.swift
//  The thief walks up from the bottom of the screen, right under the crate it
//  wants to steal, while the fox sleeps (seen from the back: Thief1–4).
//  When it has taken the veggies (or the child looks at the stall again), it
//  turns around and runs back down to where it came from (seen from the front:
//  ThiefRun1–4).
//  For now the thief is a fox; later it will be another character.
//

import SwiftUI

struct ThiefView: View {
    let isHere: Bool
    /// Which crate to steal: 0 = left, 1 = middle, 2 = right.
    let crate: Int
    let stageWidth: CGFloat
    let stageHeight: CGFloat

    /// Walking up to the stall, seen from the back.
    private let walkFrames = ["Thief1", "Thief2", "Thief3", "Thief4"]
    /// Running away, seen from the front.
    private let runFrames = ["ThiefRun1", "ThiefRun2", "ThiefRun3", "ThiefRun4"]
    /// How long each picture stays on screen (running is quicker steps).
    private let secondsPerWalkFrame = 0.15
    private let secondsPerRunFrame = 0.1
    /// Where each crate is, as a fraction of the stage width.
    private let crateX: [CGFloat] = [0.39, 0.515, 0.645]
    /// How long walking up and running away take.
    private let walkUpSeconds = 0.6
    private let runAwaySeconds = 1.0

    /// The crate the thief is standing under. It only changes at the moment the
    /// thief starts to walk up, so the thief never slides sideways while visible.
    @State private var shownCrate = 0
    /// When the thief last started walking up or running away.
    @State private var startedMoving = Date.distantPast

    var body: some View {
        // The clock ticks every frame. Each tick picks the walking picture and
        // works out how far up or down the thief is.
        TimelineView(.animation(minimumInterval: 0.03)) { context in
            let frames = isHere ? walkFrames : runFrames
            let secondsPerFrame = isHere ? secondsPerWalkFrame : secondsPerRunFrame
            let step = Int(context.date.timeIntervalSinceReferenceDate / secondsPerFrame)

            Image(frames[step % frames.count])
                .resizable()
                .scaledToFit()
                .frame(height: stageHeight * 0.30)
                .offset(y: offsetY(at: context.date))
        }
        // Where the thief stands while stealing (higher = closer to the stall).
        .position(x: stageWidth * crateX[shownCrate], y: stageHeight * 0.75)
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
