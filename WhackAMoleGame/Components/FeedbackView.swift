import SwiftUI

enum ProximityHitFeedback: Int, Equatable {
    case ok = 20
    case good = 30
    case perfect = 60

    var assetName: String {
        switch self {
        case .perfect: "FeedbackBubbles/Perfect"
        case .good: "FeedbackBubbles/Good"
        case .ok: "FeedbackBubbles/OK"
        }
    }
}

/// Drawn above the full-screen fox attack layer so the feedback can never be obscured by the fox.
/// Hole anchors keep each bubble aligned with the same character rectangle used by the board.
struct HitFeedbackOverlay: View {
    let viewModel: WhackAMoleGameViewModel
    let anchors: [FoxAnchorID: Anchor<CGRect>]

    var body: some View {
        GeometryReader { proxy in
            ForEach(viewModel.targets) { target in
                if let anchor = anchors[.hole(target.holeIndex)],
                   let visual = viewModel.moleVisuals[target.holeIndex],
                   let progress = visual.hitProgress {
                    let holeRect = proxy[anchor]
                    let artIndex = viewModel.holes.first {
                        $0.holeIndex == target.holeIndex
                    }?.artIndex ?? 0
                    let localMole = MoleHoleView.characterRect(
                        artIndex: artIndex,
                        in: holeRect.size
                    )
                    let mole = localMole.offsetBy(dx: holeRect.minX, dy: holeRect.minY)

                    HitFeedbackView(
                        progress: progress,
                        points: target.pointsAwarded ?? GameSessionRecord.defaultPointsPerHit
                    )
                    .frame(width: mole.width, height: mole.height)
                    .position(x: mole.midX, y: mole.midY)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Reaction to the hammer: a few small stars circling the mole's helmet, like being dizzy, and a
/// score floating up. Proximity-scored gaze hits use the matching illustrated feedback bubble.
/// Slow and gentle, with no flashing. `size` is the fully risen mole's frame.
struct HitFeedbackView: View {
    let progress: Double
    let points: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let starCount = 3

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width, height = proxy.size.height
            let helmetY = height * CharacterView.strikePoint.y
            ZStack {
                if let proximityFeedback = ProximityHitFeedback(rawValue: points) {
                    Image(proximityFeedback.assetName)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: width * 1.35, height: height * 0.75)
                        .scaleEffect(reduceMotion ? 1 : 0.88 + 0.12 * min(progress / 0.18, 1))
                        .position(
                            x: width * 0.5,
                            y: helmetY - height * (0.23 + (reduceMotion ? 0 : 0.12 * progress))
                        )
                } else {
                    if !reduceMotion {
                        ForEach(0..<starCount, id: \.self) { index in
                            let angle = progress * 2 * .pi * 1.25 + Double(index) / Double(starCount) * 2 * .pi
                            // A flat orbit; stars at the front of the circle are a little larger.
                            let depth = (sin(angle) + 1) / 2
                            StarShape()
                                .fill(WhackAMolePalette.star)
                                .overlay(StarShape().stroke(WhackAMolePalette.accent, lineWidth: 1))
                                .frame(width: width * (0.14 + 0.06 * depth), height: width * (0.14 + 0.06 * depth))
                                .position(x: width / 2 + cos(angle) * width * 0.42, y: helmetY + sin(angle) * height * 0.07)
                        }
                    }
                    Text("+\(points)")
                        .font(.system(size: width * 0.2, weight: .heavy, design: .rounded))
                        .foregroundStyle(WhackAMolePalette.ink)
                        .position(x: width * 0.5, y: helmetY - height * (0.14 + 0.16 * progress))
                }
            }
            .opacity(progress < 0.7 ? 1 : (1 - progress) / 0.3)
        }
        .accessibilityHidden(true)
    }
}
