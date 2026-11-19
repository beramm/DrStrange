import SwiftUI
import UIKit

/// One mole, drawn from the two provided pictures: `Mole/Appear` while it climbs out of its hole and
/// waits, and `Mole/Disappear` (the sad mole) once the hammer has landed. The hole view slides the
/// picture up and down and hides whatever is below the hole's front edge, so no frame sequence is
/// needed. Sleeping moles (decoys) are drawn in grey with a "z z" bubble.
struct CharacterView: View {
    let target: ActiveTarget
    let visual: MoleVisual

    /// Where the hammer lands, as a fraction of the fully risen mole: the top of its helmet.
    static let strikePoint = CGPoint(x: 0.5, y: 0.1)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAsleep: Bool { target.role == .decoy }

    /// A small squash right after the hammer lands; none with Reduce Motion.
    private var squash: CGFloat {
        guard !reduceMotion, let progress = visual.hitProgress else { return 1 }
        return 1 - 0.07 * CGFloat(sin(.pi * min(progress / 0.12, 1)))
    }

    var body: some View {
        GeometryReader { proxy in
            Image(MoleArt.picture(isHit: visual.isHit).assetName)
                .resizable()
                .interpolation(.high)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(x: 1, y: squash, anchor: .bottom)
                .grayscale(isAsleep ? 1 : 0)
                .overlay(alignment: .topTrailing) {
                    if isAsleep && visual.rise >= 0.9 {
                        SleepBubble()
                            .frame(width: proxy.size.width * 0.3, height: proxy.size.width * 0.2)
                            .offset(x: -proxy.size.width * 0.03, y: proxy.size.height * 0.03)
                    }
                }
        }
        .accessibilityHidden(true)
    }
}

/// "z z" bubble shown next to a sleeping mole.
private struct SleepBubble: View {
    var body: some View {
        GeometryReader { proxy in
            Text("z z")
                .font(.system(size: proxy.size.height * 0.62, weight: .heavy, design: .rounded))
                .foregroundStyle(WhackAMolePalette.ink.opacity(0.75))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(Capsule().fill(WhackAMolePalette.cream.opacity(0.9)))
        }
    }
}
