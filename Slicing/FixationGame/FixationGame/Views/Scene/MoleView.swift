//
//  MoleView.swift
//  The distraction: now and then a mole pops out of a hole on the grass,
//  stays a moment, then goes back down (the same pictures played backwards).
//  Moles appear beside the stall, never on it, so looking at one means looking away.
//

import SwiftUI

struct MoleView: View {
    /// Moles only appear while the game is being played.
    let canAppear: Bool
    let stageWidth: CGFloat
    let stageHeight: CGFloat

    /// Places on the grass, as fractions of the stage, left and right of the stall.
    private let leftSpots = [UnitPoint(x: 0.10, y: 0.84), UnitPoint(x: 0.13, y: 0.93)]
    private let rightSpots = [UnitPoint(x: 0.91, y: 0.84), UnitPoint(x: 0.89, y: 0.93)]
    private let frameCount = 24
    private let framesPerSecond = 24.0
    /// Seconds between moles.
    private let waitRange = 8.0...12.0
    /// Seconds the mole stays up.
    private let staySeconds = 2.0

    /// 1–24 while a mole is showing, nil when there is none.
    @State private var frame: Int?
    @State private var spot = UnitPoint(x: 0.10, y: 0.84)
    /// Moles take turns: left side, then right side, then left again…
    @State private var nextIsLeft = Bool.random()

    var body: some View {
        ZStack {
            if let frame {
                Image(String(format: "Mole%02d", frame))
                    .resizable()
                    .scaledToFit()
                    .frame(width: stageWidth * 0.13)
                    .position(x: stageWidth * spot.x, y: stageHeight * spot.y)
            }
        }
        .frame(width: stageWidth, height: stageHeight)
        .allowsHitTesting(false)
        // Starts again whenever canAppear changes; stops (throws) when the game pauses or ends.
        .task(id: canAppear) {
            frame = nil
            guard canAppear else { return }
            do {
                while true {
                    try await Task.sleep(for: .seconds(Double.random(in: waitRange)))
                    spot = (nextIsLeft ? leftSpots : rightSpots).randomElement() ?? spot
                    nextIsLeft.toggle()
                    try await play(frames: Array(1...frameCount))           // pop up
                    try await Task.sleep(for: .seconds(staySeconds))
                    try await play(frames: Array((1...frameCount).reversed())) // go back down
                    frame = nil
                }
            } catch {
                frame = nil
            }
        }
    }

    private func play(frames: [Int]) async throws {
        for number in frames {
            frame = number
            try await Task.sleep(for: .seconds(1 / framesPerSecond))
        }
    }
}
