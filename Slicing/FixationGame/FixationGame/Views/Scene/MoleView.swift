//
//  MoleView.swift
//  The distraction: now and then a mole pops out of a hole on the grass,
//  stays a moment, then goes back down (the same pictures played backwards).
//  Moles appear on the grass left of, right of and in front of the stall, never on
//  it, so looking at one means looking away.
//

import SwiftUI

struct MoleView: View {
    /// Moles only appear while the game is being played.
    let canAppear: Bool
    let stageWidth: CGFloat
    let stageHeight: CGFloat

    /// Places on the grass, as fractions of the stage, close to the horizon
    /// (the bottom of the screen is where the gaze tracker is least accurate).
    /// Three areas: left of the stall, in front of it, and right of it.
    private let areas: [[UnitPoint]] = [
        [UnitPoint(x: 0.14, y: 0.655), UnitPoint(x: 0.25, y: 0.705)],   // left
        [UnitPoint(x: 0.30, y: 0.80), UnitPoint(x: 0.74, y: 0.80)],     // middle, in front of the stall (beside the thief's holes)
        [UnitPoint(x: 0.86, y: 0.655), UnitPoint(x: 0.76, y: 0.705)]    // right
    ]
    private let frameCount = 24
    /// Higher = the mole comes up and goes down faster (24 frames each way).
    private let framesPerSecond = 40.0
    /// Seconds between moles.
    private let waitRange = 2.0...4.0
    /// Seconds the mole stays up.
    private let staySeconds = 2.0

    /// 1–24 while a mole is showing, nil when there is none.
    @State private var frame: Int?
    @State private var spot = UnitPoint(x: 0.10, y: 0.84)
    /// The area the last mole used, so the next one picks a different area.
    @State private var lastArea: Int?

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
                    let area = areas.indices.filter { $0 != lastArea }.randomElement() ?? 0
                    lastArea = area
                    spot = areas[area].randomElement() ?? spot
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
