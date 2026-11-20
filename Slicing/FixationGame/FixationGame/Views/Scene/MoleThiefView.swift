//
//  MoleThiefView.swift
//  The thief: a mole that pops up out of a hole in front of the basket it wants,
//  while the keeper sleeps. When it has taken the veggies it holds a carrot over
//  its head, then goes back down into its hole. If the child looks at the stall
//  again in time, it just goes back down without anything.
//  It is bigger than the distraction moles, so the child can tell them apart.
//

import SwiftUI

struct MoleThiefView: View {
    let isHere: Bool
    /// Which basket to steal: 0 = left, 1 = middle, 2 = right.
    let crate: Int
    /// Baskets still full. When it goes down after a basket was emptied, the mole
    /// shows the carrot it stole.
    let veggiesLeft: Int
    /// Where the hole in front of each basket is, as a fraction of the stage width.
    let holeX: [CGFloat]
    /// Height of the middle of the hole, as a fraction of the stage height.
    let holeY: CGFloat
    let stageWidth: CGFloat
    let stageHeight: CGFloat

    /// Width of the mole pictures, as a fraction of the stage width. The distraction
    /// moles are 0.13; the thief is bigger.
    private let width: CGFloat = 0.17
    /// Faster than the distraction moles (24 pictures each way, 0.4 s).
    private let framesPerSecond = 60.0
    private let frameCount = 24
    /// How long the mole shows the stolen carrot before going down.
    private let showCarrotSeconds = 0.5

    private enum Pose: Equatable {
        case hidden
        /// One of the "coming out of the hole" pictures, 1–24.
        case rising(Int)
        /// Standing on its hole, holding the stolen carrot up.
        case stealing
    }

    @State private var pose = Pose.hidden
    /// The basket the mole is in front of. Only changes while the mole is hidden.
    @State private var shownCrate = 0
    /// Baskets full when the mole came up, to tell if it took one.
    @State private var veggiesWhenArrived = 0
    @State private var moveTask: Task<Void, Never>?

    var body: some View {
        // The mole pictures are 469 × 403; the hole is in their lower part.
        let frameWidth = stageWidth * width
        let frameHeight = frameWidth * 403 / 469
        let x = stageWidth * holeX[shownCrate]
        // The middle of the hole is 71% down the picture.
        let frameCenterY = stageHeight * holeY - frameHeight * 0.21

        ZStack {
            switch pose {
            case .hidden:
                EmptyView()
            case .rising(let frame):
                Image(String(format: "Mole%02d", frame))
                    .resizable()
                    .scaledToFit()
                    .frame(width: frameWidth)
                    .position(x: x, y: frameCenterY)
            case .stealing:
                // An empty hole (same size as the hole in the mole pictures), with the
                // mole standing in it holding the carrot.
                Image("MoleThiefHole")
                    .resizable()
                    .frame(width: frameWidth * 0.97, height: frameHeight * 0.53)
                    .position(x: x, y: stageHeight * holeY)
                let thiefHeight = frameHeight * 1.15
                Image("MoleThief")
                    .resizable()
                    .scaledToFit()
                    .frame(height: thiefHeight)
                    // Feet planted in the front half of the hole, so it stands in it.
                    .position(x: x, y: stageHeight * holeY + frameHeight * 0.12 - thiefHeight / 2)
            }
        }
        .frame(width: stageWidth, height: stageHeight)
        .allowsHitTesting(false)
        .onChange(of: isHere, initial: true) { _, nowHere in
            nowHere ? comeUp() : goDown()
        }
        .onDisappear { moveTask?.cancel() }
    }

    private func comeUp() {
        moveTask?.cancel()
        shownCrate = min(max(crate, 0), holeX.count - 1)
        veggiesWhenArrived = veggiesLeft
        moveTask = Task {
            await play(from: 1, to: frameCount)
        }
    }

    private func goDown() {
        guard pose != .hidden else { return }
        moveTask?.cancel()
        let tookVeggies = veggiesLeft < veggiesWhenArrived
        let from: Int
        if case .rising(let frame) = pose { from = frame } else { from = frameCount }
        moveTask = Task {
            if tookVeggies {
                pose = .stealing
                try? await Task.sleep(for: .seconds(showCarrotSeconds))
                if Task.isCancelled { return }
            }
            await play(from: from, to: 1)
            if !Task.isCancelled { pose = .hidden }
        }
    }

    /// Plays the hole pictures from one number to another (up or down).
    private func play(from start: Int, to end: Int) async {
        let frames = start <= end ? Array(start...end) : Array((end...start).reversed())
        for frame in frames {
            if Task.isCancelled { return }
            pose = .rising(frame)
            try? await Task.sleep(for: .seconds(1 / framesPerSecond))
        }
    }
}
