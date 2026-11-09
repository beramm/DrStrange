import SwiftUI

/// Reaction to the hammer: a few small stars circling the mole's helmet, like being dizzy, and a
/// score floating up. Slow and gentle, with no flashing. `size` is the fully risen mole's frame.
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
            .opacity(progress < 0.7 ? 1 : (1 - progress) / 0.3)
        }
        .accessibilityHidden(true)
    }
}
