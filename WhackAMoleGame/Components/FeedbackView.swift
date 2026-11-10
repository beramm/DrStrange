import SwiftUI

/// Points for a hit: "+10" floating up from the mole's helmet as it sinks. Slow and gentle, with
/// no flashing. `size` is the fully risen mole's frame.
struct HitFeedbackView: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width, height = proxy.size.height
            let helmetY = height * CharacterView.strikePoint.y
            Text("+\(WhackAMoleGameViewModel.pointsPerHit)")
                .font(.system(size: width * 0.2, weight: .heavy, design: .rounded))
                .foregroundStyle(WhackAMolePalette.ink)
                .position(x: width * 0.5, y: helmetY - height * (0.14 + 0.16 * progress))
                .opacity(progress < 0.7 ? 1 : (1 - progress) / 0.3)
        }
        .accessibilityHidden(true)
    }
}
