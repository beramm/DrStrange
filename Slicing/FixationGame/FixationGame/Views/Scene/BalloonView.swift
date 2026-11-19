//
//  BalloonView.swift
//  The distraction from above: now and then a hot air balloon with a mole in
//  the basket floats across the sky, from one side of the screen to the other.
//  It bobs up and down and sways a little while it flies. The next one comes
//  from the other side.
//  It flies at a different height each time, above the stall or behind its roof,
//  so looking at it means looking away.
//

import SwiftUI

struct BalloonView: View {
    /// Balloons only fly while the game is being played.
    let canAppear: Bool
    let stageWidth: CGFloat
    let stageHeight: CGFloat

    /// Balloon width, as a fraction of the stage width.
    private let width: CGFloat = 0.105
    /// Seconds to cross the whole screen.
    private let flightSeconds = 10.0
    /// Seconds between balloons.
    private let waitRange = 4.0...8.0
    /// Height of the flight path (middle of the balloon), as a fraction of the stage height.
    /// High up, just below the progress bar, down to about the stall's roof
    /// (there it flies behind the stall).
    private let heightRange: ClosedRange<CGFloat> = 0.17...0.26
    /// Each balloon flies at least this much higher or lower than the one before.
    private let minHeightChange: CGFloat = 0.05

    /// One trip across the sky.
    private struct Flight {
        let start: Date
        let leftToRight: Bool
        let y: CGFloat
    }

    @State private var flight: Flight?
    /// The next balloon flies the other way.
    @State private var nextLeftToRight = true
    /// Height of the last balloon, so the next one flies at a different height.
    @State private var lastHeight: CGFloat?

    var body: some View {
        TimelineView(.animation) { context in
            if let flight {
                let seconds = context.date.timeIntervalSince(flight.start)
                let progress = min(max(seconds / flightSeconds, 0), 1)
                // From just outside one edge to just outside the other.
                let edge = width
                let x = flight.leftToRight
                    ? -edge + (1 + 2 * edge) * progress
                    : 1 + edge - (1 + 2 * edge) * progress
                // The wiggle: a slow bob up and down and a small sway.
                let bob = 0.015 * sin(seconds * 2 * .pi / 2.2)
                let sway = 4 * sin(seconds * 2 * .pi / 3.0)

                Image("HotAirBalloon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: stageWidth * width)
                    // Sways from the top, like hanging from the air.
                    .rotationEffect(.degrees(sway), anchor: .top)
                    .position(x: stageWidth * x, y: stageHeight * (flight.y + bob))
            }
        }
        .frame(width: stageWidth, height: stageHeight)
        .allowsHitTesting(false)
        // Starts again whenever canAppear changes; stops (throws) when the game pauses or ends.
        .task(id: canAppear) {
            flight = nil
            guard canAppear else { return }
            do {
                while true {
                    try await Task.sleep(for: .seconds(Double.random(in: waitRange)))
                    let height = newHeight()
                    lastHeight = height
                    flight = Flight(start: .now, leftToRight: nextLeftToRight, y: height)
                    nextLeftToRight.toggle()
                    try await Task.sleep(for: .seconds(flightSeconds))
                    flight = nil
                }
            } catch {
                flight = nil
            }
        }
    }

    /// A random height that is clearly different from the last balloon's.
    private func newHeight() -> CGFloat {
        guard let lastHeight else { return .random(in: heightRange) }
        // Try a few times; the range is wide, so this nearly always works at once.
        for _ in 0..<10 {
            let height = CGFloat.random(in: heightRange)
            if abs(height - lastHeight) >= minHeightChange { return height }
        }
        // Otherwise go to the far end of the range.
        return lastHeight < (heightRange.lowerBound + heightRange.upperBound) / 2
            ? heightRange.upperBound : heightRange.lowerBound
    }
}
