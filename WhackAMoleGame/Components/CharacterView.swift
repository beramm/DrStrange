import SwiftUI
import UIKit

/// One mole, drawn from the provided 24-frame rise animation (`Characters/MoleRise/Frame01…24`).
/// The frames play forwards as it climbs out and backwards as it goes down. When the hammer lands,
/// the 24-frame hit animation (`Characters/MoleHit/Frame01…24`) plays instead and takes it back down.
/// Sleeping moles (decoys) are drawn in grey with a "z z" bubble.
struct CharacterView: View {
    let target: ActiveTarget
    let visual: MoleVisual

    /// Where the hammer lands, as a fraction of the fully risen mole: the top of its helmet.
    static let strikePoint = CGPoint(x: 0.5, y: 0.1)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func assetName(_ frame: Int) -> String {
        String(format: "MoleRise/Frame%02d", min(max(frame, 1), MoleVisual.frameCount))
    }

    static func hitAssetName(_ frame: Int) -> String {
        String(format: "MoleHit/Frame%02d", min(max(frame, 1), MoleVisual.frameCount))
    }

    private var isAsleep: Bool { target.role == .decoy }

    /// With Reduce Motion the mole fades in and out instead of climbing or sinking.
    private var assetName: String {
        if let hitFrame = visual.hitFrame { return Self.hitAssetName(reduceMotion ? 1 : hitFrame) }
        return Self.assetName(reduceMotion ? MoleVisual.frameCount : visual.frame)
    }

    private var opacity: Double {
        guard reduceMotion else { return 1 }
        if let progress = visual.hitProgress { return 1 - progress }
        return Double(visual.frame) / Double(MoleVisual.frameCount)
    }

    var body: some View {
        GeometryReader { proxy in
            Image(assetName)
                .resizable()
                .interpolation(.high)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .grayscale(isAsleep ? 1 : 0)
                .opacity(opacity)
                .overlay(alignment: .topTrailing) {
                    if isAsleep && visual.frame >= MoleVisual.frameCount - 2 {
                        SleepBubble()
                            .frame(width: proxy.size.width * 0.38, height: proxy.size.width * 0.26)
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
