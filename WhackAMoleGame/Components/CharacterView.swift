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
    private var riseAssetName: String {
        Self.assetName(reduceMotion ? MoleVisual.frameCount : visual.frame)
    }

    private var hitFrameBlend: MoleVisual.FrameBlend? {
        guard let blend = visual.hitFrameBlend else { return nil }
        return reduceMotion
            ? MoleVisual.FrameBlend(current: 1, next: 1, fraction: 0)
            : blend
    }

    private var opacity: Double {
        guard reduceMotion else { return 1 }
        if let progress = visual.hitProgress { return 1 - progress }
        return Double(visual.frame) / Double(MoleVisual.frameCount)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let blend = hitFrameBlend {
                    sprite(Self.hitAssetName(blend.current), size: proxy.size)
                        .opacity(1 - blend.fraction)
                    if blend.next != blend.current {
                        sprite(Self.hitAssetName(blend.next), size: proxy.size)
                            .opacity(blend.fraction)
                    }
                } else {
                    sprite(riseAssetName, size: proxy.size)
                }
            }
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

    private func sprite(_ name: String, size: CGSize) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .frame(width: size.width, height: size.height)
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
