//
//  DriftingCloudsView.swift
//  A few clouds slowly drifting across the sky, some left, some right.
//  Only two cloud pictures exist, so some are flipped to look like different clouds.
//

import SwiftUI

struct DriftingCloudsView: View {
    let stageWidth: CGFloat
    let stageHeight: CGFloat

    private struct Cloud {
        let imageName: String
        let flipped: Bool
        /// Height in the sky, as a fraction of the stage height.
        let y: CGFloat
        /// Width, as a fraction of the stage width.
        let width: CGFloat
        /// Fraction of the stage width moved per second. Negative = moves left.
        let speed: CGFloat
        /// Where the cloud starts, as a fraction of the stage width.
        let start: CGFloat
    }

    private let clouds = [
        Cloud(imageName: "Cloud1", flipped: false, y: 0.10, width: 0.26, speed: 0.012, start: 0.15),
        Cloud(imageName: "Cloud2", flipped: true, y: 0.22, width: 0.20, speed: -0.009, start: 0.70),
        Cloud(imageName: "Cloud2", flipped: false, y: 0.38, width: 0.24, speed: 0.008, start: 0.85),
        Cloud(imageName: "Cloud1", flipped: true, y: 0.50, width: 0.18, speed: -0.011, start: 0.35),
    ]

    var body: some View {
        TimelineView(.animation) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(clouds.indices, id: \.self) { index in
                    let cloud = clouds[index]
                    Image(cloud.imageName)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(x: cloud.flipped ? -1 : 1)
                        .frame(width: stageWidth * cloud.width)
                        .position(x: x(of: cloud, at: seconds), y: stageHeight * cloud.y)
                }
            }
        }
        .frame(width: stageWidth, height: stageHeight)
        .allowsHitTesting(false)
    }

    /// Moves the cloud across, and wraps it to the other side once it has left the screen.
    private func x(of cloud: Cloud, at seconds: TimeInterval) -> CGFloat {
        let margin = cloud.width                  // fully off screen before wrapping
        let track = 1 + 2 * margin                // distance before the cloud wraps around
        var position = (cloud.start + cloud.speed * seconds).truncatingRemainder(dividingBy: track)
        if position < 0 { position += track }
        return stageWidth * (position - margin)
    }
}
