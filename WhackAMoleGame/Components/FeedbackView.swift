import SwiftUI

/// Rating and points for a hit ("Perfect +30") floating up from the mole's helmet as it sinks.
/// Slow and gentle, with no flashing. The view's frame is the fully risen mole's frame.
struct HitFeedbackView: View {
    let progress: Double
    let rating: HitRating

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width, height = proxy.size.height
            let helmetY = height * CharacterView.strikePoint.y
            VStack(spacing: 0) {
                Text(rating.title)
                    .font(.system(size: width * 0.13, weight: .heavy, design: .rounded))
                Text("+\(rating.points)")
                    .font(.system(size: width * 0.2, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(WhackAMolePalette.ink)
            .fixedSize()
            .position(x: width * 0.5, y: helmetY - height * (0.2 + 0.16 * progress))
            .opacity(progress < 0.7 ? 1 : (1 - progress) / 0.3)
        }
        .accessibilityHidden(true)
    }
}
