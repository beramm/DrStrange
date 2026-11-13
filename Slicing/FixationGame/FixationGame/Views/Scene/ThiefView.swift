//
//  ThiefView.swift
//  The thief walks in from the right while the fox sleeps, and walks away
//  again when the child looks back at the stall.
//  For now the thief is a fox (FOX 1–4); later it will be another character.
//

import SwiftUI

struct ThiefView: View {
    let isHere: Bool
    let stageWidth: CGFloat
    let stageHeight: CGFloat

    private let walkFrames = ["Thief1", "Thief2", "Thief3", "Thief4"]
    private let secondsPerWalkFrame = 0.15

    var body: some View {
        TimelineView(.periodic(from: .now, by: secondsPerWalkFrame)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / secondsPerWalkFrame)
            Image(walkFrames[step % walkFrames.count])
                .resizable()
                .scaledToFit()
        }
        .frame(height: stageHeight * 0.32)
        // At the stall: in front of the right-hand crate. Away: past the right edge.
        .position(
            x: stageWidth * (isHere ? 0.68 : 1.2),
            y: stageHeight * 0.80
        )
        .animation(.easeInOut(duration: 1.0), value: isHere)
    }
}
